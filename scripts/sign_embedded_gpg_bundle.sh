#!/usr/bin/env bash
#
# sign_embedded_gpg_bundle.sh
# Moaiy
#
# Signs the embedded gpg.bundle inside Moaiy.app/Contents/Resources/gpg.bundle
# and, when that bundle lives in a real Moaiy.app, installs scdaemon as a
# helper app at Contents/Helpers/MoaiyScdaemon.app.
#
# Most helpers (gpg, gpg-agent, gpgconf, gpg-connect-agent, pinentry) are
# signed with GPGHelper.entitlements: app-sandbox + inherit only. They must
# stay inherit-only. Extra entitlements make libsecinit stop treating them as
# pure inherit children and look for a CFBundleIdentifier. These CLI tools have
# none, so sandbox init SIGTRAPs (exit 5) before gpg can list keys.
#
# scdaemon is the exception. ctkpcscd checks the helper's own signature for
# com.apple.security.smartcard, which inherit does not supply. A bare
# bin/scdaemon also cannot apply a non-pure-inherit App Sandbox userland
# profile: libsecinit SIGTRAPs in SYSCALL_SET_USERLAND_PROFILE, even when
# CFBundleIdentifier is bound into a __TEXT,__info_plist section. Moaiy.app
# itself is an ad-hoc sandboxed app that can apply a profile, so scdaemon is
# packaged as a real helper .app with an on-disk Info.plist
# (CFBundleIdentifier com.moaiy.app.scdaemon). It is signed with a standalone
# sandbox: app-sandbox, smartcard, usb, and a home-relative read-write exception
# for the app-managed GNUPGHOME. It must not use inherit and must not disable
# library validation. The Mach-O __TEXT,__info_plist section is optional
# defense-in-depth; the on-disk bundle Info.plist is the required fix.
# gpg-agent scdaemon-program points at the launcher (stdio relay on first pipe-connect), not inner scdaemon.
# The leftover gpg.bundle/bin/scdaemon is only a source/copy and is signed
# inherit-only like the other CLI helpers so an accidental launch does not
# apply a bare-binary standalone profile.
#
# The helper executable still uses @executable_path/../lib/*.dylib install
# names. Those used to resolve to gpg.bundle/lib when scdaemon lived in
# gpg.bundle/bin. After the move to Contents/MacOS, the same names resolve to
# MoaiyScdaemon.app/Contents/lib, so every @executable_path/../lib dependency
# of scdaemon (and those dylibs, transitively) is copied there and signed
# before the helper .app is signed. Install names are not rewritten. Do not
# add disable-library-validation.
#
# Hardened runtime library validation treats empty ad-hoc Team IDs as
# different teams, so an ad-hoc helper signed with --options runtime cannot
# load its own ad-hoc dylibs (dyld: "mapping process and mapped file
# (non-platform) have different Team IDs"). When the identity is ad-hoc
# ("-"), MoaiyScdaemon.app and its copied dylibs are signed without
# --options runtime. When the identity is a real Team certificate, both the
# helper and those dylibs keep --options runtime so the shared Team ID
# satisfies library validation. The main Moaiy.app keeps hardened runtime
# on official signed builds. Do not disable library validation.
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
SCDAEMON_LAUNCHER_SOURCE="${SCDAEMON_LAUNCHER_SOURCE:-$PROJECT_ROOT/Moaiy/Resources/scdaemon_launcher.c}"
SCDAEMON_LAUNCHER_NAME="MoaiyScdaemon"
MAIN_APP_ENTITLEMENTS="${MAIN_APP_ENTITLEMENTS:-$PROJECT_ROOT/Moaiy/Resources/Entitlements.entitlements}"
SCDAEMON_HELPER_APP_NAME="MoaiyScdaemon.app"

SIGN_ONE_EXECUTABLE=""
if [[ "${1:-}" == "--executable" ]]; then
  SIGN_ONE_EXECUTABLE="${2:-}"
  if [[ -z "$SIGN_ONE_EXECUTABLE" || ! -f "$SIGN_ONE_EXECUTABLE" ]]; then
    echo "Usage: $0 --executable <path-to-bundled-gpg-executable>"
    exit 1
  fi
fi

