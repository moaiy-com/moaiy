#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_ICONSET="$REPO_ROOT/Moaiy/Resources/Assets.xcassets/AppIcon.appiconset"

usage() {
  cat <<'EOF'
Usage:
  scripts/generate_app_iconset.sh <source-image> [iconset-path]

Arguments:
  source-image   Path to source image (PNG/JPG). Square is recommended.
  iconset-path   Optional target AppIcon.appiconset directory.
                 Default: Moaiy/Resources/Assets.xcassets/AppIcon.appiconset

Example:
  scripts/generate_app_iconset.sh ~/Desktop/moaiy-icon.png
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

SOURCE_IMAGE="$1"
ICONSET_DIR="${2:-$DEFAULT_ICONSET}"

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Error: source image not found: $SOURCE_IMAGE" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: sips is required on macOS." >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"

TMP_DIR="$(mktemp -d /tmp/moaiy-appicon-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

WORK_IMAGE="$TMP_DIR/work.png"
MASTER_IMAGE="$TMP_DIR/master-1024.png"

WIDTH="$(sips -g pixelWidth "$SOURCE_IMAGE" | awk '/pixelWidth:/{print $2}')"
HEIGHT="$(sips -g pixelHeight "$SOURCE_IMAGE" | awk '/pixelHeight:/{print $2}')"

if [[ -z "$WIDTH" || -z "$HEIGHT" ]]; then
  echo "Error: failed to read source image dimensions." >&2
  exit 1
fi

if [[ "$WIDTH" -ne "$HEIGHT" ]]; then
  CROP_SIZE="$WIDTH"
  if [[ "$HEIGHT" -lt "$WIDTH" ]]; then
    CROP_SIZE="$HEIGHT"
  fi
  echo "Info: source image is not square, center-cropping to ${CROP_SIZE}x${CROP_SIZE}."
  sips --cropToHeightWidth "$CROP_SIZE" "$CROP_SIZE" "$SOURCE_IMAGE" --out "$WORK_IMAGE" >/dev/null
else
  cp "$SOURCE_IMAGE" "$WORK_IMAGE"
fi

sips --setProperty format png -z 1024 1024 "$WORK_IMAGE" --out "$MASTER_IMAGE" >/dev/null

generate_icon() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$MASTER_IMAGE" --out "$ICONSET_DIR/$filename" >/dev/null
}

generate_icon 16   "icon_16x16.png"
generate_icon 32   "icon_16x16@2x.png"
generate_icon 32   "icon_32x32.png"
generate_icon 64   "icon_32x32@2x.png"
generate_icon 128  "icon_128x128.png"
generate_icon 256  "icon_128x128@2x.png"
generate_icon 256  "icon_256x256.png"
generate_icon 512  "icon_256x256@2x.png"
generate_icon 512  "icon_512x512.png"
generate_icon 1024 "icon_512x512@2x.png"

cat >"$ICONSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Done. Generated app icons in:"
echo "  $ICONSET_DIR"
echo "Now open Xcode and verify Assets.xcassets > AppIcon."
