#!/bin/bash

# Phase 3 Automated Test Script
# Tests trust management, key signing, and key editing features

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper functions
print_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$status" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        [ -n "$message" ] && echo "   $message"
    elif [ "$status" = "FAIL" ]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        [ -n "$message" ] && echo "   $message"
    else
        echo -e "${YELLOW}⏸ SKIP${NC}: $test_name"
        [ -n "$message" ] && echo "   $message"
    fi
}

print_section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Change to project directory
cd /Users/codingchef/Taugast/moaiy/Moaiy

print_section "Phase 3 Automated Tests"

# Test 1: Check if source files exist
print_section "Test 1: Source Files Verification"

FILES=(
    "Views/KeyManagement/TrustManagementSheet.swift"
    "Views/KeyManagement/KeySigningSheet.swift"
    "Views/KeyManagement/KeyEditSheet.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        print_test "File exists: $file" "PASS"
    else
        print_test "File exists: $file" "FAIL" "File not found"
    fi
done

# Test 2: Build Verification
print_section "Test 2: Build Verification"

echo "Building project..."
if xcodebuild -project Moaiy.xcodeproj -scheme Moaiy -configuration Debug clean build 2>&1 | grep -q "BUILD SUCCEEDED"; then
    print_test "Project builds successfully" "PASS"
else
    print_test "Project builds successfully" "FAIL" "Build failed"
    echo ""
    echo "Build output:"
    xcodebuild -project Moaiy.xcodeproj -scheme Moaiy -configuration Debug build 2>&1 | grep -E "error:|warning:" | head -20
fi

# Test 3: GPG Keys Check
print_section "Test 3: GPG Environment"

if command -v gpg &> /dev/null; then
    print_test "GPG is installed" "PASS"
    
    KEY_COUNT=$(gpg --list-keys 2>/dev/null | grep -c "^pub")
    if [ "$KEY_COUNT" -gt 0 ]; then
        print_test "GPG keys available" "PASS" "Found $KEY_COUNT key(s)"
    else
        print_test "GPG keys available" "SKIP" "No keys found (create test key: gpg --quick-generate-key)"
    fi
else
    print_test "GPG is installed" "FAIL" "GPG not found"
fi

# Test 4: Application Launch Test
print_section "Test 4: Application Launch"

echo "Launching Moaiy..."
killall Moaiy 2>/dev/null
sleep 1

if open -a Moaiy; then
    sleep 3
    
    if pgrep -f "Moaiy.app" > /dev/null; then
        print_test "Application launches successfully" "PASS"
        
        # Get PID
        PID=$(pgrep -f "Moaiy.app")
        print_test "Application running" "PASS" "PID: $PID"
    else
        print_test "Application launches successfully" "FAIL" "Process not found"
    fi
else
    print_test "Application launches successfully" "FAIL" "Failed to launch"
fi

# Test 5: Localization Keys Check
print_section "Test 5: Localization Verification"

LOCALIZATION_FILE="Resources/Localizable.xcstrings"

if [ -f "$LOCALIZATION_FILE" ]; then
    print_test "Localization file exists" "PASS"
    
    # Check for Phase 3 keys
    PHASE3_KEYS=(
        "trust_management_title"
        "sign_key_title"
        "edit_key_title"
    )
    
    for key in "${PHASE3_KEYS[@]}"; do
        if grep -q "\"$key\"" "$LOCALIZATION_FILE"; then
            print_test "Localization key: $key" "PASS"
        else
            print_test "Localization key: $key" "FAIL" "Key not found"
        fi
    done
else
    print_test "Localization file exists" "FAIL" "File not found"
fi

# Test 6: Code Quality Check
print_section "Test 6: Code Quality"

# Check for TODOs (these are expected in Phase 3)
TODO_COUNT=$(grep -r "// TODO:" Views/KeyManagement/KeyEditSheet.swift 2>/dev/null | wc -l)
print_test "TODO comments in KeyEditSheet" "SKIP" "Found $TODO_COUNT TODO(s) - Backend implementation pending"

# Check for force unwraps (should be none)
FORCE_UNWRAP=$(grep -r "!" Views/KeyManagement/*.swift 2>/dev/null | grep -v "// " | grep -v "/* " | wc -l)
if [ "$FORCE_UNWRAP" -eq 0 ]; then
    print_test "No force unwraps found" "PASS"
else
    print_test "No force unwraps found" "FAIL" "Found $FORCE_UNWRAP force unwrap(s)"
fi

# Summary
print_section "Test Summary"

echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Tests Skipped: $((TESTS_TOTAL - TESTS_PASSED - TESTS_FAILED))${NC}"
echo -e "Total Tests: $TESTS_TOTAL${NC}"
echo ""

# Calculate pass rate
if [ $TESTS_TOTAL -gt 0 ]; then
    PASS_RATE=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    echo -e "Pass Rate: ${PASS_RATE}%${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ ALL TESTS PASSED - Ready for manual testing${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Manual UI testing (see PHASE3_TEST_GUIDE.md)"
        echo "2. Test trust management features"
        echo "3. Test key signing features"
        echo "4. Test key editing features"
        echo "5. Test localization (Chinese/English)"
        exit 0
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ SOME TESTS FAILED - Please fix issues${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No tests were run${NC}"
    exit 1
fi
