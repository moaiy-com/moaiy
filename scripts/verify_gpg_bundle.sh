#!/bin/bash

#
# verify_gpg_bundle.sh
# Moaiy
#
# Verifies the integrity and functionality of the bundled GPG
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Bundle path (relative to script location)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
BUNDLE_PATH="$PROJECT_ROOT/Moaiy/Resources/gpg.bundle"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASS_COUNT+=1))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAIL_COUNT+=1))
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARN_COUNT+=1))
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check if bundle exists
check_bundle_exists() {
    section "Checking Bundle Structure"
    
    if [ -d "$BUNDLE_PATH" ]; then
        pass "Bundle directory exists: $BUNDLE_PATH"
    else
        fail "Bundle directory not found: $BUNDLE_PATH"
        exit 1
    fi
    
    if [ -d "$BUNDLE_PATH/bin" ]; then
        pass "bin/ directory exists"
    else
        fail "bin/ directory not found"
    fi
    
    if [ -d "$BUNDLE_PATH/lib" ]; then
        pass "lib/ directory exists"
    else
        fail "lib/ directory not found"
    fi
}

# Source-tree gpg.bundle/bin/scdaemon is only the source binary. A real helper
# .app with an on-disk Info.plist is installed when the bundle is signed inside
# Moaiy.app. This source-tree check confirms the template and sign script; it
# does not require a bound Info.plist on the bare Mach-O (that approach
# SIGTRAPs in libsecinit).
check_scdaemon_helper_packaging() {
    section "Checking scdaemon helper packaging"
    local scdaemon="$BUNDLE_PATH/bin/scdaemon"
    if [ -x "$scdaemon" ]; then
        pass "Source scdaemon binary exists in gpg.bundle/bin"
    else
        fail "Source scdaemon binary missing at $scdaemon"
    fi

    local sign_script="$PROJECT_ROOT/scripts/sign_embedded_gpg_bundle.sh"
    if grep -q "MoaiyScdaemon.app" "$sign_script" \
        && grep -q "install_scdaemon_helper_app" "$sign_script" \
        && grep -q "Contents/Helpers" "$sign_script"; then
        pass "sign_embedded_gpg_bundle.sh installs Helpers/MoaiyScdaemon.app"
    else
        fail "sign_embedded_gpg_bundle.sh does not install MoaiyScdaemon.app"
    fi
    if grep -q "install_and_sign_helper_libraries" "$sign_script" \
        && grep -q 'helper_app/Contents/lib' "$sign_script" \
        && grep -q '@executable_path/../lib' "$sign_script"; then
        pass "sign_embedded_gpg_bundle.sh copies scdaemon @executable_path/../lib dylibs into the helper"
    else
        fail "sign_embedded_gpg_bundle.sh must copy scdaemon libraries into MoaiyScdaemon.app/Contents/lib"
    fi
    if grep -q "is_adhoc_sign_identity" "$sign_script" \
        && grep -q "sign_scdaemon_helper_codesign" "$sign_script" \
        && grep -q -- "--options runtime" "$sign_script"; then
        pass "Helper signing omits hardened runtime for ad-hoc identities and keeps it for Team identities"
    else
        fail "sign_embedded_gpg_bundle.sh must sign the helper without hardened runtime when the identity is ad-hoc"
    fi
    local launcher_src="$PROJECT_ROOT/Moaiy/Resources/scdaemon_launcher.c"
    local info_plist="$PROJECT_ROOT/Moaiy/Resources/ScdaemonInfo.plist"
    if grep -q "compile_scdaemon_launcher" "$sign_script"         && grep -q "sign_scdaemon_launcher_executable" "$sign_script"         && grep -q "getpwuid" "$launcher_src"         && grep -q "multi-server" "$launcher_src"         && grep -Fq -- "--daemon" "$launcher_src"         && ! grep -q "NSHomeDirectory" "$launcher_src"         && grep -q "com.moaiy.app.scdaemon/Data/Library/gnupg" "$launcher_src"         && grep -q "proxies the Assuan socket" "$launcher_src"         && grep -q "run_agent_stdio_relay" "$launcher_src"         && grep -q "GETINFO socket_name" "$launcher_src"         && grep -q "bundledScdaemonAgentProgram" "$PROJECT_ROOT/Moaiy/Services/GPGService.swift"         && grep -q "MoaiyScdaemon" "$info_plist"; then
        pass "Helper ships a getpwuid supervisor that execs scdaemon --multi-server, publishes S.scdaemon, and relays agent stdio"
    else
        fail "scdaemon helper must include a getpwuid launcher as CFBundleExecutable"
    fi

    local required_libs=(
        "libgcrypt.20.dylib"
        "libksba.8.dylib"
        "libgpg-error.0.dylib"
        "libassuan.9.dylib"
        "libnpth.0.dylib"
        "libusb-1.0.0.dylib"
        "libintl.8.dylib"
    )
    local missing=0
    local lib
    for lib in "${required_libs[@]}"; do
        if [ -f "$BUNDLE_PATH/lib/$lib" ]; then
            pass "Source library available for helper packaging: $lib"
        else
            fail "Source library missing from gpg.bundle/lib: $lib"
            missing=1
        fi
    done
    if [ "$missing" -eq 0 ]; then
        pass "All scdaemon helper libraries are present in gpg.bundle/lib"
    fi
}

