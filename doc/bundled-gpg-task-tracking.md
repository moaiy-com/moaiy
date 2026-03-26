# Bundled GPG Feature - Task Tracking

> **Branch**: `feature/bundled-gpg`
> **Started**: 2026-03-26
> **Last Updated**: 2026-03-26

---

## Progress Overview

```
Phase 1: ████████░░░░░░░░░░░░ 40% - GPG Bundle Preparation
Phase 2: ░░░░░░░░░░░░░░░░░░░░  0% - Xcode Project Integration
Phase 3: ░░░░░░░░░░░░░░░░░░░░  0% - Sandbox Testing
Phase 4: ░░░░░░░░░░░░░░░░░░░░  0% - Code Signing & Notarization
Phase 5: ░░░░░░░░░░░░░░░░░░░░  0% - Integration Testing
Phase 6: ░░░░░░░░░░░░░░░░░░░░  0% - Documentation & Polish

Overall: ██░░░░░░░░░░░░░░░░░░ 10%
```

---

## Phase 1: GPG Bundle Preparation (Week 1, Days 1-2)

### 1.1 Automate GPG Bundle Creation
- [ ] Enhance `fix_gpg_deps.sh` script
  - [ ] Support both Intel and Apple Silicon architectures
  - [ ] Add error handling and validation
  - [ ] Create universal binary support
  - [ ] Generate manifest file with checksums
  - [ ] Add verbose logging option

- [ ] Create `scripts/prepare_gpg_bundle.sh`
  - [ ] Download GPG from Homebrew
  - [ ] Package all dependencies
  - [ ] Sign all binaries
  - [ ] Create gpg.bundle directory
  - [ ] Generate manifest.json

- [ ] Add version detection
  - [ ] Extract GPG version
  - [ ] Store in manifest.json
  - [ ] Validate compatibility
  - [ ] Log version info

**Status**: 🟡 In Progress
**Blockers**: None
**ETA**: 2026-03-27

### 1.2 Verify Bundle Integrity
- [ ] Create `scripts/verify_gpg_bundle.sh`
  - [ ] Check gpg executable exists
  - [ ] Verify all libraries present
  - [ ] Validate library paths
  - [ ] Check code signatures
  - [ ] Test GPG execution

- [ ] Test bundle on clean macOS system
  - [ ] Create test VM or use clean Mac
  - [ ] Copy bundle to test system
  - [ ] Execute verification script
  - [ ] Document results

**Status**: 🔴 Not Started
**Blockers**: None
**ETA**: 2026-03-27

---

## Phase 2: Xcode Project Integration (Week 1, Day 3)

### 2.1 Add Bundle to Xcode Project
- [ ] Copy bundle to `Moaiy/Resources/`
  ```bash
  cp -r gpg.bundle Moaiy/Resources/
  ```

- [ ] Add to Xcode project
  - [ ] Open Moaiy.xcodeproj
  - [ ] Add gpg.bundle to project
  - [ ] Configure Build Phases → Copy Bundle Resources
  - [ ] Set proper permissions
  - [ ] Configure code signing

- [ ] Update `.gitignore`
  - [ ] Add `Moaiy/Resources/gpg.bundle/`
  - [ ] Add `*.dmg`
  - [ ] Add build artifacts

- [ ] Test build
  - [ ] Build Debug configuration
  - [ ] Build Release configuration
  - [ ] Verify bundle in app package
  - [ ] Check bundle permissions

**Status**: 🔴 Not Started
**Blockers**: Phase 1 completion
**ETA**: 2026-03-28

### 2.2 Update GPGService.swift
- [ ] Enhance `findGPGExecutable()` method
  - [ ] Try bundled GPG first
  - [ ] Fallback to system GPG
  - [ ] Add proper error handling
  - [ ] Add logging

- [ ] Add bundle validation
  - [ ] Check bundle exists
  - [ ] Verify executable
  - [ ] Validate libraries
  - [ ] Check signatures

- [ ] Add diagnostic logging
  - [ ] Log GPG path
  - [ ] Log GPG home
  - [ ] Log bundle validation status
  - [ ] Log GPG version

