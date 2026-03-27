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
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARN_COUNT++))
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

# Check executables
check_executables() {
    section "Checking Executables"
    
    local executables=("gpg" "gpg-agent" "gpgconf")
    
    for exe in "${executables[@]}"; do
        if [ -f "$BUNDLE_PATH/bin/$exe" ]; then
            if [ -x "$BUNDLE_PATH/bin/$exe" ]; then
                pass "Executable found and has execute permission: $exe"
            else
                fail "Executable found but no execute permission: $exe"
            fi
        else
            warn "Executable not found: $exe (optional)"
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
    )
    
    local optional_libs=(
        "libncurses.6.dylib"
        "libreadline.8.dylib"
    )
    
    # Check required libraries
    for lib in "${required_libs[@]}"; do
        if [ -f "$BUNDLE_PATH/lib/$lib" ]; then
            pass "Required library found: $lib"
        else
            fail "Required library missing: $lib"
        fi
    done
    
    # Check optional libraries
    for lib in "${optional_libs[@]}"; do
        if [ -f "$BUNDLE_PATH/lib/$lib" ]; then
            pass "Optional library found: $lib"
        else
            warn "Optional library missing: $lib (may not be needed)"
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
                warn "Not signed: $exe_name"
            fi
        fi
    done
    
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
                warn "Not signed: $lib_name"
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

# Generate manifest
generate_manifest() {
    section "Generating Manifest"
    
    local manifest_file="$BUNDLE_PATH/manifest.json"
    
    if [ ! -d "$BUNDLE_PATH" ]; then
        fail "Bundle not found, cannot generate manifest"
        return
    fi
    
    info "Generating manifest file..."
    
    # Get GPG version
    local gpg_version="unknown"
    if [ -f "$BUNDLE_PATH/bin/gpg" ]; then
        gpg_version=$("$BUNDLE_PATH/bin/gpg" --version 2>&1 | head -n 1 | awk '{print $3}')
    fi
    
    # Calculate checksums
    local -a checksum_entries=()
    
    # Add executables
    for exe in "$BUNDLE_PATH/bin"/*; do
        if [ -f "$exe" ]; then
            local name=$(basename "$exe")
            local sha256=$(shasum -a 256 "$exe" | awk '{print $1}')
            checksum_entries+=("    \"$name\": \"$sha256\"")
        fi
    done
    
    # Add libraries
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
    
    # Create manifest
    cat > "$manifest_file" << EOF
{
  "version": "1.0",
  "gpg_version": "$gpg_version",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "$(uname -m)",
  "checksums": {
$checksums
  }
}
EOF
    
    pass "Manifest generated: $manifest_file"
    info "GPG Version: $gpg_version"
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
    test_gpg_execution
    check_bundle_size
    generate_manifest
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
