#!/usr/bin/env bash
#
# sign_embedded_gpg_bundle.sh
# Moaiy
#
# Signs the embedded gpg.bundle inside Moaiy.app/Contents/Resources/gpg.bundle
# with child App Sandbox inheritance entitlements (GPGHelper.entitlements).
#
# Why this runs on the embedded .app bundle copy (and not the raw source tree copy):
# macOS libSystem_secinit aborts any executable signed with
# com.apple.security.inherit=true if it is launched by an unsandboxed parent
# (such as bash, swift test runners, or MoaiyCLI). Keeping the source-tree
# Moaiy/Resources/gpg.bundle ad-hoc signed without inherit allows CLI/test
# tools to execute it, while signing the copy inside Moaiy.app with
# GPGHelper.entitlements satisfies Mac App Store child process sandbox inheritance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_ENTITLEMENTS="${HELPER_ENTITLEMENTS:-$PROJECT_ROOT/Moaiy/Resources/GPGHelper.entitlements}"

if [[ $# -ge 1 ]]; then
  EMBEDDED_BUNDLE_PATH="$1"
elif [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
  EMBEDDED_BUNDLE_PATH="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/gpg.bundle"
else
  echo "Usage: $0 <path-to-embedded-gpg.bundle>"
  exit 1
fi

if [[ ! -d "$EMBEDDED_BUNDLE_PATH" ]]; then
  echo "ERROR: Embedded gpg.bundle not found at: $EMBEDDED_BUNDLE_PATH"
  exit 1
fi

if [[ ! -f "$HELPER_ENTITLEMENTS" ]]; then
  echo "ERROR: Helper entitlements file not found at: $HELPER_ENTITLEMENTS"
  exit 1
fi

SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${GPG_CODESIGN_IDENTITY:--}}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

echo "Signing embedded gpg.bundle at $EMBEDDED_BUNDLE_PATH (identity: $SIGN_IDENTITY)..."

# 1. Sign dynamic libraries first (inside-out signing, no entitlements on dylibs)
for lib in "$EMBEDDED_BUNDLE_PATH/lib"/*.dylib; do
  if [[ -f "$lib" ]]; then
    codesign --remove-signature "$lib" 2>/dev/null || true
    codesign --force --timestamp=none -s "$SIGN_IDENTITY" "$lib"
  fi
done

# 2. Sign executables with sandbox inheritance entitlements
for exe in "$EMBEDDED_BUNDLE_PATH/bin"/*; do
  if [[ -f "$exe" ]]; then
    codesign --remove-signature "$exe" 2>/dev/null || true
    codesign --force --timestamp=none --entitlements "$HELPER_ENTITLEMENTS" -s "$SIGN_IDENTITY" "$exe"
  fi
done

echo "Embedded gpg.bundle signed successfully with sandbox inheritance entitlements."