# Check executables
check_executables() {
    section "Checking Executables"
    
    local executables=("gpg" "gpg-agent" "gpgconf" "gpg-connect-agent" "scdaemon")
    
    for exe in "${executables[@]}"; do
        if [ -f "$BUNDLE_PATH/bin/$exe" ]; then
            if [ -x "$BUNDLE_PATH/bin/$exe" ]; then
                pass "Executable found and has execute permission: $exe"
            else
                fail "Executable found but no execute permission: $exe"
            fi
        else
            fail "Required executable not found: $exe"
        fi
    done

    local forbidden_executables=("gpg-wks-server" "gpgtar")
    for forbidden in "${forbidden_executables[@]}"; do
        if [ -f "$BUNDLE_PATH/bin/$forbidden" ]; then
            fail "Redundant executable should not be bundled: $forbidden"
        else
            pass "Redundant executable absent: $forbidden"
        fi
    done
}

# Check libraries
check_libraries() {
    section "Checking Libraries"
    
    local required_libs=(
        "libgcrypt.20.dylib"
        "libgpg-error.0.dylib"
        "libassuan.9.dylib"
        "libksba.8.dylib"
        "libnpth.0.dylib"
        "libreadline.8.dylib"
        "libintl.8.dylib"
        "libusb-1.0.0.dylib"
    )
    
    # Check required libraries
    for lib in "${required_libs[@]}"; do
        if [ -f "$BUNDLE_PATH/lib/$lib" ]; then
            pass "Required library found: $lib"
        else
            fail "Required library missing: $lib"
        fi
    done
}

