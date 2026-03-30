#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"
SCHEME="${1:-Moaiy}"
CONFIGURATION="${2:-Release}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: project not found at $PROJECT_PATH"
  exit 1
fi

BUILD_SETTINGS="$(
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null
)"

if [[ -z "$BUILD_SETTINGS" ]]; then
  echo "ERROR: unable to read build settings for scheme '$SCHEME' ($CONFIGURATION)"
  exit 1
fi

DEVELOPMENT_TEAM="$(
  printf '%s\n' "$BUILD_SETTINGS" \
    | sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM = //p' \
    | head -n 1 \
    | xargs
)"

if [[ "$CONFIGURATION" == "Release" ]]; then
  if [[ -z "$DEVELOPMENT_TEAM" || "$DEVELOPMENT_TEAM" == "__TEAM_ID_PLACEHOLDER__" || "$DEVELOPMENT_TEAM" == "YOUR_TEAM_ID" ]]; then
    echo "ERROR: Release build has no valid DEVELOPMENT_TEAM."
    echo "Set MOAIY_DEVELOPMENT_TEAM_ID in Moaiy/Config/Moaiy.Signing.xcconfig (or an included local override)."
    exit 1
  fi
fi

echo "Preflight passed: scheme=$SCHEME configuration=$CONFIGURATION team=$DEVELOPMENT_TEAM"
