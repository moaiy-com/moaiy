#!/usr/bin/env python3
"""Embed an Info.plist as a Mach-O __TEXT,__info_plist section.

scdaemon is a prebuilt GnuPG executable. Device entitlements make libsecinit
read CFBundleIdentifier from this section (and from the code-signature
Info.plist slot that codesign copies out of it). A temporary .app wrapper does
not leave the plist in the bare bin/scdaemon that gpg-agent spawns.

The section is placed in unused bytes at the end of the existing __TEXT
segment. The 80-byte section header is inserted into the load-command area,
which has padding before __text, so later file offsets stay put.
"""

from __future__ import annotations

import argparse
import pathlib
import struct
import sys

LC_SEGMENT_64 = 0x19
MH_MAGIC_64 = 0xFEEDFACF
SECTION_SIZE = 80


def _cstr(buf: bytes, size: int = 16) -> str:
    return buf.split(b"\x00", 1)[0].decode("ascii", "replace")


def find_text_segment(data: bytes) -> tuple[int, int, int, int, int, int]:
    magic, _, _, _, ncmds, _, _, _ = struct.unpack_from("<IIIIIIII", data, 0)
    if magic != MH_MAGIC_64:
        raise SystemExit("scdaemon is not a 64-bit Mach-O")
    offset = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, offset)
        if cmd == LC_SEGMENT_64:
            name = _cstr(data[offset + 8 : offset + 24])
            if name == "__TEXT":
                vmaddr = struct.unpack_from("<Q", data, offset + 24)[0]
                fileoff, filesize = struct.unpack_from("<QQ", data, offset + 40)
                nsects = struct.unpack_from("<I", data, offset + 64)[0]
                return offset, cmdsize, vmaddr, fileoff, filesize, nsects
        offset += cmdsize
    raise SystemExit("__TEXT segment not found")


def existing_info_plist(data: bytes) -> bytes | None:
    text_off, cmdsize, _, _, _, nsects = find_text_segment(data)
    section = text_off + 72
    for _ in range(nsects):
        name = _cstr(data[section : section + 16])
        if name == "__info_plist":
            size = struct.unpack_from("<Q", data, section + 40)[0]
            file_off = struct.unpack_from("<I", data, section + 48)[0]
            return data[file_off : file_off + size]
        section += SECTION_SIZE
    if text_off + cmdsize != section:
        raise SystemExit("__TEXT command size does not match its sections")
    return None


def last_text_content_end(data: bytes) -> int:
    text_off, _, _, _, _, nsects = find_text_segment(data)
    section = text_off + 72
    end = 0
    for _ in range(nsects):
        size = struct.unpack_from("<Q", data, section + 40)[0]
        file_off = struct.unpack_from("<I", data, section + 48)[0]
        if file_off and size:
            end = max(end, file_off + size)
        section += SECTION_SIZE
    return end


def embed(path: pathlib.Path, plist: bytes) -> str:
    original = path.read_bytes()
    current = existing_info_plist(original)
    if current == plist:
        return "already-embedded"
    if current is not None:
        raise SystemExit("scdaemon already has a different __TEXT,__info_plist section")

    data = bytearray(original)
    magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack_from(
        "<IIIIIIII", data, 0
    )
    text_off, text_cmdsize, vmaddr, fileoff, filesize, nsects = find_text_segment(data)
    if fileoff != 0:
        raise SystemExit("__TEXT is not at file offset 0; refusing to rewrite")
    load_end = 32 + sizeofcmds
    insert_at = text_off + text_cmdsize
    content_end = last_text_content_end(data)
    plist_off = (content_end + 15) & ~15
    text_end = fileoff + filesize
    if plist_off + len(plist) > text_end:
        raise SystemExit("not enough unused space at the end of __TEXT for Info.plist")
    first_code = None
    section = text_off + 72
    for _ in range(nsects):
        size = struct.unpack_from("<Q", data, section + 40)[0]
        file_pos = struct.unpack_from("<I", data, section + 48)[0]
        if file_pos and size:
            first_code = file_pos if first_code is None else min(first_code, file_pos)
        section += SECTION_SIZE
    if first_code is None or load_end + SECTION_SIZE > first_code:
        raise SystemExit("no padding between load commands and __text")

    section_hdr = bytearray(SECTION_SIZE)
    section_hdr[0:16] = b"__info_plist".ljust(16, b"\x00")
    section_hdr[16:32] = b"__TEXT".ljust(16, b"\x00")
    struct.pack_into("<Q", section_hdr, 32, vmaddr + plist_off)
    struct.pack_into("<Q", section_hdr, 40, len(plist))
    struct.pack_into("<I", section_hdr, 48, plist_off)
    struct.pack_into("<I", section_hdr, 52, 4)  # 16-byte alignment
    moved = bytes(data[insert_at:load_end])
    data[insert_at + SECTION_SIZE : load_end + SECTION_SIZE] = moved
    data[insert_at : insert_at + SECTION_SIZE] = section_hdr
    data[plist_off : plist_off + len(plist)] = plist

    struct.pack_into("<I", data, text_off + 4, text_cmdsize + SECTION_SIZE)
    struct.pack_into("<I", data, text_off + 64, nsects + 1)
    struct.pack_into(
        "<IIIIIIII",
        data,
        0,
        magic,
        cputype,
        cpusub,
        filetype,
        ncmds,
        sizeofcmds + SECTION_SIZE,
        flags,
        reserved,
    )
    path.write_bytes(data)
    return f"embedded {len(plist)} bytes at file offset {plist_off}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("plist")
    args = parser.parse_args()
    binary = pathlib.Path(args.binary)
    plist = pathlib.Path(args.plist).read_bytes()
    if b"CFBundleIdentifier" not in plist or b"com.moaiy.app.scdaemon" not in plist:
        raise SystemExit("Info.plist is missing CFBundleIdentifier com.moaiy.app.scdaemon")
    print(embed(binary, plist))
    return 0


if __name__ == "__main__":
    sys.exit(main())
