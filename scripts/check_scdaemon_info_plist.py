#!/usr/bin/env python3
"""Fail unless scdaemon has a bound __TEXT,__info_plist for com.moaiy.app.scdaemon.

Apple's codesign reports `Info.plist=not bound` when the code directory has no
info-slot hash. A signing identifier alone does not set that slot. This check
reads the Mach-O section and, when a signature is present, requires the info
slot hash to be non-zero and the embedded plist blob to contain the bundle id.
"""

from __future__ import annotations

import argparse
import pathlib
import struct
import sys

MH_MAGIC_64 = 0xFEEDFACF
LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1D
CSMAGIC_EMBEDDED_SIGNATURE = 0xFADE0CC0
CSMAGIC_CODEDIRECTORY = 0xFADE0C02
CSSLOT_INFOSLOT = 1
BUNDLE_ID = b"com.moaiy.app.scdaemon"


def _cstr(buf: bytes) -> str:
    return buf.split(b"\x00", 1)[0].decode("ascii", "replace")


def section_plist(data: bytes) -> bytes:
    _, _, _, _, ncmds, _, _, _ = struct.unpack_from("<IIIIIIII", data, 0)
    offset = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, offset)
        if cmd == LC_SEGMENT_64 and _cstr(data[offset + 8 : offset + 24]) == "__TEXT":
            nsects = struct.unpack_from("<I", data, offset + 64)[0]
            section = offset + 72
            for _ in range(nsects):
                if _cstr(data[section : section + 16]) == "__info_plist":
                    size = struct.unpack_from("<Q", data, section + 40)[0]
                    file_off = struct.unpack_from("<I", data, section + 48)[0]
                    blob = data[file_off : file_off + size]
                    if BUNDLE_ID not in blob:
                        raise SystemExit("FAIL: __TEXT,__info_plist has no com.moaiy.app.scdaemon")
                    return blob
                section += 80
            raise SystemExit("FAIL: scdaemon has no __TEXT,__info_plist section (otool -P would be empty)")
        offset += cmdsize
    raise SystemExit("FAIL: __TEXT segment not found")


def signature_bounds(data: bytes) -> tuple[int, int] | None:
    _, _, _, _, ncmds, _, _, _ = struct.unpack_from("<IIIIIIII", data, 0)
    offset = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, offset)
        if cmd == LC_CODE_SIGNATURE:
            dataoff, datasize = struct.unpack_from("<II", data, offset + 8)
            return dataoff, datasize
        offset += cmdsize
    return None


def info_slot_is_bound(data: bytes, plist: bytes) -> None:
    """Require the code-directory info slot (-1) to hash this exact plist.

    `codesign -d` prints `Info.plist=not bound` when that special-slot hash is
    missing or zero. A non-zero hash of the `__info_plist` bytes is what makes
    it report the plist as bound. The plist XML itself lives in the section,
    which is what `otool -P` prints.
    """
    import hashlib

    located = signature_bounds(data)
    if located is None:
        raise SystemExit("FAIL: scdaemon has no code signature (Info.plist=not bound)")
    dataoff, datasize = located
    blob = data[dataoff : dataoff + datasize]
    magic, _, count = struct.unpack_from(">III", blob, 0)
    if magic != CSMAGIC_EMBEDDED_SIGNATURE:
        raise SystemExit("FAIL: code signature superblob is invalid")
    cd_offset = None
    for index in range(count):
        slot_type, slot_offset = struct.unpack_from(">II", blob, 12 + index * 8)
        if slot_type == 0:
            cd_offset = slot_offset
            break
    if cd_offset is None:
        raise SystemExit("FAIL: code directory missing")
    cd_magic = struct.unpack_from(">I", blob, cd_offset)[0]
    if cd_magic != CSMAGIC_CODEDIRECTORY:
        raise SystemExit("FAIL: code directory magic mismatch")
    hash_offset, _, n_special, n_code = struct.unpack_from(">IIII", blob, cd_offset + 16)
    hash_size = blob[cd_offset + 36]
    if n_special < CSSLOT_INFOSLOT or n_code < 1:
        raise SystemExit("FAIL: Info.plist=not bound (no info special slot)")
    info_hash_at = cd_offset + hash_offset - hash_size
    info_hash = blob[info_hash_at : info_hash_at + hash_size]
    if info_hash == b"\x00" * hash_size:
        raise SystemExit("FAIL: Info.plist=not bound (info slot hash is zero)")
    if info_hash != hashlib.sha256(plist).digest():
        raise SystemExit("FAIL: Info.plist=not bound (info slot hash is not the embedded plist)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    args = parser.parse_args()
    data = pathlib.Path(args.binary).read_bytes()
    if data[:4] != struct.pack("<I", MH_MAGIC_64):
        raise SystemExit("FAIL: not a 64-bit Mach-O")
    plist = section_plist(data)
    info_slot_is_bound(data, plist)
    print(f"PASS: __TEXT,__info_plist and signature info slot contain {BUNDLE_ID.decode()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
