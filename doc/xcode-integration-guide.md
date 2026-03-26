# Xcode Integration Guide - Adding GPG Bundle to Project

> **Objective**: Add gpg.bundle to Moaiy.xcodeproj
> **Time Required**: ~30 minutes
> **Difficulty**: Easy

---

## 📋 Prerequisites

Before starting, ensure:
- ✅ Xcode installed (version 15.0+)
- ✅ Moaiy.xcodeproj exists
- ✅ gpg.bundle exists at `Moaiy/Resources/gpg.bundle`
- ✅ No Xcode instances running

---

## 🎯 Integration Steps

### Step 1: Open Xcode Project (2 minutes)

```bash
# Navigate to project directory
cd /Users/codingchef/Taugast/moaiy

# Open Xcode project
open Moaiy/Moaiy.xcodeproj
```

**Alternative**: Double-click `Moaiy.xcodeproj` in Finder

---

### Step 2: Locate Resources Group (1 minute)

1. In Xcode, look at the **Project Navigator** (left sidebar)
2. Find the **Moaiy** project (blue icon at top)
3. Expand it to see groups:
   ```
   Moaiy
   ├── Moaiy (target)
   ├── Resources
   │   ├── Assets.xcassets
   │   ├── Localizable.xcstrings
   │   └── Entitlements.entitlements
   ├── ViewModels
   ├── Views
   └── ...
   ```

4. **Right-click** on the **Resources** group

---

### Step 3: Add GPG Bundle (5 minutes)

#### Option A: Using "Add Files" (Recommended)

1. **Right-click** on **Resources** group
2. Select **"Add Files to 'Moaiy'..."**
3. In the file picker:
   - Navigate to: `Moaiy/Resources/gpg.bundle`
   - **Important settings**:
     - ☑️ **Destination**: Copy items if needed → **UNCHECK** ❌
     - ☑️ **Added folders**: Create groups → **CHECK** ✅
     - ☑️ **Add to targets**: Moaiy → **CHECK** ✅
4. Click **"Add"**

#### Option B: Drag and Drop

1. Open Finder
2. Navigate to: `Moaiy/Resources/gpg.bundle`
3. **Drag** `gpg.bundle` from Finder
4. **Drop** it onto the **Resources** group in Xcode
5. In the dialog that appears:
   - ☑️ **Copy items if needed**: **UNCHECK** ❌
   - ☑️ **Create groups**: **CHECK** ✅
   - ☑️ **Add to targets**: Moaiy → **CHECK** ✅
6. Click **"Finish"**

---

### Step 4: Verify Bundle Addition (3 minutes)

#### 4.1 Check Project Navigator

After adding, you should see:

```
Resources
├── Assets.xcassets
├── gpg.bundle         ← NEW!
│   ├── bin
│   ├── lib
│   ├── manifest.json
│   └── share
├── Localizable.xcstrings
└── Entitlements.entitlements
```

**Expand** `gpg.bundle` to verify structure:
- Should show `bin`, `lib`, `manifest.json`, `share`

#### 4.2 Check Build Phases

1. Click on the **Moaiy project** (blue icon at top of navigator)
2. Select **Moaiy** target
3. Click **"Build Phases"** tab
4. Expand **"Copy Bundle Resources"**
5. Verify `gpg.bundle` is listed

**If not listed**:
1. Click **"+"** button in "Copy Bundle Resources"
2. Select `gpg.bundle`
3. Click **"Add"**

---

### Step 5: Configure Build Settings (Optional, 2 minutes)

#### 5.1 Verify Bundle is Included

1. Select **Moaiy** target
2. Click **"Build Settings"** tab
3. Search for "Copy Bundle Resources"
4. Verify `gpg.bundle` appears in the list

#### 5.2 Ensure Proper Copy

The bundle should be automatically copied to:
```
Moaiy.app/Contents/Resources/gpg.bundle/
```

No additional configuration needed!

---

### Step 6: Test Build (5 minutes)

#### 6.1 Clean Build Folder

```bash
# In Xcode menu:
Product → Clean Build Folder
# Or press: Shift + Cmd + K
```

#### 6.2 Build Project

```bash
# In Xcode menu:
Product → Build
# Or press: Cmd + B
```

**Expected**: Build should succeed ✅

#### 6.3 Verify Bundle in Built App

```bash
# Navigate to built app
cd ~/Library/Developer/Xcode/DerivedData/Moaiy-*/Build/Products/Debug/

# Check if bundle exists
ls -la Moaiy.app/Contents/Resources/gpg.bundle/

# Expected output:
# drwxr-xr-x  bin
# drwxr-xr-x  lib
# -rw-r--r--  manifest.json
# drwxr-xr-x  share
```

**Alternative** (in Terminal):
```bash
# Run verification script
cd /Users/codingchef/Taugast/moaiy
swift scripts/test_bundled_gpg_integration.swift
```

---

### Step 7: Test in App (5 minutes)

#### 7.1 Run App

```bash
# In Xcode menu:
Product → Run
# Or press: Cmd + R
```

#### 7.2 Check Console Logs

When app launches, check Xcode console for:
```
GPGService: Found gpg.bundle at: .../Moaiy.app/Contents/Resources/gpg.bundle
GPGService: Using bundled GPG: .../Moaiy.app/Contents/Resources/gpg.bundle/bin/gpg
GPGService: GPG version: 2.5.18
```

