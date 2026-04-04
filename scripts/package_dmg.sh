#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/package_dmg.sh [options]

Options:
  --scheme <name>           Xcode scheme (default: Moaiy)
  --configuration <name>    Build configuration (default: Debug)
  --derived-data <path>     DerivedData path (default: <repo>/build/DerivedData)
  --dist-dir <path>         Output directory for DMG (default: <repo>/dist)
  --skip-build              Skip xcodebuild and package existing .app
  --open                    Reveal generated DMG in Finder
  -h, --help                Show this help

Examples:
  ./scripts/package_dmg.sh
  ./scripts/package_dmg.sh --configuration Release
  ./scripts/package_dmg.sh --skip-build --open
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"

SCHEME="Moaiy"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
SKIP_BUILD=false
REVEAL_IN_FINDER=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --dist-dir)
      DIST_DIR="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --open)
      REVEAL_IN_FINDER=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option '$1'"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: project not found at $PROJECT_PATH"
  exit 1
fi

if [[ "$CONFIGURATION" == "Release" ]]; then
  "$ROOT_DIR/scripts/appstore-preflight.sh" "$SCHEME" "$CONFIGURATION"
fi

mkdir -p "$DERIVED_DATA_PATH" "$DIST_DIR"

if [[ "$SKIP_BUILD" == false ]]; then
  echo "Building app (scheme=$SCHEME, configuration=$CONFIGURATION)..."
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION" -maxdepth 1 -name '*.app' -print | head -n 1 || true)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: .app not found in $DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
CONFIG_TAG="$(printf '%s' "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DMG_PATH="$DIST_DIR/${SCHEME}-${VERSION}-${CONFIG_TAG}-${TIMESTAMP}.dmg"
STAGE_DIR="$(mktemp -d "/tmp/moaiy-dmg-stage.${TIMESTAMP}.XXXXXX")"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

echo "Creating DMG..."
hdiutil create \
  -volname "$SCHEME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

SIZE_HUMAN="$(du -h "$DMG_PATH" | awk '{print $1}')"
SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

echo "DMG created: $DMG_PATH"
echo "Size: $SIZE_HUMAN"
echo "SHA-256: $SHA256"

if [[ "$REVEAL_IN_FINDER" == true ]]; then
  open -R "$DMG_PATH"
fi

