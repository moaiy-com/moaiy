#!/bin/bash

# Key Management Phase 1 - Automated Test Script
# Run this script to perform initial automated checks

set -e

echo "=================================================="
echo "  Key Management Phase 1 - Automated Tests"
echo "=================================================="
echo ""

PROJECT_DIR="/Users/codingchef/Taugast/moaiy/Moaiy"
cd "$PROJECT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

echo "Test 1: Build Verification"
echo "----------------------------"
xcodebuild -project Moaiy.xcodeproj -scheme Moaiy -configuration Debug clean build > /tmp/build.log 2>&1
if grep -q "BUILD SUCCEEDED" /tmp/build.log; then
    print_result 0 "Project builds successfully"
else
    print_result 1 "Project build failed"
    echo "Build log:"
    tail -20 /tmp/build.log
fi
echo ""

echo "Test 2: File Existence Checks"
echo "-------------------------------"
if [ -f "Views/KeyManagement/KeyDetailView.swift" ]; then
    print_result 0 "KeyDetailView.swift exists"
    LINES=$(wc -l < "Views/KeyManagement/KeyDetailView.swift")
    echo "  → File has $LINES lines"
else
    print_result 1 "KeyDetailView.swift missing"
fi

if [ -f "Views/KeyManagement/ImportKeySheet.swift" ]; then
    print_result 0 "ImportKeySheet.swift exists"
    LINES=$(wc -l < "Views/KeyManagement/ImportKeySheet.swift")
    echo "  → File has $LINES lines"
else
    print_result 1 "ImportKeySheet.swift missing"
fi
echo ""

echo "Test 3: Localization Keys"
echo "---------------------------"
KEYS=(
    "action_export_public_key"
    "action_import_key"
    "action_delete_key"
    "section_basic_info"
    "section_trust_level"
    "section_technical_details"
    "section_actions"
    "label_key_id"
    "label_fingerprint"
    "label_created"
    "label_expires"
    "empty_keys_title"
    "empty_keys_description"
)

MISSING_KEYS=0
for KEY in "${KEYS[@]}"; do
    if grep -q "\"$KEY\"" Resources/Localizable.xcstrings; then
        echo -e "  ${GREEN}✓${NC} $KEY"
    else
        echo -e "  ${RED}✗${NC} $KEY (missing)"
        ((MISSING_KEYS++))
    fi
done

if [ $MISSING_KEYS -eq 0 ]; then
    print_result 0 "All localization keys present"
else
    print_result 1 "$MISSING_KEYS localization keys missing"
fi
echo ""

echo "Test 4: Code Quality Checks"
echo "-----------------------------"
# Check for TODOs
TODOS=$(grep -r "TODO:" Views/KeyManagement/*.swift | wc -l | tr -d ' ')
if [ "$TODOS" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} Found $TODOS TODO comments"
    grep -r "TODO:" Views/KeyManagement/*.swift | head -5
else
    echo -e "  ${GREEN}✓${NC} No TODO comments found"
fi

# Check for print statements (should use logger instead)
PRINTS=$(grep -r "print(" Views/KeyManagement/*.swift | wc -l | tr -d ' ')
if [ "$PRINTS" -gt 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} Found $PRINTS print statements (consider using logger)"
else
    echo -e "  ${GREEN}✓${NC} No print statements found"
fi
echo ""

echo "Test 5: GPG Key Check"
echo "----------------------"
if command -v gpg &> /dev/null; then
    KEY_COUNT=$(gpg --list-keys 2>/dev/null | grep -c "^pub" || echo "0")
    if [ "$KEY_COUNT" -gt 0 ]; then
        print_result 0 "Found $KEY_COUNT GPG keys for testing"
        echo "  Keys:"
        gpg --list-keys --keyid-format LONG 2>/dev/null | grep "^uid" | head -3
    else
        echo -e "  ${YELLOW}⚠${NC} No GPG keys found. Create one for testing:"
        echo "    gpg --quick-generate-key \"Test User <test@example.com>\" rsa4096 default 0"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} GPG not installed"
fi
echo ""

echo "Test 6: Application Launch"
echo "----------------------------"
if pgrep -x "Moaiy" > /dev/null; then
    echo -e "  ${YELLOW}⚠${NC} Moaiy is already running. Killing..."
    killall Moaiy 2>/dev/null || true
    sleep 1
fi

echo "  Launching Moaiy..."
open -a Moaiy
sleep 2

if pgrep -x "Moaiy" > /dev/null; then
    print_result 0 "Application launched successfully"
    echo -e "  ${GREEN}✓${NC} Moaiy is running (PID: $(pgrep -x Moaiy))"
else
    print_result 1 "Application failed to launch"
fi
echo ""

echo "=================================================="
echo "  Test Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All automated tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Perform manual testing using TEST_CHECKLIST.md"
    echo "2. Test all UI interactions"
    echo "3. Verify localization (English/Chinese)"
    echo "4. Test export/import/delete functionality"
    echo ""
    echo "Ready for manual testing!"
else
    echo -e "${RED}❌ Some automated tests failed${NC}"
    echo "Please fix the issues before proceeding to manual testing."
fi
echo ""

echo "=================================================="
echo "  Quick Test Commands"
echo "=================================================="
echo "# Export a test key for import testing:"
echo "gpg --armor --export test@example.com > ~/Desktop/test_key.asc"
echo ""
echo "# Change system language to English:"
echo "defaults write NSGlobalDomain AppleLanguages -array en && killall cfprefsd"
echo ""
echo "# Change system language to Chinese:"
echo "defaults write NSGlobalDomain AppleLanguages -array zh-Hans && killall cfprefsd"
echo ""
echo "# Restart app after language change:"
echo "killall Moaiy && open -a Moaiy"
echo "=================================================="
