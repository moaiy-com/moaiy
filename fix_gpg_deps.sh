#!/bin/bash

# Configuration - 支持 Debug 和 Release 模式
BUILD_MODE="${1:-Debug}"  # 默认 Debug，可通过参数指定 Release
BUILD_DIR="/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/$BUILD_MODE/MoaiySandboxTest.app/Contents"
RESOURCES_DIR="$BUILD_DIR/Resources"
LIB_DIR="$RESOURCES_DIR/lib"
SOURCE_DIR="/Users/codingchef/Taugast/moaiy/MoaiySandboxTest/Resources"

echo "=== 配置模式: $BUILD_MODE ==="
echo "目标路径: $BUILD_DIR"
echo ""

echo "=== 复制 GPG 和库文件到 App Bundle ==="

# Create directories
mkdir -p "$RESOURCES_DIR"
mkdir -p "$LIB_DIR"

# Copy GPG binary
echo "Copying GPG binary..."
if [ -f "$SOURCE_DIR/bin/gpg" ]; then
    cp "$SOURCE_DIR/bin/gpg" "$RESOURCES_DIR/gpg"
    chmod +x "$RESOURCES_DIR/gpg"
    echo "  ✅ GPG binary copied"
else
    echo "  ❌ GPG binary not found at $SOURCE_DIR/bin/gpg"
    exit 1
fi

# Copy libraries from homebrew (will be copied to source dir first)
echo "Copying libraries from Homebrew..."
LIBS=(
    "/opt/homebrew/opt/gettext/lib/libintl.8.dylib"
    "/opt/homebrew/opt/libgcrypt/lib/libgcrypt.20.dylib"
    "/opt/homebrew/opt/libgpg-error/lib/libgpg-error.0.dylib"
    "/opt/homebrew/opt/readline/lib/libreadline.8.dylib"
    "/opt/homebrew/opt/libassuan/lib/libassuan.9.dylib"
    "/opt/homebrew/opt/npth/lib/libnpth.0.dylib"
)

mkdir -p "$SOURCE_DIR/lib"

for lib in "${LIBS[@]}"; do
    if [ -f "$lib" ]; then
        libname=$(basename "$lib")
        cp "$lib" "$SOURCE_DIR/lib/$libname"
        echo "  ✅ Copied $libname from Homebrew"
    fi
done

# Now copy to app bundle
cp "$SOURCE_DIR/lib"/*.dylib "$LIB_DIR/" 2>/dev/null || true
echo "  ✅ Libraries copied to app bundle"

# Copy ncurses library (libreadline dependency)
echo "Adding ncurses library..."
NCURSES_SRC="/opt/homebrew/opt/ncurses/lib/libncursesw.6.dylib"
NCURSES_DST="$LIB_DIR/libncurses.5.4.dylib"

cp "$NCURSES_SRC" "$NCURSES_DST"
# Fix its install name
install_name_tool -id @executable_path/../Resources/lib/libncurses.5.4.dylib "$NCURSES_DST"
echo "  ✅ Added libncurses.5.4.dylib"

GPG_PATH="$RESOURCES_DIR/gpg"

echo ""
echo "=== 修复 GPG 和库的依赖路径 ==="

# 修复 GPG binary
install_name_tool -change /opt/homebrew/opt/gettext/lib/libintl.8.dylib @executable_path/../Resources/lib/libintl.8.dylib "$GPG_PATH"
install_name_tool -change /opt/homebrew/opt/libgcrypt/lib/libgcrypt.20.dylib @executable_path/../Resources/lib/libgcrypt.20.dylib "$GPG_PATH"
install_name_tool -change /opt/homebrew/opt/readline/lib/libreadline.8.dylib @executable_path/../Resources/lib/libreadline.8.dylib "$GPG_PATH"
install_name_tool -change /opt/homebrew/opt/libassuan/lib/libassuan.9.dylib @executable_path/../Resources/lib/libassuan.9.dylib "$GPG_PATH"
install_name_tool -change /opt/homebrew/opt/npth/lib/libnpth.0.dylib @executable_path/../Resources/lib/libnpth.0.dylib "$GPG_PATH"
install_name_tool -change /opt/homebrew/opt/libgpg-error/lib/libgpg-error.0.dylib @executable_path/../Resources/lib/libgpg-error.0.dylib "$GPG_PATH"

# 修复库的内部依赖
for lib in "$LIB_DIR"/*.dylib; do
    libname=$(basename "$lib")
    
    case "$libname" in
        libintl.8.dylib)
            # Reset to use system libiconv (fixes previous incorrect bundling)
            install_name_tool -change @executable_path/../Resources/lib/libiconv.2.dylib /usr/lib/libiconv.2.dylib "$lib" 2>/dev/null || true
            ;;
        libgcrypt.20.dylib)
            install_name_tool -change /opt/homebrew/opt/libgpg-error/lib/libgpg-error.0.dylib @executable_path/../Resources/lib/libgpg-error.0.dylib "$lib"
            ;;
        libreadline.8.dylib)
            # Fix ncurses dependency - use version 5.4 naming
            install_name_tool -change /opt/homebrew/opt/ncurses/lib/libncursesw.6.dylib @executable_path/../Resources/lib/libncurses.5.4.dylib "$lib" 2>/dev/null || true
            ;;
        libassuan.9.dylib)
            install_name_tool -change /opt/homebrew/opt/libgpg-error/lib/libgpg-error.0.dylib @executable_path/../Resources/lib/libgpg-error.0.dylib "$lib"
            ;;
    esac
done

echo ""
echo "=== 重新签名所有二进制文件 ==="

# Re-sign GPG binary after modifications
echo "Re-signing GPG binary..."
codesign --remove-signature "$GPG_PATH" 2>/dev/null || true
codesign -s - "$GPG_PATH"
echo "  ✅ GPG re-signed"

# Re-sign all libraries
if [ -d "$LIB_DIR" ] && [ "$(ls -A $LIB_DIR 2>/dev/null)" ]; then
    for lib in "$LIB_DIR"/*.dylib; do
        libname=$(basename "$lib")
        echo "Re-signing $libname..."
        codesign --remove-signature "$lib" 2>/dev/null || true
        codesign -s - "$lib" 2>/dev/null || echo "  Warning: Could not sign $libname"
    done
else
    echo "  Warning: No libraries found in $LIB_DIR"
fi

echo ""
echo "✅ 依赖路径修复和重新签名完成"
