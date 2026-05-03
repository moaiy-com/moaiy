#!/usr/bin/env python3
"""Validate that dynamic localization keys are present in compiled strings."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


DYNAMIC_KEY_PATTERN = re.compile(
    r"(?:titleKey|messageKey|settingsDisplayKey|displayKey)\s*:\s*\"([a-z0-9_.-]+)\""
)
COMPILED_KEY_PATTERN = re.compile(r"<key>([^<]+)</key>")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check dynamic localization keys against compiled Localizable.strings."
    )
    parser.add_argument(
        "--source-root",
        default="Moaiy",
        help="Source root to scan for Swift files",
    )
    parser.add_argument(
        "--catalog",
        default="Moaiy/Resources/Localizable.xcstrings",
        help="Path to Localizable.xcstrings",
    )
    parser.add_argument(
        "--compiled-strings",
        required=True,
        help="Path to compiled Localizable.strings (for example en.lproj/Localizable.strings)",
    )
    return parser.parse_args()


def read_catalog_keys(path: Path) -> set[str]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    strings = payload.get("strings", {})
    if not isinstance(strings, dict):
        raise ValueError("invalid catalog format: `strings` is missing or not a dictionary")
    return set(strings.keys())


def collect_dynamic_keys(source_root: Path) -> tuple[set[str], dict[str, list[str]]]:
    keys: set[str] = set()
    locations: dict[str, list[str]] = {}

    for file_path in source_root.rglob("*.swift"):
        if "Tests" in file_path.parts:
            continue

        text = file_path.read_text(encoding="utf-8")
        for match in DYNAMIC_KEY_PATTERN.finditer(text):
            key = match.group(1)
            keys.add(key)
            line = text.count("\n", 0, match.start()) + 1
            locations.setdefault(key, []).append(f"{file_path}:{line}")

    return keys, locations


def read_compiled_keys(path: Path) -> set[str]:
    raw = path.read_bytes()

    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16")
    else:
        text = raw.decode("utf-8")

    return set(COMPILED_KEY_PATTERN.findall(text))


def main() -> int:
    args = parse_args()

    source_root = Path(args.source_root)
    catalog_path = Path(args.catalog)
    compiled_path = Path(args.compiled_strings)

    if not source_root.exists():
        print(f"ERROR: source root not found: {source_root}")
        return 1
    if not catalog_path.exists():
        print(f"ERROR: catalog not found: {catalog_path}")
        return 1
    if not compiled_path.exists():
        print(f"ERROR: compiled strings not found: {compiled_path}")
        return 1

    try:
        catalog_keys = read_catalog_keys(catalog_path)
    except Exception as error:  # pragma: no cover - defensive path
        print(f"ERROR: failed to read catalog: {error}")
        return 1

    dynamic_keys, locations = collect_dynamic_keys(source_root)
    compiled_keys = read_compiled_keys(compiled_path)

    missing_in_catalog = sorted(dynamic_keys - catalog_keys)
    missing_in_compiled = sorted(dynamic_keys - compiled_keys)

    if missing_in_catalog or missing_in_compiled:
        print("Runtime localization key check failed.")

        if missing_in_catalog:
            print(f"- Missing in catalog: {len(missing_in_catalog)}")
            for key in missing_in_catalog:
                first_location = locations.get(key, ["<unknown>"])[0]
                print(f"  - {key} ({first_location})")

        if missing_in_compiled:
            print(f"- Missing in compiled strings: {len(missing_in_compiled)}")
            for key in missing_in_compiled:
                first_location = locations.get(key, ["<unknown>"])[0]
                print(f"  - {key} ({first_location})")

        return 1

    print(
        "Runtime localization key check passed: "
        f"{len(dynamic_keys)} dynamic keys verified in compiled strings."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
