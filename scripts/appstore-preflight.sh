#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"
ENTITLEMENTS_PATH="$ROOT_DIR/Moaiy/Resources/Entitlements.entitlements"
HELPER_ENTITLEMENTS_PATH="$ROOT_DIR/Moaiy/Resources/GPGHelper.entitlements"
SCDAEMON_ENTITLEMENTS_PATH="$ROOT_DIR/Moaiy/Resources/GPGScdaemon.entitlements"
SCDAEMON_INFO_PLIST_PATH="$ROOT_DIR/Moaiy/Resources/ScdaemonInfo.plist"
PRIVACY_MANIFEST_PATH="$ROOT_DIR/Moaiy/PrivacyInfo.xcprivacy"
INFO_PLIST_PATH="$ROOT_DIR/Moaiy/Info.plist"

ALLOW_UNSIGNED_CI=false
POSITIONAL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --allow-unsigned-ci)
      ALLOW_UNSIGNED_CI=true
      ;;
    *)
      POSITIONAL_ARGS+=("$arg")
      ;;
  esac
done

SCHEME="${POSITIONAL_ARGS[0]:-Moaiy}"
CONFIGURATION="${POSITIONAL_ARGS[1]:-Release}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: project not found at $PROJECT_PATH"
  exit 1
fi

echo "==> [1/4] Validating MAS entitlements & privacy manifest..."
for plist_file in "$ENTITLEMENTS_PATH" "$HELPER_ENTITLEMENTS_PATH" "$SCDAEMON_ENTITLEMENTS_PATH" "$SCDAEMON_INFO_PLIST_PATH" "$PRIVACY_MANIFEST_PATH" "$INFO_PLIST_PATH"; do
  if [[ ! -f "$plist_file" ]]; then
    echo "ERROR: required plist missing at $plist_file"
    exit 1
  fi
  plutil -lint "$plist_file" >/dev/null
done

if ! grep -q "com.apple.security.app-sandbox" "$ENTITLEMENTS_PATH"; then
  echo "ERROR: Entitlements.entitlements is missing com.apple.security.app-sandbox."
  exit 1
fi

if ! grep -q "com.apple.security.inherit" "$HELPER_ENTITLEMENTS_PATH"; then
  echo "ERROR: GPGHelper.entitlements is missing com.apple.security.inherit (required for bundled GPG subprocesses)."
  exit 1
fi

for forbidden_helper_key in "com.apple.security.smartcard" "com.apple.security.device.usb"; do
  if grep -q "$forbidden_helper_key" "$HELPER_ENTITLEMENTS_PATH"; then
    echo "ERROR: GPGHelper.entitlements must stay inherit-only; found $forbidden_helper_key."
    echo "Device entitlements on gpg/gpg-agent make secinit SIGTRAP (no CFBundleIdentifier)."
    exit 1
  fi
done

for scdaemon_key in "com.apple.security.app-sandbox" "com.apple.security.inherit" "com.apple.security.smartcard" "com.apple.security.device.usb"; do
  if ! grep -q "$scdaemon_key" "$SCDAEMON_ENTITLEMENTS_PATH"; then
    echo "ERROR: GPGScdaemon.entitlements is missing $scdaemon_key."
    exit 1
  fi
done

if ! grep -q "com.moaiy.app.scdaemon" "$SCDAEMON_INFO_PLIST_PATH"; then
  echo "ERROR: ScdaemonInfo.plist is missing CFBundleIdentifier com.moaiy.app.scdaemon."
  exit 1
fi

for required_api in "NSPrivacyAccessedAPICategoryUserDefaults" "NSPrivacyAccessedAPICategoryDiskSpace" "NSPrivacyAccessedAPICategoryFileTimestamp"; do
  if ! grep -q "$required_api" "$PRIVACY_MANIFEST_PATH"; then
    echo "ERROR: PrivacyInfo.xcprivacy is missing required API category: $required_api"
    exit 1
  fi
done

