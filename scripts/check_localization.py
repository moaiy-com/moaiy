#!/usr/bin/env python3
"""Validate localization completeness and placeholder consistency."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REQUIRED_LOCALES = [
    "en",
    "zh-Hans",
    "es",
    "pt-BR",
    "hi",
    "ar",
    "fr",
    "de",
    "ja",
    "ko",
    "ru",
]

PLACEHOLDER_PATTERN = re.compile(r"%(?:\d+\$)?(?:lld|lli|llu|ld|li|lu|d|i|u|f|g|@|s)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check String Catalog locale coverage and placeholder consistency."
    )
    parser.add_argument(
        "--catalog",
        default="Moaiy/Resources/Localizable.xcstrings",
        help="Path to Localizable.xcstrings",
    )
    return parser.parse_args()


def extract_placeholders(text: str) -> list[str]:
    normalized = text.replace("%%", "")
    return PLACEHOLDER_PATTERN.findall(normalized)


def read_catalog(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    args = parse_args()
    catalog_path = Path(args.catalog)
    if not catalog_path.exists():
        print(f"ERROR: catalog not found: {catalog_path}")
        return 1

    catalog = read_catalog(catalog_path)
    strings = catalog.get("strings", {})
    if not isinstance(strings, dict):
        print("ERROR: invalid catalog format, `strings` is missing or not a dictionary.")
        return 1

    missing_entries: list[str] = []
    placeholder_mismatches: list[str] = []
    checked_keys = 0

    for key, node in strings.items():
        if not isinstance(node, dict):
            continue

        localizations = node.get("localizations")
        if not isinstance(localizations, dict) or not localizations:
            continue

        checked_keys += 1
        english_value = (
            localizations.get("en", {}).get("stringUnit", {}).get("value")
            if isinstance(localizations.get("en"), dict)
            else None
        )
        english_placeholders = extract_placeholders(english_value) if isinstance(english_value, str) else []

        for locale in REQUIRED_LOCALES:
            value = None
            locale_entry = localizations.get(locale)
            if isinstance(locale_entry, dict):
                value = locale_entry.get("stringUnit", {}).get("value")

            if not isinstance(value, str):
                missing_entries.append(f"{key} [{locale}]")
                continue

            localized_placeholders = extract_placeholders(value)
            if localized_placeholders != english_placeholders:
                placeholder_mismatches.append(
                    f"{key} [{locale}] expected {english_placeholders} got {localized_placeholders}"
                )

    if missing_entries or placeholder_mismatches:
        print("Localization check failed.")
        if missing_entries:
            print(f"- Missing translations: {len(missing_entries)}")
            for item in missing_entries[:80]:
                print(f"  - {item}")
            if len(missing_entries) > 80:
                print(f"  ... and {len(missing_entries) - 80} more")

        if placeholder_mismatches:
            print(f"- Placeholder mismatches: {len(placeholder_mismatches)}")
            for item in placeholder_mismatches[:80]:
                print(f"  - {item}")
            if len(placeholder_mismatches) > 80:
                print(f"  ... and {len(placeholder_mismatches) - 80} more")
        return 1

    print(
        "Localization check passed: "
        f"{checked_keys} keys validated across {len(REQUIRED_LOCALES)} required locales."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