# Check library paths
check_library_paths() {
    section "Checking Library Paths"
    
    local libs=("$BUNDLE_PATH/lib"/*.dylib)
    
    for lib in "${libs[@]}"; do
        local lib_name=$(basename "$lib")
        info "Checking paths for: $lib_name"
        
        # Get library dependencies
        local deps=$(otool -L "$lib" 2>/dev/null | grep -E "^\t" | grep -v "System\|usr/lib")
        
        while IFS= read -r dep; do
            # Check if dependency uses @executable_path
            if echo "$dep" | grep -q "@executable_path"; then
                pass "  Uses @executable_path: $(echo "$dep" | awk '{print $1}')"
            elif echo "$dep" | grep -q "/opt/homebrew\|/usr/local"; then
                fail "  Uses absolute path: $(echo "$dep" | awk '{print $1}')"
                fail "  Should use @executable_path instead"
            fi
        done <<< "$deps"
    done
}

# Check code signatures
check_signatures() {
    section "Checking Code Signatures"
    
    # Check executables
    local executables=("$BUNDLE_PATH/bin"/*)
    
    for exe in "${executables[@]}"; do
        if [ -f "$exe" ]; then
            local exe_name=$(basename "$exe")
            
            # Check if signed
            if codesign -dv "$exe" 2>&1 | grep -q "Signature"; then
                pass "Signed: $exe_name"
                
                # Verify signature
                if codesign --verify --deep --strict "$exe" 2>/dev/null; then
                    pass "  Signature valid: $exe_name"
                else
                    fail "  Signature invalid: $exe_name"
                fi
            else
                fail "Not signed: $exe_name"
            fi
        fi
    done

    # Check MAS child sandbox inheritance entitlements template & signing script
    local helper_ent="$PROJECT_ROOT/Moaiy/Resources/GPGHelper.entitlements"
    if [ -f "$helper_ent" ] && plutil -lint "$helper_ent" >/dev/null 2>&1; then
        if grep -q "com.apple.security.app-sandbox" "$helper_ent" && grep -q "com.apple.security.inherit" "$helper_ent"; then
            pass "MAS child sandbox entitlements valid: GPGHelper.entitlements"
        else
            fail "GPGHelper.entitlements missing app-sandbox or inherit keys"
        fi
        if grep -q "com.apple.security.smartcard" "$helper_ent" || grep -q "com.apple.security.device.usb" "$helper_ent"; then
            fail "GPGHelper.entitlements must stay inherit-only (no smartcard or USB)"
        else
            pass "GPGHelper.entitlements is inherit-only"
        fi
        local scdaemon_ent="$PROJECT_ROOT/Moaiy/Resources/GPGScdaemon.entitlements"
        local scdaemon_plist="$PROJECT_ROOT/Moaiy/Resources/ScdaemonInfo.plist"
        if [ -f "$scdaemon_ent" ] && plutil -lint "$scdaemon_ent" >/dev/null 2>&1 \
            && grep -q "com.apple.security.app-sandbox" "$scdaemon_ent" \
            && grep -q "com.apple.security.smartcard" "$scdaemon_ent" \
            && grep -q "com.apple.security.device.usb" "$scdaemon_ent" \
            && ! grep -q "com.apple.security.inherit" "$scdaemon_ent" \
            && ! grep -q "disable-library-validation" "$scdaemon_ent" \
            && grep -q "Library/Containers/com.moaiy.app/Data/Library/gnupg/" "$scdaemon_ent"; then
            pass "scdaemon entitlements are a standalone sandbox with smartcard, USB, and the app-managed GNUPGHOME"
        else
            fail "GPGScdaemon.entitlements must be sandbox+smartcard+usb without inherit, plus GNUPGHOME access"
        fi
        if [ -f "$scdaemon_plist" ] && grep -q "com.moaiy.app.scdaemon" "$scdaemon_plist"; then
            pass "scdaemon Info.plist bundle id is com.moaiy.app.scdaemon"
        else
            fail "ScdaemonInfo.plist missing CFBundleIdentifier com.moaiy.app.scdaemon"
        fi
        local sign_script="$PROJECT_ROOT/scripts/sign_embedded_gpg_bundle.sh"
        if grep -q "GPGHelper.entitlements" "$sign_script" \
            && grep -q "GPGScdaemon.entitlements" "$sign_script" \
            && grep -q "MoaiyScdaemon.app" "$sign_script" \
            && grep -q "install_scdaemon_helper_app" "$sign_script" \
            && grep -q "install_and_sign_helper_libraries" "$sign_script" \
            && grep -q "is_adhoc_sign_identity" "$sign_script" \
            && grep -q "sign_scdaemon_helper_codesign" "$sign_script" \
            && grep -q "ScdaemonInfo.plist" "$sign_script" \
            && grep -q "sign_inherit_only_executable" "$sign_script"; then
            pass "Only MoaiyScdaemon.app is signed with device entitlements; other helpers stay inherit-only"
        else
            fail "sign_embedded_gpg_bundle.sh does not keep other helpers inherit-only or is missing helper-app packaging"
        fi
    else
        fail "GPGHelper.entitlements missing or invalid plist"
    fi

    if [ -f "$PROJECT_ROOT/scripts/moaiy-pinentry.c" ]; then
        pass "Bundled pinentry source present: scripts/moaiy-pinentry.c"
    else
        fail "Missing scripts/moaiy-pinentry.c"
    fi

    if [ -x "$PROJECT_ROOT/scripts/sign_embedded_gpg_bundle.sh" ]; then
        pass "Embedded bundle sandbox signing script ready: scripts/sign_embedded_gpg_bundle.sh"
    else
        fail "Missing or non-executable: scripts/sign_embedded_gpg_bundle.sh"
    fi
    
    # Check libraries
    local libs=("$BUNDLE_PATH/lib"/*.dylib)
    
    for lib in "${libs[@]}"; do
        if [ -f "$lib" ]; then
            local lib_name=$(basename "$lib")
            
            # Check if signed
            if codesign -dv "$lib" 2>&1 | grep -q "Signature"; then
                pass "Signed: $lib_name"
                
                # Verify signature
                if codesign --verify --deep --strict "$lib" 2>/dev/null; then
                    pass "  Signature valid: $lib_name"
                else
                    fail "  Signature invalid: $lib_name"
                fi
            else
                fail "Not signed: $lib_name"
            fi
        fi
    done
}

# Test GPG execution
test_gpg_execution() {
    section "Testing GPG Execution"
    
    local gpg_exe="$BUNDLE_PATH/bin/gpg"
    
    if [ ! -f "$gpg_exe" ]; then
        fail "GPG executable not found"
        return
    fi
    
    # Test basic execution
    info "Testing GPG version..."
    if "$gpg_exe" --version >/dev/null 2>&1; then
        pass "GPG executable runs successfully"
        
        # Get version
        local version=$("$gpg_exe" --version 2>&1 | head -n 1)
        info "GPG Version: $version"
    else
        fail "GPG executable failed to run"
        return
    fi
    
    # Test help command
    info "Testing GPG help..."
    if "$gpg_exe" --help >/dev/null 2>&1; then
        pass "GPG help command works"
    else
        warn "GPG help command failed (non-critical)"
    fi
    
    # Test with custom GNUPGHOME
    info "Testing with custom GNUPGHOME..."
    local temp_home=$(mktemp -d)
    chmod 700 "$temp_home"
    
    if GNUPGHOME="$temp_home" "$gpg_exe" --list-keys >/dev/null 2>&1; then
        pass "GPG works with custom GNUPGHOME"
    else
        warn "GPG failed with custom GNUPGHOME (may need additional setup)"
    fi
    
    rm -rf "$temp_home"
}

# Check bundle size
check_bundle_size() {
    section "Checking Bundle Size"
    
    if [ -d "$BUNDLE_PATH" ]; then
        local size=$(du -sh "$BUNDLE_PATH" | awk '{print $1}')
        local size_bytes=$(du -s "$BUNDLE_PATH" | awk '{print $1}')
        local size_mb=$((size_bytes * 512 / 1024 / 1024))
        
        info "Bundle size: $size ($size_mb MB)"
        
        if [ $size_mb -lt 20 ]; then
            pass "Bundle size is acceptable (< 20MB)"
        elif [ $size_mb -lt 30 ]; then
            warn "Bundle size is larger than optimal ($size_mb MB)"
        else
            fail "Bundle size is too large ($size_mb MB)"
        fi
    else
        fail "Bundle not found, cannot check size"
    fi
}

# Verify or update manifest
verify_or_update_manifest() {
    local update_manifest="${1:-false}"
    local manifest_file="$BUNDLE_PATH/manifest.json"

    if [ ! -d "$BUNDLE_PATH" ]; then
        fail "Bundle not found, cannot verify manifest"
        return
    fi

    if [ "$update_manifest" = "true" ] || [ ! -f "$manifest_file" ]; then
        section "Generating Manifest"
        info "Generating manifest file..."

        local gpg_version="unknown"
        if [ -f "$BUNDLE_PATH/bin/gpg" ]; then
            gpg_version=$("$BUNDLE_PATH/bin/gpg" --version 2>&1 | head -n 1 | awk '{print $3}')
        fi

        local -a checksum_entries=()
        for exe in "$BUNDLE_PATH/bin"/*; do
            if [ -f "$exe" ]; then
                local name=$(basename "$exe")
                local sha256=$(shasum -a 256 "$exe" | awk '{print $1}')
                checksum_entries+=("    \"$name\": \"$sha256\"")
            fi
        done

        for lib in "$BUNDLE_PATH/lib"/*.dylib; do
            if [ -f "$lib" ]; then
                local name=$(basename "$lib")
                local sha256=$(shasum -a 256 "$lib" | awk '{print $1}')
                checksum_entries+=("    \"$name\": \"$sha256\"")
            fi
        done

        local checksums=""
        if [ ${#checksum_entries[@]} -gt 0 ]; then
            checksums=$(printf '%s,\n' "${checksum_entries[@]}" | sed '$ s/,$//')
        fi

        cat > "$manifest_file" << EOF
{
  "version": "1.0",
  "gpg_version": "$gpg_version",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "$(uname -m)",
  "architecture": "$(uname -m)",
  "macos_min_version": "12.0",
  "checksums": {
$checksums
  }
}
EOF
        pass "Manifest generated: $manifest_file"
        info "GPG Version: $gpg_version"
        return
    fi

    section "Verifying Manifest Checksums (Read-Only)"
    if python3 - "$BUNDLE_PATH" "$manifest_file" << 'PYEOF'
import hashlib, json, pathlib, sys

bundle_path = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
recorded = manifest.get("checksums", {})

actual = {}
for folder in ("bin", "lib"):
    d = bundle_path / folder
    if d.is_dir():
        for item in sorted(d.iterdir()):
            if item.is_file():
                actual[item.name] = hashlib.sha256(item.read_bytes()).hexdigest()

missing = sorted(set(actual) - set(recorded))
extra = sorted(set(recorded) - set(actual))
mismatched = sorted(k for k in set(actual) & set(recorded) if actual[k] != recorded[k])

if missing or extra or mismatched:
    if missing:
        print(f"Missing in manifest: {missing}", file=sys.stderr)
    if extra:
        print(f"Unexpected in manifest: {extra}", file=sys.stderr)
    if mismatched:
        print(f"Checksum mismatch: {mismatched}", file=sys.stderr)
    sys.exit(1)
PYEOF
    then
        pass "Manifest checksums match all bundled binaries & libraries (read-only)"
    else
        fail "Manifest checksums out of sync with gpg.bundle (run with --update-manifest to refresh)"
    fi
}

# Print summary
print_summary() {
    section "Verification Summary"
    
    echo -e "Total Checks:"
    echo -e "  ${GREEN}✅ Passed: $PASS_COUNT${NC}"
    echo -e "  ${RED}❌ Failed: $FAIL_COUNT${NC}"
    echo -e "  ${YELLOW}⚠️  Warnings: $WARN_COUNT${NC}"
    echo ""
    
    if [ $FAIL_COUNT -eq 0 ]; then
        if [ $WARN_COUNT -eq 0 ]; then
            echo -e "${GREEN}✅ All checks passed! Bundle is ready for integration.${NC}"
            exit 0
        else
            echo -e "${YELLOW}⚠️  All critical checks passed, but there are warnings.${NC}"
            echo -e "${YELLOW}   Review warnings before proceeding.${NC}"
            exit 0
        fi
    else
        echo -e "${RED}❌ Some checks failed. Please fix issues before proceeding.${NC}"
        exit 1
    fi
}

# Main execution
main() {
    local update_manifest="false"
    for arg in "$@"; do
        case "$arg" in
            --update-manifest)
                update_manifest="true"
                ;;
        esac
    done

    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Moaiy - GPG Bundle Verification Script              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    info "Bundle path: $BUNDLE_PATH"
    info "Project root: $PROJECT_ROOT"
    
    # Run all checks
    check_bundle_exists
    check_executables
    check_libraries
    check_library_paths
    check_signatures
    check_scdaemon_helper_packaging
    test_gpg_execution
    check_bundle_size
    verify_or_update_manifest "$update_manifest"
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
