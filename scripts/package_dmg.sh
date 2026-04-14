#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/package_dmg.sh [options]

Options:
  --scheme <name>           Xcode scheme (default: Moaiy)
  --configuration <name>    Build configuration (default: Debug)
  --arch <arch>             Target architecture (arm64 or x86_64)
  --version <X.Y.Z>         Expected app version; fails on mismatch
  --artifact-name <name>    Output DMG filename (default: generated with timestamp)
  --derived-data <path>     DerivedData path (default: <repo>/build/DerivedData)
  --dist-dir <path>         Output directory for DMG (default: <repo>/dist)
  --allow-unsigned-release  Skip Release signing preflight (unsafe; CI/local fallback only)
  --skip-build              Skip xcodebuild and package existing .app
  --open                    Reveal generated DMG in Finder
  -h, --help                Show this help

Examples:
  ./scripts/package_dmg.sh
  ./scripts/package_dmg.sh --arch arm64 --version 0.5.3
  ./scripts/package_dmg.sh --arch x86_64 --version 0.5.3 --artifact-name Moaiy-0.5.3-macos-intel-chip.dmg
  ./scripts/package_dmg.sh --configuration Release
  ./scripts/package_dmg.sh --skip-build --open
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"

SCHEME="Moaiy"
CONFIGURATION="Debug"
ARCH=""
EXPECTED_VERSION=""
ARTIFACT_NAME=""
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
ALLOW_UNSIGNED_RELEASE=false
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
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    --version)
      EXPECTED_VERSION="${2:-}"
      shift 2
      ;;
    --artifact-name)
      ARTIFACT_NAME="${2:-}"
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
    --allow-unsigned-release)
      ALLOW_UNSIGNED_RELEASE=true
      shift
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

if [[ -n "$ARCH" && "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "ERROR: --arch must be arm64 or x86_64"
  exit 1
fi

if [[ -n "$EXPECTED_VERSION" && ! "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: --version must match X.Y.Z"
  exit 1
fi

if [[ -n "$ARTIFACT_NAME" ]]; then
  if [[ "$ARTIFACT_NAME" != *.dmg ]]; then
    ARTIFACT_NAME="${ARTIFACT_NAME}.dmg"
  fi
  ARTIFACT_NAME="$(basename "$ARTIFACT_NAME")"
fi

if [[ "$CONFIGURATION" == "Release" && "$ALLOW_UNSIGNED_RELEASE" == false ]]; then
  "$ROOT_DIR/scripts/appstore-preflight.sh" "$SCHEME" "$CONFIGURATION"
fi

mkdir -p "$DERIVED_DATA_PATH" "$DIST_DIR"

DESTINATION="platform=macOS"
ARCH_TAG=""
if [[ -n "$ARCH" ]]; then
  DESTINATION="platform=macOS,arch=$ARCH"
  ARCH_TAG="-$ARCH"
fi

if [[ "$SKIP_BUILD" == false ]]; then
  echo "Building app (scheme=$SCHEME, configuration=$CONFIGURATION, destination=$DESTINATION)..."
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
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
if [[ -n "$EXPECTED_VERSION" && "$VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "ERROR: app version mismatch (expected=$EXPECTED_VERSION actual=$VERSION)"
  echo "Tip: sync MARKETING_VERSION and rebuild before packaging."
  exit 1
fi

CONFIG_TAG="$(printf '%s' "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
if [[ -n "$ARTIFACT_NAME" ]]; then
  DMG_PATH="$DIST_DIR/$ARTIFACT_NAME"
else
  DMG_PATH="$DIST_DIR/${SCHEME}-${VERSION}-${CONFIG_TAG}${ARCH_TAG}-${TIMESTAMP}.dmg"
fi
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
echo "Version: $VERSION"
echo "Architecture: ${ARCH:-auto}"

if [[ "$REVEAL_IN_FINDER" == true ]]; then
  open -R "$DMG_PATH"
fi
