#!/bin/bash

# Download and bundle GPG for Moaiy
# This script downloads GPG from Homebrew and bundles it with the app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🗿 Moaiy GPG Bundler"
echo "===================="
echo ""

# Configuration
GPG_VERSION="2.5.18"
BREW_GPG_PATH="/opt/homebrew/opt/gnupg"
OUTPUT_DIR="$SCRIPT_DIR/../Moaiy/Resources/gpg.bundle"

# Check if GPG is installed via Homebrew
if [ ! -d "$BREW_GPG_PATH" ]; then
    echo "❌ GPG not found in Homebrew"
    echo "Please install: brew install gnupg"
    exit 1
fi

echo "✅ Found GPG in Homebrew: $BREW_GPG_PATH"
echo "   Version: $(gpg --version | head -1)"
echo ""

# Create bundle directory
echo "📁 Creating bundle directory..."
mkdir -p "$OUTPUT_DIR/bin"
mkdir -p "$OUTPUT_DIR/lib"
mkdir -p "$OUTPUT_DIR/share"

# Copy GPG binary
echo "📦 Copying GPG binary..."
cp "$BREW_GPG_PATH/bin/gpg" "$OUTPUT_DIR/bin/"
cp "$BREW_GPG_PATH/bin/gpg-agent" "$OUTPUT_DIR/bin/" 2>/dev/null || true
cp "$BREW_GPG_PATH/bin/gpgconf" "$OUTPUT_DIR/bin/" 2>/dev/null || true

# Copy required libraries
echo "📚 Copying libraries..."
LIBS=(
    "libintl.8.dylib"
    "libgcrypt.20.dylib"
    "libgpg-error.0.dylib"
    "libreadline.8.dylib"
    "libassuan.9.dylib"
    "libnpth.0.dylib"
    "libncursesw.6.dylib"
)

for lib in "${LIBS[@]}"; do
    lib_path=$(find /opt/homebrew -name "$lib" 2>/dev/null | head -1)
    if [ -n "$lib_path" ]; then
        cp "$lib_path" "$OUTPUT_DIR/lib/"
        echo "   ✅ $lib"
    fi
done

# Fix library paths
echo "🔧 Fixing library paths..."
cd "$OUTPUT_DIR"
"$SCRIPT_DIR/fix_gpg_deps.sh" 2>/dev/null || echo "   ℹ️  Run scripts/fix_gpg_deps.sh manually if needed"

# Create checksum
echo "📝 Creating checksum..."
cd "$OUTPUT_DIR"
find . -type f -exec shasum -a 256 {} \; > SHA256SUMS

# Calculate size
SIZE=$(du -sh "$OUTPUT_DIR" | awk '{print $1}')
echo ""
echo "✅ GPG bundle created successfully!"
echo "   Location: $OUTPUT_DIR"
echo "   Size: $SIZE"
echo ""
echo "💡 Next steps:"
echo "   1. Add gpg.bundle to Xcode project"
echo "   2. Configure Build Phase to copy bundle to Resources"
echo "   3. Test in sandboxed environment"