#### 7.3 Test GPG Functionality

In the app:
1. Navigate to **Key Management** section
2. Try to **list keys**
3. Try to **create a new key**

**Expected**: All operations should work using bundled GPG ✅

---

## 🔍 Troubleshooting

### Issue 1: Bundle Not in Copy Bundle Resources

**Symptoms**:
- Bundle not in `Moaiy.app/Contents/Resources/`
- App can't find bundled GPG

**Solution**:
1. Select Moaiy target
2. Go to Build Phases → Copy Bundle Resources
3. Click "+" button
4. Add `gpg.bundle`

### Issue 2: Build Fails with "No such file or directory"

**Symptoms**:
- Build error about missing gpg.bundle

**Solution**:
1. Check bundle exists: `ls -la Moaiy/Resources/gpg.bundle`
2. If missing, run: `./scripts/prepare_gpg_bundle.sh`
3. Re-add bundle to Xcode

### Issue 3: GPG Not Found at Runtime

**Symptoms**:
- Console shows: "Bundle not found in Bundle.main"
- App falls back to system GPG

**Solution**:
1. Verify bundle in Copy Bundle Resources
2. Clean and rebuild
3. Check bundle is in app package (Step 6.3)

### Issue 4: Code Signing Issues

**Symptoms**:
- Build fails with code signing error

**Solution**:
1. Select Moaiy target
2. Build Settings → Signing & Capabilities
3. Ensure "Sign to Run Locally" is selected (Debug)
4. For Release, use proper signing certificate

---

## 📸 Visual Guide

### Xcode Interface Overview

```
┌─────────────────────────────────────────────────────────┐
│ Xcode                                                    │
├────────────────┬────────────────────────────────────────┤
│ Project        │ Editor Area                            │
│ Navigator      │                                        │
│                │                                        │
│ ▼ Moaiy        │  ┌──────────────────────────────────┐ │
│   ▼ Moaiy      │  │ Build Phases                     │ │
│   ▼ Resources  │  │ ├─ Target Dependencies           │ │
│   │  Assets    │  │ ├─ Compile Sources               │ │
│   │  gpg.bundle│←─┤ ├─ Copy Bundle Resources          │ │
│   │  Localiz..│  │ │  └─ gpg.bundle ← Should be here│ │
│   ▼ ViewModels │  │ ├─ Link Binary With Libraries    │ │
│   ▼ Views      │  │ └─ Copy Files                    │ │
│                │  └──────────────────────────────────┘ │
└────────────────┴────────────────────────────────────────┘
```

---

## ✅ Verification Checklist

After integration, verify:

- [ ] Bundle appears in Project Navigator (Resources group)
- [ ] Bundle is in Copy Bundle Resources build phase
- [ ] Build succeeds without errors
- [ ] Bundle exists in `Moaiy.app/Contents/Resources/`
- [ ] App console shows "Using bundled GPG"
- [ ] GPG operations work correctly in app

---

## 🚀 Quick Reference Commands

```bash
# Open Xcode
open Moaiy/Moaiy.xcodeproj

# Clean build
xcodebuild clean -project Moaiy/Moaiy.xcodeproj -scheme Moaiy

# Build Debug
xcodebuild -project Moaiy/Moaiy.xcodeproj -scheme Moaiy -configuration Debug

# Build Release
xcodebuild -project Moaiy/Moaiy.xcodeproj -scheme Moaiy -configuration Release

# Check bundle in built app
find ~/Library/Developer/Xcode/DerivedData/Moaiy-*/Build/Products/Debug/Moaiy.app -name "gpg.bundle"

# Test GPG in built app
~/Library/Developer/Xcode/DerivedData/Moaiy-*/Build/Products/Debug/Moaiy.app/Contents/Resources/gpg.bundle/bin/gpg --version
```

---

## 📝 Post-Integration Steps

After successful integration:

1. **Test thoroughly** (1-2 hours)
   - Test all GPG operations
   - Test key management
   - Test encryption/decryption

2. **Create test suite** (4-6 hours)
   - Write unit tests
   - Write integration tests

3. **Update documentation**
   - Mark Xcode integration as complete
   - Update progress to 75%

4. **Prepare for release**
   - Production signing
   - Notarization

---

## 🎯 Success Criteria

Integration is successful when:

- ✅ Bundle appears in Xcode project
- ✅ Bundle in Copy Bundle Resources phase
- ✅ Build succeeds
- ✅ Bundle in built app package
- ✅ App uses bundled GPG
- ✅ All GPG operations work
- ✅ No fallback to system GPG

---

## 📞 Need Help?

If you encounter issues:

1. **Check documentation**:
   - `doc/bundled-gpg-quick-start.md`
   - `doc/bundled-gpg-development-plan.md`

2. **Run verification**:
   ```bash
   swift scripts/test_bundled_gpg_integration.swift
   ```

3. **Check console logs**:
   - Look for GPGService messages
   - Check for errors

4. **Rebuild from scratch**:
   ```bash
   # Clean everything
   xcodebuild clean -allprojects
   
   # Rebuild bundle
   ./scripts/prepare_gpg_bundle.sh
   
   # Re-add to Xcode
   ```

---

**Estimated Time**: 30 minutes
**Difficulty**: Easy
**Risk**: Low
**Impact**: High (50% → 75% progress)

