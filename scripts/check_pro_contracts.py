#!/usr/bin/env python3
"""Validate Pro contracts versioning and feature-to-product mapping consistency."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SEMVER_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
PRODUCT_ID_PATTERN = re.compile(r"^com\.moaiy\.pro\.[a-z0-9_]+$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check Pro contract semantic version and product manifest mapping."
    )
    parser.add_argument(
        "--app-state",
        default="Moaiy/ViewModels/AppState.swift",
        help="Path to AppState.swift where ProFeature is defined.",
    )
    parser.add_argument(
        "--constants",
        default="Moaiy/Utils/Constants.swift",
        help="Path to Constants.swift where Pro manifest is defined.",
    )
    return parser.parse_args()


def load_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")
    return path.read_text(encoding="utf-8")


def extract_enum_body(source: str, enum_name: str) -> str:
    enum_marker = f"enum {enum_name}"
    start = source.find(enum_marker)
    if start == -1:
        raise ValueError(f"Unable to locate `{enum_marker}` in source.")

    body_start = source.find("{", start)
    if body_start == -1:
        raise ValueError(f"Unable to parse `{enum_name}` body start.")

    depth = 0
    for index in range(body_start, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[body_start + 1 : index]

    raise ValueError(f"Unable to parse `{enum_name}` body end.")


def extract_pro_features(app_state_source: str) -> list[str]:
    enum_body = extract_enum_body(app_state_source, "ProFeature")
    features: list[str] = []

    for line in enum_body.splitlines():
        stripped = line.strip()
        if not stripped.startswith("case "):
            continue

        declaration = stripped.removeprefix("case ").split("//", 1)[0].strip()
        for token in declaration.split(","):
            candidate = token.strip()
            if not candidate:
                continue
            if candidate.startswith(".") or ":" in candidate:
                continue
            feature_name = candidate.split("(", 1)[0].split("=", 1)[0].strip()
            if feature_name:
                features.append(feature_name)

    if not features:
        raise ValueError("No ProFeature cases found.")
    return features


def extract_feature_to_product_map(constants_source: str) -> dict[str, str]:
    marker = "static let featureToProductID"
    start = constants_source.find(marker)
    if start == -1:
        raise ValueError("Unable to locate `featureToProductID` mapping.")

    assignment_start = constants_source.find("=", start)
    if assignment_start == -1:
        raise ValueError("Unable to locate `featureToProductID` assignment.")

    mapping_start = constants_source.find("[", assignment_start)
    if mapping_start == -1:
        raise ValueError("Unable to parse `featureToProductID` mapping start.")

    depth = 0
    mapping_end = -1
    for index in range(mapping_start, len(constants_source)):
        char = constants_source[index]
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                mapping_end = index
                break

    if mapping_end == -1:
        raise ValueError("Unable to parse `featureToProductID` mapping end.")

    mapping_body = constants_source[mapping_start + 1 : mapping_end]
    entries = re.findall(r"\.(\w+)\s*:\s*\"([^\"]+)\"", mapping_body)
    if not entries:
        raise ValueError("No entries found in `featureToProductID` mapping.")

    result: dict[str, str] = {}
    for feature, product_id in entries:
        if feature in result:
            raise ValueError(f"Duplicate Pro feature key in mapping: {feature}")
        result[feature] = product_id
    return result


def extract_contract_semver(constants_source: str) -> str:
    match = re.search(
        r"contractsSemanticVersion\s*=\s*\"([0-9]+\.[0-9]+\.[0-9]+)\"",
        constants_source,
    )
    if not match:
        raise ValueError("Unable to locate `contractsSemanticVersion` in Constants.Pro.")
    return match.group(1)


def main() -> int:
    args = parse_args()

    app_state_path = Path(args.app_state)
    constants_path = Path(args.constants)

    try:
        app_state_source = load_text(app_state_path)
        constants_source = load_text(constants_path)
    except FileNotFoundError as error:
        print(f"ERROR: {error}")
        return 1

    try:
        features = extract_pro_features(app_state_source)
        mapping = extract_feature_to_product_map(constants_source)
        semver = extract_contract_semver(constants_source)
    except ValueError as error:
        print(f"ERROR: {error}")
        return 1

    issues: list[str] = []

    if not SEMVER_PATTERN.fullmatch(semver):
        issues.append(f"Invalid semantic version: {semver}")

    feature_set = set(features)
    mapping_key_set = set(mapping.keys())

    missing_mapping = sorted(feature_set - mapping_key_set)
    extra_mapping = sorted(mapping_key_set - feature_set)
    if missing_mapping:
        issues.append(f"Missing product mapping for features: {', '.join(missing_mapping)}")
    if extra_mapping:
        issues.append(f"Unknown mapped features not in ProFeature enum: {', '.join(extra_mapping)}")

    product_ids = list(mapping.values())
    duplicate_product_ids = sorted(
        product_id for product_id in set(product_ids) if product_ids.count(product_id) > 1
    )
    if duplicate_product_ids:
        issues.append(f"Duplicate product IDs: {', '.join(duplicate_product_ids)}")

    invalid_product_ids = sorted(
        product_id for product_id in product_ids if not PRODUCT_ID_PATTERN.fullmatch(product_id)
    )
    if invalid_product_ids:
        issues.append(f"Invalid product ID format: {', '.join(invalid_product_ids)}")

    if issues:
        print("Pro contracts check failed.")
        for issue in issues:
            print(f"- {issue}")
        return 1

    print(
        "Pro contracts check passed: "
        f"{len(features)} features, {len(mapping)} product mappings, "
        f"contractsSemanticVersion={semver}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
