#!/bin/bash

#
# prepare_gpg_bundle.sh
# Moaiy
#
# Prepares a complete GPG bundle for embedding in the app
# Creates gpg.bundle with all dependencies
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
BUNDLE_NAME="gpg.bundle"
BUNDLE_PATH="$PROJECT_ROOT/Moaiy/Resources/$BUNDLE_NAME"
TEMP_BUNDLE="/tmp/$BUNDLE_NAME"

# GPG configuration
GPG_VERSION=""
HOMEBREW_PREFIX=$(brew --prefix)

# Helper functions
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    section "Checking Prerequisites"
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        error "Homebrew not found. Please install Homebrew first."
    fi
    success "Homebrew found at $(command -v brew)"
    
    # Check for GPG
    if ! command -v gpg &> /dev/null; then
        error "GPG not found. Install with: brew install gnupg"
    fi
    
    GPG_VERSION=$(gpg --version | head -n 1)
    success "GPG found: $GPG_VERSION"
    
    # Check for required tools
    local tools=("install_name_tool" "codesign" "otool")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool not found: $tool"
        fi
        success "Found: $tool"
    done
}

# Create bundle structure
create_bundle_structure() {
    section "Creating Bundle Structure"
    
    info "Removing old bundle if exists..."
    rm -rf "$TEMP_BUNDLE"
    
    info "Creating bundle directories..."
    mkdir -p "$TEMP_BUNDLE/bin"
    mkdir -p "$TEMP_BUNDLE/lib"
    mkdir -p "$TEMP_BUNDLE/share/gnupg"
    
    success "Bundle structure created at $TEMP_BUNDLE"
}

# Copy GPG executables
copy_gpg_executables() {
    section "Copying GPG Executables"
    
    local executables=(
        "gpg"
        "gpg-agent"
        "gpgconf"
        "gpg-connect-agent"
        "gpgtar"
        "gpg-wks-server"
    )
    
    local gpg_bin="$HOMEBREW_PREFIX/bin"
    local copied_count=0
    
    for exe in "${executables[@]}"; do
        if [ -f "$gpg_bin/$exe" ]; then
            cp "$gpg_bin/$exe" "$TEMP_BUNDLE/bin/"
            chmod +x "$TEMP_BUNDLE/bin/$exe"
            success "Copied: $exe"
            ((copied_count++))
        else
            warning "Not found (optional): $exe"
        fi
    done
    
    if [ $copied_count -eq 0 ]; then
        error "No GPG executables found!"
    fi
    
    info "Copied $copied_count executables"
}

# Copy required libraries
copy_libraries() {
    section "Copying Required Libraries"
    
    local lib_count=0
    
    # Get GPG dependencies using otool
    info "Analyzing GPG dependencies..."
    local gpg_path="$TEMP_BUNDLE/bin/gpg"
    local deps=$(otool -L "$gpg_path" 2>/dev/null | grep "homebrew\|local" | awk '{print $1}')
    
    # Copy each dependency
    for dep in $deps; do
        # Get library name
        local lib_name=$(basename "$dep")
        
        # Find actual library path (resolve symlinks)
        local actual_path=""
        if [ -f "$dep" ]; then
            actual_path=$(realpath "$dep")
        else
            # Try to find in Homebrew
            local search_name=$(echo "$lib_name" | sed 's/\.[0-9]*\.dylib$/.dylib/')
            actual_path=$(find "$HOMEBREW_PREFIX/lib" -name "$lib_name" -o -name "$search_name" 2>/dev/null | head -1)
        fi
        
        if [ -n "$actual_path" ] && [ -f "$actual_path" ]; then
            cp "$actual_path" "$TEMP_BUNDLE/lib/$lib_name"
            success "Copied: $lib_name"
            ((lib_count++))
        else
            warning "Library not found: $lib_name (from $dep)"
        fi
    done
    
    # Copy additional commonly required libraries
    local common_libs=(
        "libgcrypt"
        "libgpg-error"
        "libassuan"
        "libnpth"
        "libintl"
        "libreadline"
        "libncurses"
        "libksba"
    )
    
    for lib_prefix in "${common_libs[@]}"; do
        local found=0
        
        # Find library with version number
        for lib_path in "$HOMEBREW_PREFIX/lib/$lib_prefix"*.dylib; do
            if [ -f "$lib_path" ]; then
                local target_name=$(basename "$lib_path")
                
                # Check if already copied
                if [ ! -f "$TEMP_BUNDLE/lib/$target_name" ]; then
                    cp "$lib_path" "$TEMP_BUNDLE/lib/$target_name"
                    success "Copied: $target_name"
                    ((lib_count++))
                fi
                found=1
                break
            fi
        done
        
        if [ $found -eq 0 ]; then
            warning "Optional library not found: $lib_prefix"
        fi
    done
    
    info "Total libraries copied: $lib_count"
    
    if [ $lib_count -eq 0 ]; then
        error "No libraries found! Cannot proceed."
    fi
}

