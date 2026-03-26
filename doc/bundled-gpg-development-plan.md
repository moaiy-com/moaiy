# Built-in GPG Feature Development Plan

> **Feature Branch**: `feature/bundled-gpg`
> **Created**: 2026-03-26
> **Target**: v0.2.0
> **Priority**: High

---

## 1. Executive Summary

### Objective
Integrate a fully self-contained GPG executable into Moaiy app bundle to ensure:
- ✅ Zero external dependencies for end users
- ✅ App Store compliance (sandbox compatible)
- ✅ Consistent GPG version across all installations
- ✅ No requirement for users to install GPG separately

### Current Status
- ✅ GPG packaging script created (`fix_gpg_deps.sh`)
- ✅ Sandbox testing framework ready (`MoaiySandboxTest`)
- ✅ GPGService architecture supports both system and bundled GPG
- ⏳ Bundled GPG not yet integrated into main app
- ⏳ Release build sandbox testing not complete

### Success Criteria
1. GPG executable and all dependencies bundled in app
2. Works in strict sandbox environment (Release build)
3. Passes all existing tests with bundled GPG
4. Code signed and notarized successfully
5. App Store review approved

---

## 2. Technical Architecture

### 2.1 Bundle Structure

```
Moaiy.app/
└── Contents/
    └── Resources/
        └── gpg.bundle/
            ├── bin/
            │   ├── gpg              # Main executable
            │   ├── gpg-agent        # GPG agent (optional)
            │   └── gpgconf          # GPG config utility
            ├── lib/
            │   ├── libgcrypt.20.dylib
            │   ├── libgpg-error.0.dylib
            │   ├── libassuan.9.dylib
            │   ├── libksba.8.dylib
            │   ├── libnpth.0.dylib
            │   └── libncurses.6.dylib
            └── share/
                └── gnupg/           # GPG configuration files
```

### 2.2 GPGService Integration Strategy

```swift
// Priority order for GPG executable:
1. Bundled GPG (Production)
   - Path: Bundle.main.url(forResource: "gpg.bundle", withExtension: nil)
   - Executable: gpg.bundle/bin/gpg
   
2. System GPG (Development/Fallback)
   - Path: /opt/homebrew/bin/gpg (Apple Silicon)
   - Path: /usr/local/bin/gpg (Intel)
   
3. Environment Setup:
   - GNUPGHOME: App container directory
   - DYLD_LIBRARY_PATH: gpg.bundle/lib
```

### 2.3 Dynamic Library Loading

**Challenge**: macOS sandbox restricts dynamic library loading

**Solution**:
1. Use `@executable_path` relative paths
2. Modify library install names with `install_name_tool`
3. Re-sign all binaries after modification
4. Test in sandbox environment

---

## 3. Development Phases

### Phase 1: GPG Bundle Preparation (2-3 days)

#### 1.1 Automate GPG Bundle Creation
**Tasks**:
- [ ] Enhance `fix_gpg_deps.sh` script
  - Support both Intel and Apple Silicon architectures
  - Add error handling and validation
  - Create universal binary support
  - Generate manifest file with checksums
  
- [ ] Create `scripts/prepare_gpg_bundle.sh`
  ```bash
  #!/bin/bash
  # Downloads GPG from Homebrew
  # Packages all dependencies
  # Signs all binaries
  # Creates gpg.bundle directory
  ```

- [ ] Add version detection
  ```bash
  # Extract GPG version
  # Store in manifest.json
  # Validate compatibility
  ```

**Deliverables**:
- ✅ Automated GPG bundle creation script
- ✅ `gpg.bundle/` directory with all dependencies
- ✅ `manifest.json` with version info

#### 1.2 Verify Bundle Integrity
**Tasks**:
- [ ] Test bundle on clean macOS system
- [ ] Verify all dependencies are included
- [ ] Check library paths are correct
- [ ] Test code signatures

**Testing**:
```bash
# Run bundle verification
./scripts/verify_gpg_bundle.sh

# Expected output:
# ✅ gpg executable found
# ✅ All 6 libraries present
# ✅ All library paths correct
# ✅ All binaries signed
# ✅ GPG version: 2.5.18
```

---

### Phase 2: Xcode Project Integration (1-2 days)

#### 2.1 Add Bundle to Xcode Project
**Tasks**:
- [ ] Add `gpg.bundle` to Xcode project
  ```bash
  # Copy bundle to Moaiy/Resources/
  cp -r gpg.bundle Moaiy/Resources/
  
  # Add to Xcode project
  # Build Phases → Copy Bundle Resources
  ```

- [ ] Configure build settings
  - Ensure bundle is copied to `Contents/Resources/`
  - Set proper permissions
  - Configure code signing

