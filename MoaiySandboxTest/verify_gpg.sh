#!/bin/bash

GPG_PATH="/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app/Contents/Resources/gpg"

echo "=== GPG Bundled Binary Verification ==="
echo ""

if [ -f "$GPG_PATH" ]; then
    echo "✅ GPG binary found at: $GPG_PATH"
    echo ""
    echo "File info:"
    file "$GPG_PATH"
    echo ""
    echo "Testing execution..."
    "$GPG_PATH" --version | head -3
    echo ""
    echo "✅ SUCCESS: Bundled GPG works in app bundle!"
else
    echo "❌ GPG binary not found"
fi
