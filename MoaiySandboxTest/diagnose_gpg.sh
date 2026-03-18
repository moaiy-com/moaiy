#!/bin/bash

GPG_PATH="/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/gpg"
LIB_DIR="/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/lib"

echo "=== GPG 沙盒诊断 ==="
echo ""
echo "1. 检查 GPG binary 是否可执行"
ls -la "$GPG_PATH"
echo ""
echo "2. 检查所有库文件是否存在"
ls -la "$LIB_DIR"
echo ""
echo "3. 验证 GPG binary 的依赖路径"
otool -L "$GPG_PATH" | grep -E "(homebrew|executable_path)"
echo ""
echo "4. 验证所有库的 ID 和依赖"
for lib in "$LIB_DIR"/*.dylib; do
    libname=$(basename "$lib")
    echo "--- $libname ---"
    otool -L "$lib" | head -3
done
echo ""
echo "5. 尝试直接运行 GPG（在沙盒外）"
"$GPG_PATH" --version | head -3
