# Key Management Phase 1 - Test Checklist

## Test Environment
- **Branch**: key_management
- **Build**: Debug
- **Date**: 2026-03-21
- **Tester**: _______________

---

## Pre-Test Setup

### 1. Build and Run
```bash
cd /Users/codingchef/Taugast/moaiy/Moaiy
xcodebuild -project Moaiy.xcodeproj -scheme Moaiy clean build
open -a Moaiy
```

### 2. Test Data Preparation
Ensure you have at least one GPG key in your system:
```bash
# Check existing keys
gpg --list-keys

# If no keys exist, create a test key
gpg --quick-generate-key "Test User <test@example.com>" rsa4096 default 0
```

---

## Test Cases

### ✅ Test 1: 密钥列表导航到详情页

**Steps:**
1. Launch Moaiy application
2. Navigate to "Key Management" section in sidebar
3. Verify key list is displayed
4. Click on any key in the list
5. Verify navigation to detail view

**Expected Results:**
- [ ] Key list displays all available keys
- [ ] Each key shows: name, email, key type badge, trust level badge
- [ ] Clicking a key navigates to detail view
- [ ] Navigation animation is smooth
- [ ] Back navigation works (click sidebar or swipe)

**Issues Found:**
- _______________
- _______________

---

### ✅ Test 2: 查看密钥详细信息

**Steps:**
1. Navigate to key detail view
2. Verify all sections are displayed
3. Check each information field

**Expected Results:**

**Header Section:**
- [ ] Key icon displayed (different for private/public)
- [ ] Key name displayed correctly
- [ ] Email displayed correctly
- [ ] Key type badge (Private/Public) shown
- [ ] Status indicators (Expired/Trusted) shown when applicable

**Basic Information Section:**
- [ ] Key ID displayed
- [ ] Fingerprint displayed (formatted with spaces)
- [ ] Created date displayed
- [ ] Expiration date displayed (or "No Expiration")
- [ ] Fingerprint copy button works

**Trust Level Section:**
- [ ] Current trust level displayed with icon
- [ ] Trust level description shown
- [ ] Trust level indicator shows all levels
- [ ] Current level is highlighted

**Technical Details Section:**
- [ ] Algorithm displayed (e.g., RSA)
- [ ] Key length displayed (e.g., 4096 bits)
- [ ] Key type displayed (e.g., RSA-4096)
- [ ] Capabilities badges shown (Encrypt, Sign, Certify)

**Issues Found:**
- _______________
- _______________

---

### ✅ Test 3: 导出公钥到文件

**Steps:**
1. In key detail view, click "Export Public Key" button
2. Export sheet should appear
3. Click "Save to File" button
4. File save dialog appears
5. Choose location and save
6. Verify file is created

**Expected Results:**
- [ ] Export sheet appears with key information
- [ ] "Save to File" button shows file picker
- [ ] Default filename is correct (e.g., "Test_User_public.asc")
- [ ] File saves successfully
- [ ] Saved file contains valid PGP public key
- [ ] Progress indicator shows during export
- [ ] Success feedback after export

**Verify Exported Key:**
```bash
# Check the exported file
cat ~/Downloads/Test_User_public.asc
# Should show:
# -----BEGIN PGP PUBLIC KEY BLOCK-----
# ...
# -----END PGP PUBLIC KEY BLOCK-----
```

**Issues Found:**
- _______________
- _______________

---

### ✅ Test 4: 复制公钥到剪贴板

**Steps:**
1. In key detail view, click "Export Public Key" button
2. In export sheet, click "Copy to Clipboard" button
3. Verify key is copied

**Expected Results:**
- [ ] "Copy to Clipboard" button works
- [ ] Progress indicator shows during export
- [ ] Sheet dismisses after successful copy
- [ ] Clipboard contains valid PGP public key

**Verify Clipboard:**
```bash
# Paste and check clipboard content
pbpaste | head -5
# Should show:
# -----BEGIN PGP PUBLIC KEY BLOCK-----
```

**Issues Found:**
- _______________
- _______________

---

### ✅ Test 5: 导入密钥（拖拽和文件选择）

**Test 5a: File Picker Import**

**Steps:**
1. In key list view, click "Import Key" button in toolbar
2. Import sheet appears
3. Click "Select Files" button
4. Choose a key file (.asc, .gpg, or .pgp)
5. Verify import process

**Expected Results:**
- [ ] Import sheet appears
- [ ] "Select Files" button opens file picker
- [ ] File picker filters for key files
- [ ] Selected file shows preview
- [ ] "Import" button becomes enabled
- [ ] Import process shows progress
- [ ] Success message shows after import
- [ ] Key appears in list after import

**Test 5b: Drag & Drop Import**

**Steps:**
1. Prepare a key file in Finder
2. Drag the file to the import drop zone
3. Drop the file
4. Verify import process

**Expected Results:**
- [ ] Drop zone highlights when dragging over
- [ ] Drop zone icon changes
- [ ] File preview shows after drop
- [ ] Import process works same as file picker

**Create Test Key for Import:**
```bash
# Export a test key
gpg --armor --export test@example.com > ~/Desktop/test_key.asc
```

**Issues Found:**
- _______________
- _______________

---

### ✅ Test 6: 删除密钥（确认对话框）

**Steps:**
1. Navigate to key detail view
2. Scroll to Actions section
3. Click "Delete Key" button
4. Confirmation dialog appears
5. Test Cancel and Delete options

**Expected Results:**

