#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Moaiy/Moaiy.xcodeproj"
ENTITLEMENTS_PATH="$ROOT_DIR/Moaiy/Resources/Entitlements.entitlements"
HELPER_ENTITLEMENTS_PATH="$ROOT_DIR/Moaiy/Resources/GPGHelper.entitlements"
PRIVACY_MANIFEST_PATH="$ROOT_DIR/Moaiy/PrivacyInfo.xcprivacy"
INFO_PLIST_PATH="$ROOT_DIR/Moaiy/Info.plist"
SCHEME="${1:-Moaiy}"
CONFIGURATION="${2:-Release}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "ERROR: project not found at $PROJECT_PATH"
  exit 1
fi

echo "==> [1/4] Validating MAS entitlements & privacy manifest..."
for plist_file in "$ENTITLEMENTS_PATH" "$HELPER_ENTITLEMENTS_PATH" "$PRIVACY_MANIFEST_PATH" "$INFO_PLIST_PATH"; do
  if [[ ! -f "$plist_file" ]]; then
    echo "ERROR: required plist missing at $plist_file"
    exit 1
  fi
  plutil -lint "$plist_file" >/dev/null
done

if ! grep -q "keychain-access-groups" "$ENTITLEMENTS_PATH"; then
  echo "ERROR: Entitlements.entitlements is missing keychain-access-groups (required for Data Protection Keychain)."
  exit 1
fi

if ! grep -q "com.apple.security.inherit" "$HELPER_ENTITLEMENTS_PATH"; then
  echo "ERROR: GPGHelper.entitlements is missing com.apple.security.inherit (required for bundled GPG subprocesses)."
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

    if [[ "$CONFIGURATION" == "Release" ]]; then
      if [[ -z "$DEVELOPMENT_TEAM" || "$DEVELOPMENT_TEAM" == "__TEAM_ID_PLACEHOLDER__" || "$DEVELOPMENT_TEAM" == "YOUR_TEAM_ID" ]]; then
        echo "ERROR: Release build has no valid DEVELOPMENT_TEAM."
        echo "Set MOAIY_DEVELOPMENT_TEAM_ID in Moaiy/Config/Moaiy.Signing.xcconfig (or an included local override)."
        exit 1
      fi
    fi
    echo "Preflight passed: scheme=$SCHEME configuration=$CONFIGURATION team=$DEVELOPMENT_TEAM"
  else
    echo "WARN: xcodebuild -showBuildSettings unavailable on current host; static MAS preflight checks passed."
  fi
else
  echo "WARN: Full Xcode not active on current host; static MAS preflight checks passed."
fi