- [ ] Update tests
  - [ ] Add bundled GPG tests
  - [ ] Mock bundle for unit tests
  - [ ] Test fallback behavior

**Status**: 🔴 Not Started
**Blockers**: Phase 1 completion
**ETA**: 2026-03-28

---

## Phase 3: Sandbox Testing (Week 1, Days 4-5)

### 3.1 Create Comprehensive Test Suite
- [ ] Create `MoaiyTests/BundledGPGTests.swift`
  - [ ] Test bundle exists
  - [ ] Test bundle structure
  - [ ] Test executable permissions
  - [ ] Test library loading

- [ ] Test GPG operations
  - [ ] Key generation (RSA, ECC)
  - [ ] Key listing
  - [ ] Key import/export
  - [ ] Text encryption/decryption
  - [ ] File encryption/decryption
  - [ ] Signing and verification
  - [ ] Trust management

- [ ] Test error scenarios
  - [ ] Invalid bundle
  - [ ] Missing libraries
  - [ ] Permission errors
  - [ ] Invalid operations

**Status**: 🔴 Not Started
**Blockers**: Phase 2 completion
**ETA**: 2026-03-29

### 3.2 Test in Strict Sandbox
- [ ] Configure Release entitlements
  ```xml
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
  <key>com.apple.security.get-task-allow</key>
  <false/>
  ```

- [ ] Build and test Release version
  - [ ] Clean build
  - [ ] Run all tests
  - [ ] Check console logs
  - [ ] Document results

- [ ] Test on clean macOS VM
  - [ ] Create macOS VM
  - [ ] Install no additional software
  - [ ] Copy app to VM
  - [ ] Test all functionality
  - [ ] Document results

**Status**: 🔴 Not Started
**Blockers**: Phase 3.1 completion
**ETA**: 2026-03-30

---

## Phase 4: Code Signing & Notarization (Week 2, Days 1-2)

### 4.1 Code Signing
- [ ] Create `scripts/sign_gpg_bundle.sh`
  - [ ] Sign all libraries
  - [ ] Sign all executables
  - [ ] Sign bundle directory
  - [ ] Verify signatures

- [ ] Update build process
  - [ ] Add signing step to Build Phases
  - [ ] Configure signing identity
  - [ ] Test automated signing

- [ ] Verify signatures
  - [ ] Run `codesign --verify`
  - [ ] Run `spctl --assess`
  - [ ] Check signature validity
  - [ ] Document results

**Status**: 🔴 Not Started
**Blockers**: Phase 3 completion
**ETA**: 2026-03-31

### 4.2 Notarization
- [ ] Create `scripts/notarize_app.sh`
  - [ ] Create ZIP archive
  - [ ] Submit for notarization
  - [ ] Wait for approval
  - [ ] Staple ticket

- [ ] Test notarized app
  - [ ] Download on different Mac
  - [ ] Verify Gatekeeper accepts
  - [ ] Test all functionality
  - [ ] Document results

- [ ] Handle notarization issues
  - [ ] Review logs
  - [ ] Fix issues
  - [ ] Resubmit if needed

**Status**: 🔴 Not Started
**Blockers**: Phase 4.1 completion
**ETA**: 2026-04-01

---

## Phase 5: Integration Testing (Week 2, Days 3-4)

### 5.1 End-to-End Testing
- [ ] Test complete user flows
  - [ ] Fresh install scenario
  - [ ] Generate key pair
  - [ ] Encrypt/decrypt text
  - [ ] Encrypt/decrypt file
  - [ ] Import/export keys
  - [ ] Trust management
  - [ ] Settings configuration

- [ ] Performance testing
  - [ ] Measure key generation time
  - [ ] Measure encryption speed
  - [ ] Check memory usage
  - [ ] Measure app launch time
  - [ ] Profile with Instruments

- [ ] Stress testing
  - [ ] Large files (1GB+)
  - [ ] Many keys (100+)
  - [ ] Long-running operations
  - [ ] Memory pressure
  - [ ] CPU usage

**Status**: 🔴 Not Started
**Blockers**: Phase 4 completion
**ETA**: 2026-04-02

