# 🧪 Manual Testing Guide - Key Management Phase 1

## ✅ Automated Tests Passed
- [x] Build: SUCCESS
- [x] Files: All present (1004 lines of new code)
- [x] GPG Keys: Available for testing

---

## 📋 Manual Test Checklist

### Before Starting
1. **Launch the app**: `open -a Moaiy`
2. **Navigate to**: Key Management section (sidebar)

---

### Test 1: 🔍 密钥列表导航到详情页

**Steps:**
1. ✅ Verify key list is displayed
2. ✅ Click on any key in the list
3. ✅ Verify detail view opens

**What to check:**
- [ ] Keys appear in the list
- [ ] Each key shows: Name, Email, Type Badge, Trust Badge
- [ ] Clicking opens detail view (not an error)
- [ ] Can navigate back to list

**✅ PASS / ❌ FAIL**: _______

---

### Test 2: 👁️ 查看密钥详细信息

**Steps:**
1. Navigate to any key's detail view
2. Scroll through all sections

**What to check:**
- [ ] **Header**: Key icon, name, email, badges
- [ ] **Basic Info**: Key ID, Fingerprint (with spaces), Created/Expires dates
- [ ] **Trust Level**: Icon, description, level indicator
- [ ] **Technical**: Algorithm, key length, capabilities badges
- [ ] **Actions**: Export, Encrypt, Delete buttons

**Test fingerprint copy:**
- [ ] Click on fingerprint text
- [ ] Verify it copies to clipboard
- [ ] Paste somewhere to verify

**✅ PASS / ❌ FAIL**: _______

---

### Test 3: 💾 导出公钥到文件

**Steps:**
1. In detail view, click "Export Public Key" button
2. In the sheet, click "Save to File"
3. Choose location (e.g., Desktop)
4. Save the file

**What to check:**
- [ ] Export sheet appears
- [ ] Key info is correct in sheet
- [ ] File picker opens
- [ ] Default filename is correct
- [ ] File saves successfully
- [ ] File contains PGP key block:
  ```bash
  cat ~/Desktop/*public.asc
  # Should show: -----BEGIN PGP PUBLIC KEY BLOCK-----
  ```

**✅ PASS / ❌ FAIL**: _______

---

### Test 4: 📋 复制公钥到剪贴板

**Steps:**
1. Open export sheet again
2. Click "Copy to Clipboard"
3. Paste in a text editor

**What to check:**
- [ ] Button works (no crash)
- [ ] Sheet dismisses after copy
- [ ] Clipboard contains PGP key:
  ```bash
  pbpaste | head -3
  # Should show: -----BEGIN PGP PUBLIC KEY BLOCK-----
  ```

**✅ PASS / ❌ FAIL**: _______

---

### Test 5: 📥 导入密钥（拖拽和文件选择）

**Preparation:**
```bash
# Export a test key first
gpg --armor --export your-email@example.com > ~/Desktop/test_import.asc
```

**Test 5a: File Picker**
1. Click "Import Key" button in toolbar
2. Click "Select Files" button
3. Choose the test_import.asc file

**What to check:**
- [ ] Import sheet opens
- [ ] File picker works
- [ ] File preview shows filename
- [ ] Import button becomes enabled
- [ ] Click import
- [ ] Success message shows
- [ ] Key appears in list

**Test 5b: Drag & Drop**
1. Open import sheet again
2. Drag test_import.asc onto drop zone

**What to check:**
- [ ] Drop zone highlights when dragging
- [ ] File is accepted
- [ ] File preview shows
- [ ] Import works

**✅ PASS / ❌ FAIL**: _______

---

### Test 6: 🗑️ 删除密钥（确认对话框）

**⚠️ WARNING**: Only test with a key you created for testing!

**Steps:**
1. Create a disposable test key:
   ```bash
   gpg --quick-generate-key "DELETE ME <delete@test.com>" rsa2048 default 0
   ```
2. Find this key in Moaiy
3. Navigate to its detail view
4. Scroll to Actions section
5. Click "Delete Key" button
6. Confirm the deletion dialog

**What to check:**
- [ ] Confirmation dialog appears
- [ ] Dialog has Cancel and Delete buttons
- [ ] Cancel works (no deletion)
- [ ] Delete works with confirmation
- [ ] Progress indicator shows
- [ ] Returns to key list
- [ ] Key is actually deleted (check with `gpg --list-keys`)

**✅ PASS / ❌ FAIL**: _______

---

### Test 7: 🌐 中英文切换显示

**Test 7a: Switch to Chinese**

**Steps:**
1. Change system language:
   ```bash
   defaults write NSGlobalDomain AppleLanguages -array zh-Hans && killall cfprefsd
   ```
2. Restart Moaiy:
   ```bash
   killall Moaiy && open -a Moaiy
   ```

**What to check:**
- [ ] App restarts in Chinese
- [ ] Sidebar shows: 密钥管理, 加密解密, 设置
- [ ] Key list shows: 公钥/私钥 badges
- [ ] Trust levels in Chinese
- [ ] Button text in Chinese
- [ ] No English text remains

**Test 7b: Switch back to English**

**Steps:**
```bash
defaults write NSGlobalDomain AppleLanguages -array en && killall cfprefsd
killall Moaiy && open -a Moaiy
```

**What to check:**
- [ ] App shows in English
- [ ] All text properly localized

**✅ PASS / ❌ FAIL**: _______

---

## 🐛 Issues Found

### Issue 1:
**Description**: _______________
**Severity**: Critical / High / Medium / Low
**Steps to Reproduce**:
1. _______________
2. _______________
**Expected**: _______________
**Actual**: _______________

### Issue 2:
**Description**: _______________
**Severity**: Critical / High / Medium / Low
**Steps to Reproduce**:
1. _______________
2. _______________
**Expected**: _______________
**Actual**: _______________

---

## 📊 Test Summary

| Test | Status | Notes |
|------|--------|-------|
| 1. Navigation | ⬜ PASS / ⬜ FAIL | |
| 2. Detail View | ⬜ PASS / ⬜ FAIL | |
| 3. Export to File | ⬜ PASS / ⬜ FAIL | |
| 4. Copy to Clipboard | ⬜ PASS / ⬜ FAIL | |
| 5. Import | ⬜ PASS / ⬜ FAIL | |
| 6. Delete | ⬜ PASS / ⬜ FAIL | |
| 7. Localization | ⬜ PASS / ⬜ FAIL | |

**Overall Result**: ⬜ ALL PASS / ⬜ SOME FAIL

**Ready to Commit**: ⬜ YES / ⬜ NO

---

## 🎯 Test Completion

**Tester Name**: _______________
**Date**: 2026-03-21
**Time**: _______________

**Signature**: _______________

---

## 📝 Post-Test Actions

If all tests pass:
```bash
# Commit the changes
git add .
git commit -m "feat: implement Key Management Phase 1

- Add KeyDetailView with comprehensive key information display
- Implement key export/import functionality with drag-drop support
- Add key delete functionality with confirmation dialog
- Fix NavigationSplitView configuration for proper navigation
- Add 40+ localization keys for English and Chinese
- Improve navigation and user experience

Phase 1 Complete ✅
All manual tests passed"

# Push to remote
git push origin key_management
```

If tests fail:
1. Document all issues found
2. Create GitHub issues if needed
3. Fix critical/high severity issues
4. Re-test affected areas
5. Update this checklist

---

**Happy Testing! 🚀**
