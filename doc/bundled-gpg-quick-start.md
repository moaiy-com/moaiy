# Bundled GPG Feature - Quick Start Guide

> **Branch**: `feature/bundled-gpg`
> **Created**: 2026-03-26

---

## 🎯 Overview

This guide will help you get started with implementing the bundled GPG feature for Moaiy.

## 📋 Prerequisites

Before you begin, ensure you have:

- ✅ macOS 12.0 or later
- ✅ Xcode 15.0 or later
- ✅ Homebrew installed
- ✅ GPG installed via Homebrew (`brew install gnupg`)
- ✅ Apple Developer account (for code signing)
- ✅ Clean macOS VM for testing (optional but recommended)

## 🚀 Quick Start

### Step 1: Verify Current Setup

```bash
# Check current branch
git branch --show-current
# Expected: feature/bundled-gpg

# Check GPG installation
gpg --version
# Expected: gpg (GnuPG) 2.x.x

# Check Homebrew GPG location
which gpg
# Expected: /opt/homebrew/bin/gpg (Apple Silicon) or /usr/local/bin/gpg (Intel)
```

### Step 2: Review Documentation

```bash
# Read the development plan
cat doc/bundled-gpg-development-plan.md

# Review task tracking
cat doc/bundled-gpg-task-tracking.md
```

### Step 3: Start Phase 1

Phase 1 focuses on GPG bundle preparation. Here's what to do:

#### 3.1 Enhance the Packaging Script

The existing `scripts/fix_gpg_deps.sh` script needs improvements:

```bash
# Review current script
cat scripts/fix_gpg_deps.sh

# Create enhanced version
# See Phase 1.1 in development plan for details
```

#### 3.2 Create GPG Bundle

```bash
# Run the packaging script
./scripts/fix_gpg_deps.sh

# Verify the bundle
ls -la MoaiySandboxTest/Resources/gpg.bundle/

# Test GPG executable
./MoaiySandboxTest/Resources/gpg.bundle/bin/gpg --version
```

#### 3.3 Run Verification Script

```bash
# Run the verification script
./scripts/verify_gpg_bundle.sh

# Expected: All checks pass with no failures
```

## 📊 Development Workflow

### Daily Workflow

1. **Start of Day**
   ```bash
   # Pull latest changes
   git pull origin feature/bundled-gpg
   
   # Review task tracking
   cat doc/bundled-gpg-task-tracking.md
   
   # Check current progress
   ```

2. **During Development**
   ```bash
   # Make changes to code
   
   # Test changes
   xcodebuild test -project Moaiy.xcodeproj -scheme Moaiy
   
   # Commit changes
   git add .
   git commit -m "feat: describe your changes"
   ```

3. **End of Day**
   ```bash
   # Update task tracking
   # Document progress and blockers
   
   # Push changes
   git push origin feature/bundled-gpg
   ```

### Phase Checklist

#### Phase 1: GPG Bundle Preparation (2-3 days)
- [ ] Enhance `scripts/fix_gpg_deps.sh` script
- [ ] Create `scripts/prepare_gpg_bundle.sh`
- [ ] Test bundle creation
- [ ] Run verification script
- [ ] Document results

#### Phase 2: Xcode Integration (1-2 days)
- [ ] Add bundle to Xcode project
- [ ] Update GPGService.swift
- [ ] Test in Debug mode
- [ ] Test in Release mode

#### Phase 3: Sandbox Testing (2-3 days)
- [ ] Create comprehensive test suite
- [ ] Test in strict sandbox
- [ ] Test on clean macOS VM
- [ ] Document all results

#### Phase 4: Code Signing (1-2 days)
- [ ] Sign all binaries
- [ ] Verify signatures
- [ ] Submit for notarization
- [ ] Test notarized app

#### Phase 5: Integration Testing (2-3 days)
- [ ] Test all user flows
- [ ] Performance testing
- [ ] Compatibility testing
- [ ] Stress testing