### 5.2 Compatibility Testing
- [ ] Test on different macOS versions
  - [ ] macOS 12 Monterey
  - [ ] macOS 13 Ventura
  - [ ] macOS 14 Sonoma
  - [ ] macOS 15 Sequoia (if available)

- [ ] Test on different architectures
  - [ ] Intel Mac (x86_64)
  - [ ] Apple Silicon M1
  - [ ] Apple Silicon M2/M3 (if available)

- [ ] Test with existing GPG installations
  - [ ] Homebrew GPG installed
  - [ ] GPG Suite installed
  - [ ] No GPG installed
  - [ ] Multiple GPG versions

**Status**: 🔴 Not Started
**Blockers**: Phase 5.1 completion
**ETA**: 2026-04-03

---

## Phase 6: Documentation & Polish (Week 2, Days 5 + Week 3)

### 6.1 Update Documentation
- [ ] Update `README.md`
  - [ ] Update installation instructions
  - [ ] Remove external dependency mentions
  - [ ] Add bundled GPG info
  - [ ] Update screenshots if needed

- [ ] Create `BUNDLED_GPG.md`
  - [ ] Explain bundled GPG architecture
  - [ ] Technical details
  - [ ] How it works
  - [ ] Troubleshooting guide

- [ ] Update `CHANGELOG.md`
  - [ ] Add v0.2.0 entry
  - [ ] List new features
  - [ ] List changes
  - [ ] List fixes

- [ ] Update `AGENTS.md`
  - [ ] Add bundled GPG guidelines
  - [ ] Update development setup
  - [ ] Add testing instructions

**Status**: 🔴 Not Started
**Blockers**: Phase 5 completion
**ETA**: 2026-04-04

### 6.2 Final Polish
- [ ] Review all code changes
  - [ ] Code review checklist
  - [ ] Remove debug code
  - [ ] Optimize performance
  - [ ] Check error handling

- [ ] Optimize bundle size
  - [ ] Strip debug symbols
  - [ ] Remove unnecessary files
  - [ ] Compress if needed
  - [ ] Target: < 20MB

- [ ] UI polish
  - [ ] Add version info to About
  - [ ] Update app icon if needed
  - [ ] Polish error messages
  - [ ] Review accessibility

**Status**: 🔴 Not Started
**Blockers**: Phase 6.1 completion
**ETA**: 2026-04-05

---

## Blockers & Issues

### Current Blockers
*None at this time*

### Open Issues
1. **Bundle Size**: Need to verify final bundle size is acceptable (< 20MB)
2. **Universal Binary**: Need to decide if we support both architectures or create separate builds
3. **GPG Updates**: Need process for updating bundled GPG when new versions released

### Resolved Issues
*None yet*

---

## Testing Results

### Phase 1 Tests
*Pending*

### Phase 2 Tests
*Pending*

### Phase 3 Tests
*Pending*

### Phase 4 Tests
*Pending*

### Phase 5 Tests
*Pending*

---

## Metrics

### Bundle Metrics
- Bundle size: TBD
- Number of files: TBD
- Number of libraries: TBD

### Performance Metrics
- App launch time: TBD
- Key generation time: TBD
- Encryption speed: TBD
- Memory usage: TBD

### Quality Metrics
- Test coverage: TBD
- Number of tests: TBD
- Bug count: TBD

---

## Notes & Decisions

### Architecture Decisions
1. **Bundle Location**: `Moaiy.app/Contents/Resources/gpg.bundle/`
2. **GPG Priority**: Bundled GPG > System GPG (development fallback)
3. **Home Directory**: App container, not system ~/.gnupg

### Open Questions
1. Should we create universal binary or separate builds?
2. How to handle GPG agent for long-running operations?
3. Should we include gpgconf and other GPG utilities?

### Future Enhancements
1. Automatic GPG bundle updates
2. Hardware key support (Pro feature)
3. Multiple GPG versions support

---

**Next Review**: 2026-03-27 (End of Phase 1)
**Project Manager**: @codingchef
**Target Release**: v0.2.0 (April 2026)
