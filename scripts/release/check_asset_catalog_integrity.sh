#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_FILE="$ROOT_DIR/Moaiy/Moaiy.xcodeproj/project.pbxproj"
ASSET_ICON_DIR="$ROOT_DIR/Moaiy/Resources/Assets.xcassets/moaiy_icon.icon"
LEGACY_ICON_DIR="$ROOT_DIR/Moaiy/Resources/moaiy_icon.icon"

failed=0

echo "Checking asset catalog integrity..."
echo "  project file: $PROJECT_FILE"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "ERROR: project file not found: $PROJECT_FILE"
  exit 1
fi

if ! grep -Fq 'ASSETCATALOG_COMPILER_APPICON_NAME = moaiy_icon;' "$PROJECT_FILE"; then
  echo "ERROR: app icon compiler name must remain 'moaiy_icon'"
  failed=1
fi

if grep -Fq 'moaiy_icon.icon in Resources' "$PROJECT_FILE"; then
  echo "ERROR: standalone moaiy_icon.icon must not be added to Resources build phase"
  failed=1
fi

if grep -Eq 'path = moaiy_icon\.icon;' "$PROJECT_FILE"; then
  echo "ERROR: standalone file reference path = moaiy_icon.icon detected in project"
  failed=1
fi

if [[ ! -d "$ASSET_ICON_DIR" ]]; then
  echo "ERROR: expected icon asset directory missing: $ASSET_ICON_DIR"
  failed=1
fi

if [[ -d "$LEGACY_ICON_DIR" ]]; then
  echo "ERROR: legacy standalone icon directory must not exist: $LEGACY_ICON_DIR"
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "Asset catalog integrity check failed."
  exit 1
fi

echo "Asset catalog integrity check passed."