**Delete Button:**
- [ ] Delete button is red/destructive style
- [ ] Button shows trash icon

**Confirmation Dialog:**
- [ ] Dialog appears with warning message
- [ ] "Cancel" button works (dismisses dialog)
- [ ] "Delete" button requires explicit action
- [ ] Dialog message is clear and localized

**Delete Process:**
- [ ] Progress indicator shows during deletion
- [ ] Navigation returns to key list after deletion
- [ ] Deleted key no longer appears in list
- [ ] Error handling works if deletion fails

**Test Error Handling:**
- Try to delete a key that's in use
- Verify error message appears
- Verify user can dismiss error

**Issues Found:**
- _______________
- _______________

---

### ✅ Test 7: 中英文切换显示

**Steps:**
1. Change system language to English
2. Restart application
3. Verify all UI strings are in English
4. Change system language to Chinese (Simplified)
5. Restart application
6. Verify all UI strings are in Chinese

**Expected Results:**

**English:**
- [ ] Section titles in English
- [ ] Button labels in English
- [ ] Error messages in English
- [ ] Trust level descriptions in English
- [ ] All UI elements properly localized

**Chinese (Simplified):**
- [ ] Section titles in Chinese
- [ ] Button labels in Chinese
- [ ] Error messages in Chinese
- [ ] Trust level descriptions in Chinese
- [ ] All UI elements properly localized

**Test Specific Strings:**
```
English:
- "Key Management" ✓/✗
- "Create Key" ✓/✗
- "Export Public Key" ✓/✗
- "Delete Key" ✓/✗
- "No Keys Yet" ✓/✗

Chinese:
- "密钥管理" ✓/✗
- "创建密钥" ✓/✗
- "导出公钥" ✓/✗
- "删除密钥" ✓/✗
- "还没有密钥" ✓/✗
```

**Change Language:**
```bash
# Change to English
defaults write NSGlobalDomain AppleLanguages -array en
killall cfprefsd

# Change to Chinese
defaults write NSGlobalDomain AppleLanguages -array zh-Hans
killall cfprefsd

# Restart app
killall Moaiy
open -a Moaiy
```

**Issues Found:**
- _______________
- _______________

---

## Edge Cases & Error Handling

### Test 8: Empty State
**Steps:**
1. Remove all test keys (or use fresh GPG home)
2. Launch application
3. Navigate to Key Management

**Expected Results:**
- [ ] Empty state view appears
- [ ] "No Keys Yet" title shown
- [ ] Helpful description displayed
- [ ] "Create Your First Key" button shown
- [ ] Button navigates to key creation

### Test 9: Loading State
**Steps:**
1. Launch application with many keys
2. Observe initial loading

**Expected Results:**
- [ ] Loading indicator shows
- [ ] "Loading keys..." message displayed
- [ ] List appears after loading completes

### Test 10: Search Functionality
**Steps:**
1. Enter search term in search field
2. Verify filtering works

**Expected Results:**
- [ ] Search field is accessible
- [ ] Keys filter by name
- [ ] Keys filter by email
- [ ] Keys filter by fingerprint
- [ ] Clear search restores full list

---

## Performance Testing

### Test 11: Large Key List
**Steps:**
1. Import or create 20+ keys
2. Test scrolling and navigation

**Expected Results:**
- [ ] List scrolls smoothly
- [ ] Navigation remains responsive
- [ ] No memory leaks
- [ ] No UI freezing

---

## Final Checklist

### All Tests Passed
- [ ] Test 1: Navigation
- [ ] Test 2: Detail View
- [ ] Test 3: Export to File
- [ ] Test 4: Export to Clipboard
- [ ] Test 5: Import (File Picker & Drag/Drop)
- [ ] Test 6: Delete
- [ ] Test 7: Localization
- [ ] Test 8: Empty State
- [ ] Test 9: Loading State
- [ ] Test 10: Search
- [ ] Test 11: Performance

### Critical Issues
- _______________
- _______________
- _______________

### Minor Issues
- _______________
- _______________
- _______________

### Enhancement Suggestions
- _______________
- _______________
- _______________

---

## Test Completion

**Tester Signature**: _______________

**Date**: _______________

**Overall Status**: 
- [ ] ✅ PASS - Ready for merge
- [ ] ⚠️ CONDITIONAL PASS - Minor issues, can merge with notes
- [ ] ❌ FAIL - Critical issues, do not merge

**Notes:**
```
[Add any additional notes here]
```

---

## Automated Testing Commands

### Quick Verification Script
```bash
#!/bin/bash
echo "Running automated checks..."

# 1. Build check
echo "1. Building project..."
cd /Users/codingchef/Taugast/moaiy/Moaiy
xcodebuild -project Moaiy.xcodeproj -scheme Moaiy clean build | grep -E "BUILD SUCCEEDED|BUILD FAILED"

# 2. Check for localization keys
echo "2. Checking localization..."
grep -c "\"action_export_public_key\"" Resources/Localizable.xcstrings
grep -c "\"action_import_key\"" Resources/Localizable.xcstrings

# 3. Verify files exist
echo "3. Verifying files..."
ls -lh Views/KeyManagement/KeyDetailView.swift
ls -lh Views/KeyManagement/ImportKeySheet.swift

# 4. Launch app
echo "4. Launching application..."
open -a Moaiy

echo "Automated checks complete. Please perform manual testing."
```

Save as `test_phase1.sh` and run:
```bash
chmod +x test_phase1.sh
./test_phase1.sh
```