- [ ] Update `.gitignore`
  ```
  # Don't commit the large bundle
  Moaiy/Resources/gpg.bundle/
  ```

**Deliverables**:
- ✅ Bundle integrated in Xcode project
- ✅ Bundle appears in built app
- ✅ Build succeeds in Debug and Release

#### 2.2 Update GPGService.swift
**Tasks**:
- [ ] Enhance `findGPGExecutable()` method
  ```swift
  private func findGPGExecutable() throws {
      // 1. Try bundled GPG first
      if let bundleURL = Bundle.main.url(
          forResource: "gpg.bundle", 
          withExtension: nil
      ) {
          let executableURL = bundleURL
              .appendingPathComponent("bin/gpg")
          
          if FileManager.default.fileExists(
              atPath: executableURL.path
          ) {
              gpgURL = executableURL
              logger.info("Using bundled GPG: \(executableURL.path)")
              return
          }
      }
      
      // 2. Fallback to system GPG (development)
      // ... existing code ...
  }
  ```

- [ ] Add bundle validation
  ```swift
  private func validateGPGBundle() -> Bool {
      guard let bundleURL = Bundle.main.url(
          forResource: "gpg.bundle",
          withExtension: nil
      ) else {
          return false
      }
      
      // Check executable
      let gpgURL = bundleURL.appendingPathComponent("bin/gpg")
      guard FileManager.default.isExecutableFile(atPath: gpgURL.path) else {
          return false
      }
      
      // Check libraries
      let libURL = bundleURL.appendingPathComponent("lib")
      // ... validate libraries ...
      
      return true
  }
  ```

- [ ] Add diagnostic logging
  ```swift
  private func logGPGEnvironment() {
      logger.info("GPG Path: \(gpgURL?.path ?? "nil")")
      logger.info("GPG Home: \(gpgHome?.path ?? "nil")")
      logger.info("Bundle Valid: \(validateGPGBundle())")
      
      if let version = gpgVersion {
          logger.info("GPG Version: \(version)")
      }
  }
  ```

**Deliverables**:
- ✅ GPGService uses bundled GPG
- ✅ Fallback to system GPG in development
- ✅ Proper error handling and logging

---

### Phase 3: Sandbox Testing (2-3 days)

#### 3.1 Create Comprehensive Test Suite
**Tasks**:
- [ ] Create `MoaiySandboxTests/BundledGPGTests.swift`
  ```swift
  @Test("Bundled GPG exists")
  func bundledGPGExists() async throws {
      guard let bundleURL = Bundle.main.url(
          forResource: "gpg.bundle",
          withExtension: nil
      ) else {
          Issue.record("gpg.bundle not found")
          return
      }
      
      let gpgURL = bundleURL.appendingPathComponent("bin/gpg")
      #expect(FileManager.default.fileExists(atPath: gpgURL.path))
  }
  
  @Test("Bundled GPG executes in sandbox")
  func bundledGPGExecutes() async throws {
      let service = GPGService.shared
      #expect(service.isReady)
      #expect(service.gpgVersion != nil)
  }
  
  @Test("Key operations work in sandbox")
  func keyOperationsWork() async throws {
      let service = GPGService.shared
      
      // Generate test key
      let fingerprint = try await service.generateKey(
          name: "Test User",
          email: "test@example.com",
          keyType: .rsa2048,
          passphrase: "test123"
      )
      
      #expect(fingerprint.count == 40)
      
      // List keys
      let keys = try await service.listKeys()
      #expect(keys.contains { $0.fingerprint == fingerprint })
  }
  ```

- [ ] Test all GPG operations
  - [ ] Key generation (RSA, ECC)
  - [ ] Key listing
  - [ ] Key import/export
  - [ ] Text encryption/decryption
  - [ ] File encryption/decryption
  - [ ] Signing and verification
  - [ ] Trust management

**Deliverables**:
- ✅ Comprehensive sandbox test suite
- ✅ All tests pass in Debug mode
- ✅ All tests pass in Release mode

#### 3.2 Test in Strict Sandbox
**Tasks**:
- [ ] Configure strict sandbox entitlements
  ```xml
  <!-- Entitlements-Release.entitlements -->
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
  <key>com.apple.security.get-task-allow</key>
  <false/>
  ```

- [ ] Test Release build
  ```bash
  # Build Release version
  xcodebuild -project Moaiy.xcodeproj \
             -scheme Moaiy \
             -configuration Release \
             clean build
  
  # Run tests
  xcodebuild test -project Moaiy.xcodeproj \
                  -scheme Moaiy \
                  -configuration Release
  ```

- [ ] Test on clean macOS VM
  - No GPG installed
  - No Homebrew
  - Strict sandbox enabled

