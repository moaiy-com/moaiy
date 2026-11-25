#!/usr/bin/env bash
#
# sign_embedded_gpg_bundle.sh
# Moaiy
#
# Signs the embedded gpg.bundle inside Moaiy.app/Contents/Resources/gpg.bundle.
#
# Most helpers (gpg, gpg-agent, gpgconf, gpg-connect-agent, pinentry) are
# signed with GPGHelper.entitlements: app-sandbox + inherit only. They must
# stay inherit-only. Extra entitlements make libsecinit stop treating them as
# pure inherit children and look for a CFBundleIdentifier. These CLI tools have
# none, so sandbox init SIGTRAPs (exit 5) before gpg can list keys.
#
# scdaemon is the exception. ctkpcscd checks the helper's own signature for
# com.apple.security.smartcard, which inherit does not supply. scdaemon is
# signed with GPGScdaemon.entitlements (sandbox + inherit + smartcard + usb).
# Because those device entitlements are present, its code signature must also
# carry an Info.plist with CFBundleIdentifier. That plist is
# Moaiy/Resources/ScdaemonInfo.plist (com.moaiy.app.scdaemon). It is embedded
# by signing a temporary one-file bundle: codesign stores the bundle Info.plist
# in the Mach-O signature's Info.plist slot, and that signed binary is copied
# back. Do not re-sign the bare scdaemon afterwards or the slot is dropped.
# Do not put device entitlements on any other helper.
#
# Why this runs on the embedded .app bundle copy (and not the raw source tree copy):
# macOS libSystem_secinit aborts any executable signed with
# com.apple.security.inherit=true if it is launched by an unsandboxed parent
# (such as bash, swift test runners, or MoaiyCLI). Keeping the source-tree
# Moaiy/Resources/gpg.bundle ad-hoc signed without inherit allows CLI/test
# tools to execute it, while signing the copy inside Moaiy.app satisfies
# Mac App Store child process sandbox inheritance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_ENTITLEMENTS="${HELPER_ENTITLEMENTS:-$PROJECT_ROOT/Moaiy/Resources/GPGHelper.entitlements}"
SCDAEMON_ENTITLEMENTS="${SCDAEMON_ENTITLEMENTS:-$PROJECT_ROOT/Moaiy/Resources/GPGScdaemon.entitlements}"
SCDAEMON_INFO_PLIST="${SCDAEMON_INFO_PLIST:-$PROJECT_ROOT/Moaiy/Resources/ScdaemonInfo.plist}"

SIGN_ONE_EXECUTABLE=""
if [[ "${1:-}" == "--executable" ]]; then
  SIGN_ONE_EXECUTABLE="${2:-}"
  if [[ -z "$SIGN_ONE_EXECUTABLE" || ! -f "$SIGN_ONE_EXECUTABLE" ]]; then
    echo "Usage: $0 --executable <path-to-bundled-gpg-executable>"
    exit 1
  fi
fi

sign_scdaemon_with_bundle_identifier() {
  local exe="$1"
  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/moaiy-scdaemon-sign.XXXXXX")"
  mkdir -p "$work/Scdaemon.app/Contents/MacOS"
  cp "$exe" "$work/Scdaemon.app/Contents/MacOS/scdaemon"
  cp "$SCDAEMON_INFO_PLIST" "$work/Scdaemon.app/Contents/Info.plist"
  chmod 755 "$work/Scdaemon.app/Contents/MacOS/scdaemon"
  codesign --remove-signature "$work/Scdaemon.app/Contents/MacOS/scdaemon" 2>/dev/null || true
  # Signing the bundle (not the bare Mach-O) copies ScdaemonInfo.plist into the
  # code signature Info.plist slot, including CFBundleIdentifier.
  codesign --force --timestamp=none \
    --identifier "com.moaiy.app.scdaemon" \
    --entitlements "$SCDAEMON_ENTITLEMENTS" \
    -s "$SIGN_IDENTITY" \
    "$work/Scdaemon.app"
  cp "$work/Scdaemon.app/Contents/MacOS/scdaemon" "$exe"
  chmod 755 "$exe"
  rm -rf "$work"
}