is_scdaemon_helper_executable() {
  local exe="$1"
  [[ "$(basename "$exe")" == "scdaemon" ]] || return 1
  local macos_dir exe_parent helper_app
  macos_dir="$(cd "$(dirname "$exe")" && pwd)"
  [[ "$(basename "$macos_dir")" == "MacOS" ]] || return 1
  exe_parent="$(cd "$macos_dir/.." && pwd)"
  [[ "$(basename "$exe_parent")" == "Contents" ]] || return 1
  helper_app="$(cd "$exe_parent/.." && pwd)"
  [[ "$(basename "$helper_app")" == "$SCDAEMON_HELPER_APP_NAME" ]]
}

is_adhoc_sign_identity() {
  local identity="${1:-${SIGN_IDENTITY:-}}"
  [[ -z "$identity" || "$identity" == "-" ]]
}

# Sign MoaiyScdaemon.app, its executable, or a copied helper dylib.
# Ad-hoc identities omit --options runtime; Team identities keep it.
sign_scdaemon_helper_codesign() {
  local target="$1"
  shift
  if is_adhoc_sign_identity; then
    codesign --force --timestamp=none "$@" -s "$SIGN_IDENTITY" "$target"
  else
    codesign --force --timestamp=none --options runtime "$@" -s "$SIGN_IDENTITY" "$target"
  fi
}

sign_inherit_only_executable() {
  local exe="$1"
  codesign --remove-signature "$exe" 2>/dev/null || true
  codesign --force --timestamp=none \
    --entitlements "$HELPER_ENTITLEMENTS" \
    -s "$SIGN_IDENTITY" \
    "$exe"
  chmod 755 "$exe"
}

sign_scdaemon_helper_executable() {
  local exe="$1"
  # Section first. codesign --remove-signature drops the signature blob only;
  # __TEXT,__info_plist stays, and the following codesign binds it. This is
  # optional defense-in-depth; the helper .app Info.plist is what applies the
  # sandbox profile.
  bind_inner_scdaemon_info_plist "$exe"
  codesign --remove-signature "$exe" 2>/dev/null || true
  sign_scdaemon_helper_codesign "$exe" \
    --identifier "com.moaiy.app.scdaemon" \
    --entitlements "$SCDAEMON_ENTITLEMENTS"
  chmod 755 "$exe"
}

sign_scdaemon_launcher_executable() {
  local exe="$1"
  # The launcher must not carry App Sandbox. Launch Services starts it, then
  # it execs scdaemon, which applies the standalone profile once. If the
  # launcher is already sandboxed, exec of a sandboxed scdaemon SIGTRAPs in
  # libsecinit (exit 5) when it tries to apply a second profile. After exec,
  # ctkpcscd inspects scdaemon's own signature, which still has smartcard.
  codesign --remove-signature "$exe" 2>/dev/null || true
  sign_scdaemon_helper_codesign "$exe" \
    --identifier "com.moaiy.app.scdaemon"
  chmod 755 "$exe"
}

sign_one_executable() {
  local exe="$1"
  if is_scdaemon_helper_executable "$exe"; then
    sign_scdaemon_helper_executable "$exe"
  else
    # Bare gpg.bundle/bin/scdaemon stays inherit-only. The helper .app is the
    # process that must carry the standalone sandbox and device entitlements.
    sign_inherit_only_executable "$exe"
  fi
}