**Deliverables**:
- ✅ Release build works in sandbox
- ✅ Works on system without GPG
- ✅ No permission errors

---

### Phase 4: Code Signing & Notarization (1-2 days)

#### 4.1 Code Signing
**Tasks**:
- [ ] Sign all binaries in bundle
  ```bash
  #!/bin/bash
  # scripts/sign_gpg_bundle.sh
  
  IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
  BUNDLE_PATH="Moaiy/Resources/gpg.bundle"
  
  # Sign libraries
  for lib in "$BUNDLE_PATH/lib/"*.dylib; do
      codesign --force --sign "$IDENTITY" "$lib"
  done
  
  # Sign executables
  for bin in "$BUNDLE_PATH/bin/"*; do
      codesign --force --sign "$IDENTITY" "$bin"
  done
  
  # Sign bundle
  codesign --force --sign "$IDENTITY" "$BUNDLE_PATH"
  ```

- [ ] Verify signatures
  ```bash
  # Verify all signatures
  codesign --verify --deep --strict Moaiy.app
  spctl --assess --verbose=4 Moaiy.app
  ```

**Deliverables**:
- ✅ All binaries properly signed
- ✅ Signature verification passes

#### 4.2 Notarization
**Tasks**:
- [ ] Create notarization script
  ```bash
  #!/bin/bash
  # scripts/notarize_app.sh
  
  # Create ZIP
  ditto -c -k --keepParent Moaiy.app Moaiy.zip
  
  # Submit for notarization
  xcrun notarytool submit Moaiy.zip \
      --apple-id "your@email.com" \
      --team-id "TEAM_ID" \
      --password "@keychain:AC_PASSWORD" \
      --wait
  
  # Staple ticket
  xcrun stapler staple Moaiy.app
  ```

- [ ] Test notarized app
  - Download on different Mac
  - Verify Gatekeeper accepts it
  - Test all functionality

**Deliverables**:
- ✅ App notarized successfully
- ✅ Gatekeeper accepts app
- ✅ Works on other Macs

---

### Phase 5: Integration Testing (2-3 days)

#### 5.1 End-to-End Testing
**Tasks**:
- [ ] Test complete user flows
  1. Fresh install (no GPG)
  2. Generate key pair
  3. Encrypt/decrypt text
  4. Encrypt/decrypt file
  5. Import/export keys
  6. Trust management

- [ ] Performance testing
  - Key generation time
  - Encryption speed
  - Memory usage
  - App launch time

- [ ] Stress testing
  - Large files (1GB+)
  - Many keys (100+)
  - Long-running operations

**Deliverables**:
- ✅ All user flows work correctly
- ✅ Performance is acceptable
- ✅ No crashes or memory leaks

#### 5.2 Compatibility Testing
**Tasks**:
- [ ] Test on different macOS versions
  - macOS 12 Monterey
  - macOS 13 Ventura
  - macOS 14 Sonoma
  - macOS 15 Sequoia

- [ ] Test on different architectures
  - Intel Mac (x86_64)
  - Apple Silicon (M1/M2/M3)

- [ ] Test with existing GPG installations
  - Homebrew GPG installed
  - GPG Suite installed
  - No conflicts

**Deliverables**:
- ✅ Works on all supported macOS versions
- ✅ Works on both architectures
- ✅ No conflicts with system GPG

---

### Phase 6: Documentation & Polish (1-2 days)

#### 6.1 Update Documentation
**Tasks**:
- [ ] Update README.md
  ```markdown
  ## Installation
  
  Moaiy is fully self-contained. No external dependencies required.
  
  - GPG is bundled with the app
  - Works in sandbox environment
  - App Store ready
  ```

- [ ] Create `BUNDLED_GPG.md`
  - Technical details
  - How bundled GPG works
  - Troubleshooting guide

- [ ] Update CHANGELOG.md
  ```markdown
  ## v0.2.0 - 2026-04-XX
  
  ### Added
  - Bundled GPG executable (no external dependencies)
  - Automatic GPG home directory setup
  - Enhanced error messages
  ```

- [ ] Update AGENTS.md
  - Add bundled GPG guidelines
  - Update development instructions

**Deliverables**:
- ✅ All documentation updated
- ✅ User guide reflects bundled GPG
- ✅ Developer guide updated

#### 6.2 Final Polish
**Tasks**:
- [ ] Review all code changes
- [ ] Remove debug logging
- [ ] Optimize bundle size
- [ ] Add version info to UI
- [ ] Update app icon if needed

**Deliverables**:
- ✅ Code reviewed and clean
- ✅ Bundle size optimized
- ✅ UI polished

---

## 4. Risk Assessment

