# Phase 3 Setup Instructions

## ⚠️ Manual Step Required

Before building Phase 3 features, you need to manually add the new files to Xcode:

### Steps:

1. **Open Xcode Project**
   ```bash
   cd /Users/codingchef/Taugast/moaiy/Moaiy
   open Moaiy.xcodeproj
   ```

2. **Add New Swift Files**
   In Xcode, add these files to the `Views/KeyManagement` folder:
   - `TrustManagementSheet.swift`
   - `KeySigningSheet.swift`
   - `KeyEditSheet.swift`

   For each file:
   - Right-click on `Views/KeyManagement` folder in project navigator
   - Select "Add Files to Moaiy..."
   - Navigate to and select the file
   - Make sure "Copy items if needed" is **unchecked** (file already exists)
   - Make sure "Add to targets: Moaiy" is **checked**
   - Click "Add"

3. **Verify**
   - Build the project (⌘+B)
   - Should compile without errors

## Phase 3 Features Implemented

### 1. Trust Management Interface ✅
- **File**: `TrustManagementSheet.swift` (300+ lines)
- **Features**:
  - Display current trust level with visual indicators
  - Select new trust level from 5 options (Unknown, None, Marginal, Full, Ultimate)
  - View trust details (signature count, last checked date)
  - Warning for Ultimate trust level
  - Save changes with proper error handling
  - Full i18n support (EN + ZH)

### 2. Key Signing UI ✅
- **File**: `KeySigningSheet.swift` (300+ lines)
- **Features**:
  - Sign other keys to certify their authenticity
  - Select signing key from available secret keys
  - Enter passphrase for signing key
  - Optionally set trust level after signing
  - Warning and info text for security awareness
  - Full i18n support (EN + ZH)

### 3. Key Editing Features ✅
- **File**: `KeyEditSheet.swift` (450+ lines)
- **Features**:
  - **Expiration Tab**: Change key expiration (Never/1Y/2Y/5Y/Custom date)
  - **User IDs Tab**: Add new user IDs to a key
  - **Passphrase Tab**: Change key passphrase
  - Tabbed interface with clear navigation
  - Validation and error handling
  - Full i18n support (EN + ZH)

### 4. UI Integration ✅
- Added "Manage" button in KeyDetailView Status Section (trust management)
- Added "Sign Key" button in Actions Section (key signing)
- Added "Edit" button in toolbar (key editing)
- All features integrated with existing KeyManagementViewModel

## Localization

**Total New Keys**: 42
- Trust Management: 6 keys
- Key Signing: 13 keys
- Key Editing: 23 keys

All keys support English and Chinese (Simplified).

## Testing Checklist

After adding files to Xcode:

### Trust Management
- [ ] Open trust management sheet from "Manage" button
- [ ] View current trust level and details
- [ ] Select different trust levels
- [ ] Save changes successfully
- [ ] Verify trust level updates in key list

### Key Signing
- [ ] Open signing sheet from "Sign Key" button
- [ ] Select signing key from secret keys
- [ ] Enter passphrase
- [ ] Set trust level after signing
- [ ] Complete signing successfully
- [ ] Verify signature appears on key

### Key Editing
- [ ] Open edit sheet from "Edit" button
- [ ] Test expiration editing (all options)
- [ ] Test adding new user ID
- [ ] Test passphrase change
- [ ] Verify changes persist

## Next Steps

1. Add files to Xcode project (manual)
2. Build and test all Phase 3 features
3. Create comprehensive test report
4. Consider Phase 4 features (backup/restore, statistics)

---

**Status**: Phase 3 code complete, waiting for manual Xcode setup
**Commit**: 4ffcc56
**Date**: 2026-03-22
**Files Created**: 3 (TrustManagementSheet.swift, KeySigningSheet.swift, KeyEditSheet.swift)
**Lines Added**: ~1050
**Localization Keys**: 42
