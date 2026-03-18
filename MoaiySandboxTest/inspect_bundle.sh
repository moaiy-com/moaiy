#!/bin/bash

echo "=== App Bundle Structure Analysis ==="
echo ""

APP_PATH="/Users/codingchef/Library/Developer/Xcode/DerivedData/MoaiySandboxTest-bhkozavfvenkuwbhrsvhoebgezas/Build/Products/Debug/MoaiySandboxTest.app"

echo "App path: $APP_PATH"
echo ""

if [ -d "$APP_PATH" ]; then
    echo "✓ App exists"
    echo ""
    
    echo "=== Contents Structure ==="
    find "$APP_PATH/Contents" -type f 2>/dev/null | head -20
    
    echo ""
    echo "=== Resources Directory ==="
    if [ -d "$APP_PATH/Contents/Resources" ]; then
        ls -la "$APP_PATH/Contents/Resources"
    else
        echo "Resources directory does not exist"
    fi
    
    echo ""
    echo "=== MacOS Directory ==="
    if [ -d "$APP_PATH/Contents/MacOS" ]; then
        ls -la "$APP_PATH/Contents/MacOS"
    else
        echo "MacOS directory does not exist"
    fi
    
    echo ""
    echo "=== Searching for gpg binary ==="
    find "$APP_PATH" -name "gpg" 2>/dev/null
    
else
    echo "❌ App not found at $APP_PATH"
fi