# Copy every @executable_path/../lib dependency of scdaemon, and those of the
# copied dylibs, into MoaiyScdaemon.app/Contents/lib. Keep existing install
# names. Fail packaging if any required library is missing.
install_and_sign_helper_libraries() {
  local helper_app="$1"
  local bundle_path="$2"
  local exe="$helper_app/Contents/MacOS/scdaemon"
  local bundle_lib="$bundle_path/lib"
  local dest_lib="$helper_app/Contents/lib"
  if [[ ! -f "$exe" ]]; then
    echo "ERROR: helper scdaemon executable not found at $exe"
    exit 1
  fi
  if [[ ! -d "$bundle_lib" ]]; then
    echo "ERROR: gpg.bundle lib directory not found at $bundle_lib"
    exit 1
  fi

  local work queue needed
  work="$(mktemp -d)"
  queue="$work/queue"
  needed="$work/needed"
  : > "$needed"
  printf '%s\n' "$exe" > "$queue"

  local index=1 current dep name src total
  while true; do
    total="$(wc -l < "$queue" | tr -d ' ')"
    if [[ "$index" -gt "$total" ]]; then
      break
    fi
    current="$(sed -n "${index}p" "$queue")"
    index=$((index + 1))
    [[ -n "$current" && -f "$current" ]] || continue
    while IFS= read -r dep; do
      [[ -n "$dep" ]] || continue
      name="$(basename "$dep")"
      if grep -qx "$name" "$needed"; then
        continue
      fi
      printf '%s\n' "$name" >> "$needed"
      src="$bundle_lib/$name"
      if [[ ! -f "$src" ]]; then
        rm -rf "$work"
        echo "ERROR: MoaiyScdaemon.app is missing required library $name (referenced as $dep)"
        exit 1
      fi
      printf '%s\n' "$src" >> "$queue"
    done < <(otool -L "$current" | awk '/@executable_path\/\.\.\/lib\// { print $1 }')
  done

  if [[ ! -s "$needed" ]]; then
    rm -rf "$work"
    echo "ERROR: scdaemon has no @executable_path/../lib dependencies; refusing to package an incomplete helper"
    exit 1
  fi

  mkdir -p "$dest_lib"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    cp "$bundle_lib/$name" "$dest_lib/$name"
    chmod 755 "$dest_lib/$name"
    codesign --remove-signature "$dest_lib/$name" 2>/dev/null || true
    sign_scdaemon_helper_codesign "$dest_lib/$name"
  done < "$needed"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if [[ ! -f "$dest_lib/$name" ]]; then
      rm -rf "$work"
      echo "ERROR: helper Contents/lib is missing $name after copy"
      exit 1
    fi
  done < "$needed"

  if otool -L "$exe" | grep -E 'gpg\.bundle/lib|/Contents/Resources/gpg\.bundle' >/dev/null; then
    rm -rf "$work"
    echo "ERROR: scdaemon install names were rewritten away from @executable_path/../lib"
    exit 1
  fi
  if ! otool -L "$exe" | grep -q '@executable_path/../lib/'; then
    rm -rf "$work"
    echo "ERROR: scdaemon no longer uses @executable_path/../lib install names"
    exit 1
  fi

  echo "Installed helper libraries into $dest_lib: $(tr '\n' ' ' < "$needed")"
  rm -rf "$work"
}

parent_app_path_from_gpg_bundle() {
  local bundle_path="$1"
  local resources_dir contents_dir app_path
  resources_dir="$(cd "$(dirname "$bundle_path")" && pwd)"
  [[ "$(basename "$resources_dir")" == "Resources" ]] || return 1
  contents_dir="$(cd "$resources_dir/.." && pwd)"
  [[ "$(basename "$contents_dir")" == "Contents" ]] || return 1
  app_path="$(cd "$contents_dir/.." && pwd)"
  [[ "$(basename "$app_path")" == *.app ]] || return 1
  printf '%s\n' "$app_path"
}

compile_scdaemon_launcher() {
  local dest="$1"
  if [[ ! -f "$SCDAEMON_LAUNCHER_SOURCE" ]]; then
    echo "ERROR: scdaemon launcher source not found at $SCDAEMON_LAUNCHER_SOURCE"
    exit 1
  fi
  cc -O2 -arch arm64 -mmacosx-version-min=14.0 \
    -o "$dest" "$SCDAEMON_LAUNCHER_SOURCE"
  chmod 755 "$dest"
}

# The app Info.plist names CFBundleExecutable MoaiyScdaemon. The inner
# scdaemon binary still binds a matching identifier, but its own executable
# name stays scdaemon.
bind_inner_scdaemon_info_plist() {
  local exe="$1"
  local tmp
  tmp="$(mktemp -t moaiy-scdaemon-info).plist"
  cat > "$tmp" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>scdaemon</string>
	<key>CFBundleIdentifier</key>
	<string>com.moaiy.app.scdaemon</string>
	<key>CFBundleName</key>
	<string>scdaemon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>LSBackgroundOnly</key>
	<true/>
</dict>
</plist>
PLIST
  python3 "$PROJECT_ROOT/scripts/embed_macho_info_plist.py" "$exe" "$tmp"
  rm -f "$tmp"
}