#### Phase 6: Documentation & Polish (1-2 days)
- [ ] Update all documentation
- [ ] Code review
- [ ] Final polish
- [ ] Prepare for release

## 🧪 Testing Strategy

### Unit Tests
```bash
# Run all unit tests
xcodebuild test -project Moaiy.xcodeproj \
                -scheme Moaiy \
                -destination 'platform=macOS'
```

### Integration Tests
```bash
# Run integration tests
xcodebuild test -project Moaiy.xcodeproj \
                -scheme Moaiy \
                -destination 'platform=macOS' \
                -only-testing:MoaiyTests/IntegrationTests
```

### Manual Tests
1. Build and run app in Xcode
2. Test all GPG operations
3. Verify error handling
4. Check performance

## 🐛 Troubleshooting

### Common Issues

#### Issue: GPG executable not found
```bash
# Check if GPG is installed
which gpg

# Install GPG if needed
brew install gnupg
```

#### Issue: Library not loaded
```bash
# Check library dependencies
otool -L Moaiy/Resources/gpg.bundle/lib/libgcrypt.20.dylib

# Should use @executable_path, not absolute paths
```

#### Issue: Code signature invalid
```bash
# Re-sign the bundle
./scripts/sign_gpg_bundle.sh

# Verify signature
codesign --verify --deep --strict Moaiy.app
```

#### Issue: Sandbox permission denied
```bash
# Check entitlements
cat Moaiy/Resources/Entitlements.entitlements

# Ensure sandbox is enabled in Release
# com.apple.security.app-sandbox = true
```

## 📚 Resources

### Documentation
- [Development Plan](./bundled-gpg-development-plan.md)
- [Task Tracking](./bundled-gpg-task-tracking.md)
- [Technical Architecture](./technical-architecture.md)
- [Sandbox Testing Plan](./sandbox-testing-plan.md)

### External Resources
- [GPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [Apple Sandbox Guide](https://developer.apple.com/documentation/security/app_sandbox)
- [Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### Related Files
- `scripts/fix_gpg_deps.sh` - GPG packaging script
- `scripts/verify_gpg_bundle.sh` - Bundle verification
- `Moaiy/Services/GPGService.swift` - GPG service implementation
- `Moaiy/Resources/Entitlements.entitlements` - Sandbox configuration

## 🎯 Success Criteria

The feature is complete when:

- ✅ GPG bundle created and verified
- ✅ Integrated into Xcode project
- ✅ Works in sandbox environment
- ✅ All tests pass (unit + integration)
- ✅ Code signed and notarized
- ✅ Documentation updated
- ✅ Tested on multiple macOS versions
- ✅ No external dependencies required

## 📅 Timeline

- **Week 1**: Phases 1-3 (Bundle prep, integration, sandbox testing)
- **Week 2**: Phases 4-6 (Signing, integration testing, polish)
- **Week 3**: Final testing and release preparation

**Target Release**: v0.2.0 (April 2026)

## 🆘 Getting Help

### If you're stuck:

1. **Check Documentation**
   - Review the development plan
   - Read task tracking for context
   - Check troubleshooting section

2. **Review Code**
   - Look at existing GPGService implementation
   - Check MoaiySandboxTest for examples
   - Review test cases

3. **Test Incrementally**
   - Make small changes
   - Test frequently
   - Document issues

4. **Ask for Help**
   - Create GitHub issue
   - Document the problem
   - Include logs and screenshots

## 🎉 Next Steps

1. **Read the development plan** (`doc/bundled-gpg-development-plan.md`)
2. **Review task tracking** (`doc/bundled-gpg-task-tracking.md`)
3. **Start Phase 1** - Enhance the packaging script
4. **Run verification** to ensure bundle is correct
5. **Update task tracking** as you progress

Good luck! 🚀

---

**Questions?** Check the documentation or create an issue on GitHub.