### 4.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Dynamic library loading fails in sandbox | Medium | High | Thorough sandbox testing, use @executable_path |
| Code signing breaks library paths | Medium | High | Re-sign after each modification |
| GPG version incompatibility | Low | Medium | Pin specific GPG version, test thoroughly |
| Bundle size too large | Low | Low | Strip debug symbols, compress |
| Performance degradation | Low | Medium | Profile and optimize |

### 4.2 Process Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| App Store rejection | Medium | High | Follow guidelines strictly, test notarization |
| Sandbox restrictions change | Low | Medium | Stay updated with Apple guidelines |
| GPG license issues | Low | High | Verify GPL compliance |

### 4.3 Contingency Plans

**Plan A**: Full bundled GPG (primary)
**Plan B**: Hybrid approach (bundled + system fallback)
**Plan C**: External helper app (if sandbox issues)

---

## 5. Testing Strategy

### 5.1 Unit Tests
- GPGService with mocked bundle
- Path resolution logic
- Error handling

### 5.2 Integration Tests
- Real GPG operations in sandbox
- Key generation and management
- Encryption/decryption

### 5.3 UI Tests
- Complete user flows
- Error scenarios
- Performance tests

### 5.4 Manual Tests
- Fresh macOS install
- Different architectures
- Various macOS versions

---

## 6. Timeline & Milestones

### Week 1: Preparation & Integration
- **Day 1-2**: Phase 1 - GPG Bundle Preparation
- **Day 3**: Phase 2 - Xcode Project Integration
- **Day 4-5**: Phase 3 - Initial Sandbox Testing

### Week 2: Testing & Polish
- **Day 1-2**: Phase 3 - Complete Sandbox Testing
- **Day 3**: Phase 4 - Code Signing & Notarization
- **Day 4-5**: Phase 5 - Integration Testing

### Week 3: Final Polish & Release
- **Day 1-2**: Phase 6 - Documentation & Polish
- **Day 3**: Final testing and bug fixes
- **Day 4-5**: Release preparation

**Total Duration**: 12-15 working days

---

## 7. Success Metrics

### Technical Metrics
- ✅ Bundle size < 20MB
- ✅ App launch time < 2s
- ✅ Key generation < 5s (RSA-2048)
- ✅ Encryption speed > 10MB/s
- ✅ Memory usage < 100MB idle
- ✅ Zero crashes in testing

### Quality Metrics
- ✅ Test coverage > 85%
- ✅ All sandbox tests pass
- ✅ Notarization successful
- ✅ App Store review approved
- ✅ Zero critical bugs

### User Experience Metrics
- ✅ Works on clean macOS
- ✅ No external dependencies
- ✅ Clear error messages
- ✅ Consistent performance

---

## 8. Rollout Plan

### 8.1 Internal Testing (Week 3)
- Deploy to team members
- Collect feedback
- Fix critical issues

### 8.2 Beta Testing (Week 4)
- Release to TestFlight (if applicable)
- Or distribute DMG to beta users
- Monitor for issues

### 8.3 Production Release (Week 5)
- Submit to App Store
- Update website/documentation
- Announce release

---

## 9. Maintenance Plan

### 9.1 GPG Updates
- Monitor GPG releases
- Update bundle quarterly
- Test compatibility

### 9.2 Security Updates
- Monitor security advisories
- Update dependencies promptly
- Re-notarize as needed

### 9.3 Compatibility Updates
- Test on new macOS versions
- Update for new architectures
- Maintain backward compatibility

---

## 10. Resources

### Documentation
- [GPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [Apple Sandbox Guide](https://developer.apple.com/documentation/security/app_sandbox)
- [Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### Tools
- `fix_gpg_deps.sh` - GPG packaging script
- `scripts/verify_gpg_bundle.sh` - Bundle verification
- `scripts/sign_gpg_bundle.sh` - Code signing
- `scripts/notarize_app.sh` - Notarization

### Related Files
- `Moaiy/Services/GPGService.swift`
- `Moaiy/Resources/Entitlements.entitlements`
- `doc/technical-validation-status.md`
- `doc/sandbox-testing-plan.md`

---

## 11. Next Steps

### Immediate Actions (This Week)
1. ✅ Create feature branch `feature/bundled-gpg`
2. [ ] Enhance `fix_gpg_deps.sh` script
3. [ ] Create GPG bundle for testing
4. [ ] Add bundle to Xcode project
5. [ ] Update GPGService.swift

### This Month
- Complete Phases 1-3
- Initial sandbox testing
- Basic functionality working

### Next Month
- Complete Phases 4-6
- App Store submission
- Release v0.2.0

---

**Status**: Ready to begin Phase 1
**Next Review**: End of Week 1
**Target Release**: v0.2.0 (April 2026)