# Fix library dependencies
fix_library_paths() {
    section "Fixing Library Dependencies"
    
    info "This may take a while..."
    echo ""
    
    # Fix GPG executables
    for exe in "$TEMP_BUNDLE/bin"/*; do
        if [ -f "$exe" ]; then
            local exe_name=$(basename "$exe")
            info "Fixing $exe_name..."
            
            # Get dependencies
            local deps=$(otool -L "$exe" 2>/dev/null | grep "homebrew\|/usr/local\|/opt" | awk '{print $1}')
            
            for dep in $deps; do
                local lib_name=$(basename "$dep")
                local new_path="@executable_path/../lib/$lib_name"
                
                if [ -f "$TEMP_BUNDLE/lib/$lib_name" ]; then
                    install_name_tool -change "$dep" "$new_path" "$exe"
                    info "  Changed: $lib_name"
                fi
            done
        fi
    done
    
    echo ""
    
    # Fix libraries
    for lib in "$TEMP_BUNDLE/lib"/*.dylib; do
        if [ -f "$lib" ]; then
            local lib_name=$(basename "$lib")
            info "Fixing $lib_name..."
            
            # Set library ID
            install_name_tool -id "@executable_path/../lib/$lib_name" "$lib"
            
            # Fix dependencies
            local deps=$(otool -L "$lib" 2>/dev/null | grep "homebrew\|/usr/local\|/opt" | awk '{print $1}')
            
            for dep in $deps; do
                local dep_name=$(basename "$dep")
                local new_path="@executable_path/../lib/$dep_name"
                
                # Don't reference self
                if [ "$dep_name" != "$lib_name" ]; then
                    if [ -f "$TEMP_BUNDLE/lib/$dep_name" ]; then
                        install_name_tool -change "$dep" "$new_path" "$lib"
                        info "  Changed dependency: $dep_name"
                    else
                        # Keep system libraries
                        if [[ "$dep" != /usr/lib/* ]] && [[ "$dep" != /System/* ]]; then
                            warning "  Missing dependency in $lib_name: $dep_name"
                        fi
                    fi
                fi
            done
            
            success "Fixed: $lib_name"
        fi
    done
}

# Sign all binaries
sign_binaries() {
    section "Signing All Binaries"
    
    local sign_count=0
    
    # Sign libraries first
    for lib in "$TEMP_BUNDLE/lib"/*.dylib; do
        if [ -f "$lib" ]; then
            local lib_name=$(basename "$lib")
            
            # Remove existing signature
            codesign --remove-signature "$lib" 2>/dev/null || true
            
            # Sign with ad-hoc signature
            if codesign -s - "$lib" 2>/dev/null; then
                success "Signed: $lib_name"
                ((sign_count++))
            else
                warning "Failed to sign: $lib_name"
            fi
        fi
    done
    
    # Sign executables
    for exe in "$TEMP_BUNDLE/bin"/*; do
        if [ -f "$exe" ]; then
            local exe_name=$(basename "$exe")
            
            # Remove existing signature
            codesign --remove-signature "$exe" 2>/dev/null || true
            
            # Sign with ad-hoc signature
            if codesign -s - "$exe" 2>/dev/null; then
                success "Signed: $exe_name"
                ((sign_count++))
            else
                warning "Failed to sign: $exe_name"
            fi
        fi
    done
    
    info "Total binaries signed: $sign_count"
}

# Test the bundle
test_bundle() {
    section "Testing Bundle"
    
    local gpg_exe="$TEMP_BUNDLE/bin/gpg"
    
    if [ ! -f "$gpg_exe" ]; then
        error "GPG executable not found in bundle!"
    fi
    
    # Test execution
    info "Testing GPG execution..."
    if "$gpg_exe" --version &> /dev/null; then
        local version=$("$gpg_exe" --version 2>&1 | head -n 1)
        success "GPG executes successfully: $version"
    else
        error "GPG failed to execute!"
    fi
    
    # Test with custom GNUPGHOME
    info "Testing with custom GNUPGHOME..."
    local temp_home=$(mktemp -d)
    chmod 700 "$temp_home"
    
    if GNUPGHOME="$temp_home" "$gpg_exe" --list-keys &> /dev/null; then
        success "GPG works with custom GNUPGHOME"
    else
        warning "GPG may have issues with custom GNUPGHOME"
    fi
    
    rm -rf "$temp_home"
    
    # Test help
    info "Testing help command..."
    if "$gpg_exe" --help &> /dev/null; then
        success "GPG help command works"
    else
        warning "GPG help command failed"
    fi
}

# Generate manifest
generate_manifest() {
    section "Generating Manifest"
    
    local manifest_file="$TEMP_BUNDLE/manifest.json"
    
    # Get GPG version
    local gpg_version=$("$TEMP_BUNDLE/bin/gpg" --version 2>&1 | head -n 1 | awk '{print $3}')
    
    # Calculate checksums
    info "Calculating checksums..."
    
    local checksums=""
    
    # Add executables
    for exe in "$TEMP_BUNDLE/bin"/*; do
        if [ -f "$exe" ]; then
            local name=$(basename "$exe")
            local sha256=$(shasum -a 256 "$exe" | awk '{print $1}')
            checksums+="    \"$name\": \"$sha256\",\n"
        fi
    done
    
    # Add libraries
    for lib in "$TEMP_BUNDLE/lib"/*.dylib; do
        if [ -f "$lib" ]; then
            local name=$(basename "$lib")
            local sha256=$(shasum -a 256 "$lib" | awk '{print $1}')
            checksums+="    \"$name\": \"$sha256\",\n"
        fi
    done
    
    # Remove trailing comma
    checksums=$(echo "$checksums" | sed '$ s/,$//')
    
    # Create manifest
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
    
    success "Manifest generated: $manifest_file"
    info "GPG Version: $gpg_version"
}

# Install bundle to project
install_bundle() {
    section "Installing Bundle"
    
    info "Removing old bundle..."
    rm -rf "$BUNDLE_PATH"
    
    info "Copying bundle to project..."
    mkdir -p "$(dirname "$BUNDLE_PATH")"
    cp -R "$TEMP_BUNDLE" "$BUNDLE_PATH"
    
    # Get bundle size
    local size=$(du -sh "$BUNDLE_PATH" | awk '{print $1}')
    
    success "Bundle installed to: $BUNDLE_PATH"
    info "Bundle size: $size"
    
    # List contents
    info "Bundle contents:"
    echo "  bin/            ($(ls -1 "$BUNDLE_PATH/bin" | wc -l | tr -d ' ') files)"
    echo "  lib/            ($(ls -1 "$BUNDLE_PATH/lib" | wc -l | tr -d ' ') files)"
    echo "  manifest.json   (1 file)"
}

# Verify final bundle
verify_bundle() {
    section "Verifying Final Bundle"
    
    if [ -f "$PROJECT_ROOT/scripts/verify_gpg_bundle.sh" ]; then
        info "Running verification script..."
        "$PROJECT_ROOT/scripts/verify_gpg_bundle.sh"
    else
        warning "Verification script not found, skipping"
    fi
}

# Print summary
print_summary() {
    section "Summary"
    
    echo -e "${GREEN}"
    echo "✅ GPG Bundle Created Successfully!"
    echo -e "${NC}"
    echo ""
    echo "Bundle Location: $BUNDLE_PATH"
    echo "GPG Version: $GPG_VERSION"
    echo "Platform: $(uname -m)"
    echo ""
    
    local size=$(du -sh "$BUNDLE_PATH" | awk '{print $1}')
    echo "Bundle Size: $size"
    
    local exe_count=$(ls -1 "$BUNDLE_PATH/bin" | wc -l | tr -d ' ')
    local lib_count=$(ls -1 "$BUNDLE_PATH/lib" | wc -l | tr -d ' ')
    
    echo "Executables: $exe_count"
    echo "Libraries: $lib_count"
    echo ""
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Verify bundle: ./scripts/verify_gpg_bundle.sh"
    echo "2. Add to Xcode project:"
    echo "   - Add gpg.bundle to Moaiy.xcodeproj"
    echo "   - Configure Copy Bundle Resources"
    echo "3. Test in app: Build and run Moaiy"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         Moaiy - GPG Bundle Preparation Script                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    info "Project root: $PROJECT_ROOT"
    info "Bundle path: $BUNDLE_PATH"
    info "Homebrew prefix: $HOMEBREW_PREFIX"
    
    # Run all steps
    check_prerequisites
    create_bundle_structure
    copy_gpg_executables
    copy_libraries
    fix_library_paths
    sign_binaries
    test_bundle
    generate_manifest
    install_bundle
    verify_bundle
    print_summary
}

# Run main function
main "$@"
