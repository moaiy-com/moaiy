#!/usr/bin/env bash
#
# Compile the bundled pinentry into an already-copied gpg.bundle.
# The helper is signed afterwards by scripts/sign_embedded_gpg_bundle.sh
# with app-sandbox + inherit (or ad-hoc, when the host app is unsigned).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/moaiy-pinentry.c"

if [[ $# -ge 1 ]]; then
  BUNDLE_PATH="$1"
elif [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
  BUNDLE_PATH="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/gpg.bundle"
else
  echo "Usage: $0 <path-to-gpg.bundle>"
  exit 1
fi

if [[ ! -d "$BUNDLE_PATH/bin" ]]; then
  echo "ERROR: gpg.bundle bin directory not found at: $BUNDLE_PATH/bin"
  exit 1
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "ERROR: pinentry source not found at: $SOURCE_FILE"
  exit 1
fi

OUTPUT_PATH="$BUNDLE_PATH/bin/pinentry"
echo "Compiling moaiy pinentry to $OUTPUT_PATH"
clang -Os -mmacosx-version-min=14.0 -Wall -Wextra -Werror -o "$OUTPUT_PATH" "$SOURCE_FILE"
chmod 755 "$OUTPUT_PATH"