install_scdaemon_helper_app() {
  local bundle_path="$1"
  local app_path contents_dir helper_app src exe
  app_path="$(parent_app_path_from_gpg_bundle "$bundle_path")" || {
    echo "Skipping MoaiyScdaemon.app: $bundle_path is not inside an .app bundle."
    return 0
  }
  src="$bundle_path/bin/scdaemon"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: scdaemon source binary not found at $src"
    exit 1
  fi
  contents_dir="$app_path/Contents"
  helper_app="$contents_dir/Helpers/$SCDAEMON_HELPER_APP_NAME"
  rm -rf "$helper_app"
  mkdir -p "$helper_app/Contents/MacOS"
  cp "$SCDAEMON_INFO_PLIST" "$helper_app/Contents/Info.plist"
  cp "$src" "$helper_app/Contents/MacOS/scdaemon"
  chmod 755 "$helper_app/Contents/MacOS/scdaemon"
  exe="$helper_app/Contents/MacOS/scdaemon"
  compile_scdaemon_launcher "$helper_app/Contents/MacOS/$SCDAEMON_LAUNCHER_NAME"
  install_and_sign_helper_libraries "$helper_app" "$bundle_path"
  sign_scdaemon_helper_executable "$exe"
  sign_scdaemon_launcher_executable "$helper_app/Contents/MacOS/$SCDAEMON_LAUNCHER_NAME"
  # Sign the bundle without sandbox entitlements so the main executable
  # (the launcher) stays unsandboxed. Nested scdaemon keeps its own
  # standalone-sandbox signature.
  sign_scdaemon_helper_codesign "$helper_app" \
    --identifier "com.moaiy.app.scdaemon"
  if is_adhoc_sign_identity; then
    echo "Signed MoaiyScdaemon.app and its libraries without hardened runtime (ad-hoc identity)."
  else
    echo "Signed MoaiyScdaemon.app and its libraries with hardened runtime (team identity)."
  fi
  local sealed sealed_files
  sealed="$(codesign -d --verbose=2 "$helper_app" 2>&1 || true)"
  sealed_files="$(
    printf '%s\n' "$sealed" \
      | sed -n 's/.*[[:space:]]files=\([0-9][0-9]*\).*/\1/p' \
      | head -n 1
  )"
  if [[ -z "$sealed_files" ]]; then
    echo "ERROR: MoaiyScdaemon.app is missing Sealed Resources after signing"
    printf '%s\n' "$sealed"
    exit 1
  fi
  if [[ "$sealed_files" -lt 8 ]]; then
    echo "ERROR: MoaiyScdaemon.app Sealed Resources must include the inner scdaemon and 7 libraries (files=$sealed_files)"
    printf '%s\n' "$sealed"
    exit 1
  fi
  echo "Installed helper $helper_app"
}

reseal_parent_app_if_needed() {
  local bundle_path="$1"
  local app_path
  # Inside Xcode the parent is signed after this script. Resealing here would
  # be overwritten, and Xcode may also rewrite nested signatures. package_dmg
  # and other post-build callers re-run this script without Xcode variables so
  # the helper entitlements stay in place and the parent seal is valid.
  if [[ -n "${XCODE_VERSION_ACTUAL:-}" ]]; then
    return 0
  fi
  app_path="$(parent_app_path_from_gpg_bundle "$bundle_path")" || return 0
  if [[ ! -f "$MAIN_APP_ENTITLEMENTS" ]]; then
    echo "ERROR: main app entitlements missing at $MAIN_APP_ENTITLEMENTS"
    exit 1
  fi
  # Do not use --deep: that would re-sign the helper with the parent
  # entitlements and drop the GNUPGHOME temporary exception.
  codesign --force --timestamp=none --options runtime \
    --entitlements "$MAIN_APP_ENTITLEMENTS" \
    -s "$SIGN_IDENTITY" \
    "$app_path"
  echo "Resealed parent app without --deep: $app_path"
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

# 2. Inherit-only helpers, including the leftover source copy of scdaemon.
for exe in "$EMBEDDED_BUNDLE_PATH/bin"/*; do
  if [[ -f "$exe" ]]; then
    sign_one_executable "$exe"
  fi
done

# 3. Package scdaemon as a real helper .app when we are inside Moaiy.app.
install_scdaemon_helper_app "$EMBEDDED_BUNDLE_PATH"
reseal_parent_app_if_needed "$EMBEDDED_BUNDLE_PATH"

echo "Embedded gpg.bundle signed. Helpers use inherit-only entitlements; scdaemon runs from Helpers/MoaiyScdaemon.app with a standalone sandbox, smartcard, USB, GNUPGHOME access, an on-disk Info.plist, and its @executable_path/../lib dylibs in Contents/lib."