sign_one_executable() {
  local exe="$1"
  local exe_name
  exe_name="$(basename "$exe")"
  codesign --remove-signature "$exe" 2>/dev/null || true
  if [[ "$exe_name" == "scdaemon" ]]; then
    sign_scdaemon_with_bundle_identifier "$exe"
  else
    codesign --force --timestamp=none --entitlements "$HELPER_ENTITLEMENTS" -s "$SIGN_IDENTITY" "$exe"
  fi
}

if [[ -n "$SIGN_ONE_EXECUTABLE" ]]; then
  if [[ ! -f "$HELPER_ENTITLEMENTS" || ! -f "$SCDAEMON_ENTITLEMENTS" || ! -f "$SCDAEMON_INFO_PLIST" ]]; then
    echo "ERROR: helper entitlements or ScdaemonInfo.plist missing"
    exit 1
  fi
  SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${GPG_CODESIGN_IDENTITY:--}}"
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
  fi
  if [[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]]; then
    codesign --remove-signature "$SIGN_ONE_EXECUTABLE" 2>/dev/null || true
    codesign --force --timestamp=none -s - "$SIGN_ONE_EXECUTABLE"
    exit 0
  fi
  sign_one_executable "$SIGN_ONE_EXECUTABLE"
  exit 0
fi

if [[ $# -ge 1 ]]; then
  EMBEDDED_BUNDLE_PATH="$1"
elif [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
  EMBEDDED_BUNDLE_PATH="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/gpg.bundle"
else
  echo "Usage: $0 <path-to-embedded-gpg.bundle>"
  echo "       $0 --executable <path-to-one-bundled-executable>"
  exit 1
fi

if [[ ! -d "$EMBEDDED_BUNDLE_PATH" ]]; then
  echo "ERROR: Embedded gpg.bundle not found at: $EMBEDDED_BUNDLE_PATH"
  exit 1
fi

if [[ ! -f "$HELPER_ENTITLEMENTS" || ! -f "$SCDAEMON_ENTITLEMENTS" || ! -f "$SCDAEMON_INFO_PLIST" ]]; then
  echo "ERROR: helper entitlements or ScdaemonInfo.plist missing"
  exit 1
fi

SIGN_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${GPG_CODESIGN_IDENTITY:--}}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

# When Xcode is told not to sign (e.g. CI: CODE_SIGNING_ALLOWED=NO), the host
# Moaiy.app is not sandboxed. Helpers carrying com.apple.security.inherit would
# then be aborted by libSystem_secinit at launch (SIGTRAP, exit code 5), so sign
# them ad-hoc WITHOUT entitlements in that case.
if [[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" ]]; then
  echo "CODE_SIGNING_ALLOWED=NO: host app is unsandboxed; ad-hoc signing embedded gpg.bundle without inherit entitlements."
  for f in "$EMBEDDED_BUNDLE_PATH/lib"/*.dylib "$EMBEDDED_BUNDLE_PATH/bin"/*; do
    if [[ -f "$f" ]]; then
      codesign --remove-signature "$f" 2>/dev/null || true
      codesign --force --timestamp=none -s - "$f"
    fi
  done
  exit 0
fi

echo "Signing embedded gpg.bundle at $EMBEDDED_BUNDLE_PATH (identity: $SIGN_IDENTITY)..."

# 1. Sign dynamic libraries first (inside-out signing, no entitlements on dylibs)
for lib in "$EMBEDDED_BUNDLE_PATH/lib"/*.dylib; do
  if [[ -f "$lib" ]]; then
    codesign --remove-signature "$lib" 2>/dev/null || true
    codesign --force --timestamp=none -s "$SIGN_IDENTITY" "$lib"
  fi
done

# 2. Inherit-only helpers, plus scdaemon with its own device entitlements and bundle id.
for exe in "$EMBEDDED_BUNDLE_PATH/bin"/*; do
  if [[ -f "$exe" ]]; then
    sign_one_executable "$exe"
  fi
done

echo "Embedded gpg.bundle signed. Helpers use inherit-only entitlements; scdaemon also has smartcard, USB, and CFBundleIdentifier."