if ! grep -q "ITSAppUsesNonExemptEncryption" "$INFO_PLIST_PATH"; then
  echo "ERROR: Info.plist is missing ITSAppUsesNonExemptEncryption export compliance key."
  exit 1
fi

echo "==> [2/4] Validating bundled GPG integrity & MAS helper signing script..."
SCDAEMON_BIN="$ROOT_DIR/Moaiy/Resources/gpg.bundle/bin/scdaemon"
if ! python3 "$ROOT_DIR/scripts/check_scdaemon_info_plist.py" "$SCDAEMON_BIN"; then
  echo "ERROR: scdaemon Info.plist is not bound (codesign would report Info.plist=not bound)."
  exit 1
fi
if command -v codesign >/dev/null 2>&1; then
  codesign_detail="$(codesign -d --verbose=2 "$SCDAEMON_BIN" 2>&1 || true)"
  printf '%s\n' "$codesign_detail"
  if printf '%s\n' "$codesign_detail" | grep -q "Info.plist=not bound"; then
    echo "ERROR: codesign reports Info.plist=not bound for scdaemon."
    exit 1
  fi
  if ! printf '%s\n' "$codesign_detail" | grep -q "Identifier=com.moaiy.app.scdaemon"; then
    echo "ERROR: scdaemon codesign identifier is not com.moaiy.app.scdaemon."
    exit 1
  fi
fi
if command -v otool >/dev/null 2>&1; then
  otool_plist="$(otool -P "$SCDAEMON_BIN" 2>/dev/null || true)"
  printf '%s\n' "$otool_plist"
  if ! printf '%s\n' "$otool_plist" | grep -q "com.moaiy.app.scdaemon"; then
    echo "ERROR: otool -P did not print CFBundleIdentifier com.moaiy.app.scdaemon."
    exit 1
  fi
fi
"$ROOT_DIR/scripts/verify_gpg_bundle.sh" >/dev/null

echo "==> [3/4] Checking external support/privacy URLs referenced in app..."
for url in "https://moaiy.com/privacy" "https://moaiy.com/doc/help"; do
  if grep -rq "$url" "$ROOT_DIR/Moaiy/"; then
    echo "  Verified reference to $url (ensure HTTP 200 before App Store Review submission)"
  fi
done

echo "==> [4/4] Checking Xcode build settings ($SCHEME / $CONFIGURATION)..."
if xcodebuild -version >/dev/null 2>&1; then
  BUILD_SETTINGS="$(
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration "$CONFIGURATION" \
      -showBuildSettings 2>/dev/null || true
  )"

  if [[ -n "$BUILD_SETTINGS" ]]; then
    DEVELOPMENT_TEAM="$(
      printf '%s\n' "$BUILD_SETTINGS" \
        | sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM = //p' \
        | head -n 1 \
        | xargs
    )"

    if [[ "$CONFIGURATION" == "Release" && "$ALLOW_UNSIGNED_CI" == false ]]; then
      if [[ -z "$DEVELOPMENT_TEAM" || "$DEVELOPMENT_TEAM" == "__TEAM_ID_PLACEHOLDER__" || "$DEVELOPMENT_TEAM" == "YOUR_TEAM_ID" ]]; then
        echo "ERROR: Release build has no valid DEVELOPMENT_TEAM."
        echo "Set MOAIY_DEVELOPMENT_TEAM_ID in Moaiy/Config/Moaiy.Signing.xcconfig (or an included local override)."
        exit 1
      fi
    fi
    if [[ "$ALLOW_UNSIGNED_CI" == true ]]; then
      echo "Preflight passed (unsigned CI mode): scheme=$SCHEME configuration=$CONFIGURATION (DEVELOPMENT_TEAM check skipped)"
    else
      echo "Preflight passed: scheme=$SCHEME configuration=$CONFIGURATION team=$DEVELOPMENT_TEAM"
    fi
  else
    echo "WARN: xcodebuild -showBuildSettings unavailable on current host; static MAS preflight checks passed."
  fi
else
  echo "WARN: Full Xcode not active on current host; static MAS preflight checks passed."
fi
