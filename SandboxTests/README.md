# Sandbox Tests

macOS App Sandbox compatibility tests for Moaiy.

## Purpose

Verify GPG functionality in sandboxed environment before starting development.

## Quick Start

1. **Create Xcode Project**
   ```
   - Open Xcode
   - File → New → Project
   - macOS → App
   - Interface: SwiftUI
   - Language: Swift
   ```

2. **Enable App Sandbox**
   ```
   - Select project target
   - Signing & Capabilities → + Capability → App Sandbox
   - Add required entitlements (see below)
   ```

3. **Add Test Code**
   - Copy `SandboxTestRunner.swift` to your project
   - Run tests in simulator or real device

## Required Entitlements

```xml
<!-- App Sandbox -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- Network access (for key servers) -->
<key>com.apple.security.network.client</key>
<true/>

<!-- File access (user authorized) -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Downloads folder access -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>
```

## Test Cases

### Test 1: System GPG Call (Expected to FAIL)
Verifies that sandbox blocks system GPG access.

### Test 2: Bundled GPG Call (Expected to PASS)
Verifies that bundled GPG can be executed.

### Test 3: File Access Without Auth (Expected to FAIL)
Verifies that sandbox blocks unauthorized file access.

### Test 4: File Access With Auth (Expected to PASS)
Verifies that NSOpenPanel authorization works.

### Test 5: Security-Scoped Bookmarks (Expected to PASS)
Verifies that file access can be persisted via bookmarks.

### Test 6: GPG Encryption/Decryption (Critical Test)
Verifies complete encryption workflow.

### Test 7: Container Directory Access (Expected to PASS)
Verifies unrestricted access to app container.

### Test 8: Network Access (Expected to PASS)
Verifies network access for key servers.

## Running Tests

```bash
# In Xcode
⌘ + R  # Run app
# Tests will execute automatically and print results to console

# Check console output for test results
```

## Expected Results

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| 1. System GPG | ❌ FAIL | - | ⏳ |
| 2. Bundled GPG | ✅ PASS | - | ⏳ |
| 3. File No Auth | ❌ FAIL | - | ⏳ |
| 4. File With Auth | ✅ PASS | - | ⏳ |
| 5. Bookmarks | ✅ PASS | - | ⏳ |
| 6. Encryption | ✅ PASS | - | ⏳ |
| 7. Container | ✅ PASS | - | ⏳ |
| 8. Network | ✅ PASS | - | ⏳ |

## Next Steps

After completing tests:
1. Document results in `/doc/sandbox-test-results.md`
2. Update technical architecture if needed
3. Decide on final approach (sandbox vs non-sandbox)

## Notes

- Tests require real macOS environment (not simulator for some tests)
- User interaction needed for file authorization tests
- Network tests require internet connection

---

*Created: 2026-03-16*
