# macOS Sandbox Compatibility Test Plan

> Purpose: Validate that Moaiy encryption workflows operate correctly under App Sandbox constraints.
> Updated: 2026-04-05

## 1. Objectives

### Primary objectives
1. Verify bundled crypto runtime execution inside sandbox.
2. Verify user-authorized file access behavior.
3. Verify bookmark-based persistent access behavior.
4. Identify blocking constraints before release.

### Success criteria
- Core encrypt/decrypt flows pass under sandbox.
- File access succeeds only through authorized paths.
- Permission failures are user-actionable and recoverable.
- Required entitlements are minimal and justified.

## 2. Sandbox Constraint Summary

| Constraint Type | Restriction | Product Impact |
| --- | --- | --- |
| File system | Access limited without explicit user grant | Import/export and file crypto flows |
| Process execution | Only approved executable paths in app context | Bundled runtime strategy required |
| Network | Outbound behavior gated by entitlement/policy | Keyserver and update-adjacent flows |
| Hardware | Additional controls for external tokens | Pro hardware key scope |

## 3. Strategy Options

### Option A: No sandbox (not App Store compatible)
- Pros: easiest technically
- Cons: not acceptable for App Store
- Use case: local diagnostics only

### Option B: Sandbox + user authorization (recommended baseline)
- Pros: review-compatible, predictable permission model
- Cons: user prompts are required for external paths

### Option C: Sandbox + bundled runtime (recommended)
- Pros: self-contained, no system dependency drift
- Cons: requires bundle integrity validation in CI/release

## 4. Test Environment

### Required matrix
- macOS latest stable (Apple Silicon)
- macOS latest stable (Intel, if available)
- Clean user profile (no pre-granted permissions)

### Build profiles
- Debug sandbox profile
- Release sandbox profile

## 5. Test Cases

## 5.1 Runtime execution in sandbox
- Goal: ensure bundled runtime launches and returns expected output.
- Steps:
  1. Launch app under sandbox.
  2. Trigger an operation that requires runtime invocation.
  3. Capture success/failure state and error output.
- Expected:
  - Bundled runtime path works.
  - System runtime assumptions are not required.

## 5.2 File access without authorization
- Goal: confirm unauthorized path access fails safely.
- Steps:
  1. Attempt operation on non-authorized external path.
- Expected:
  - Operation fails.
  - User-facing guidance explains re-authorization path.

## 5.3 File access with explicit authorization
- Goal: confirm authorized path behavior.
- Steps:
  1. Use `NSOpenPanel` / `NSSavePanel` to select files/dirs.
  2. Re-run import/export/encrypt/decrypt operations.
- Expected:
  - Operation succeeds.
  - No hidden privilege escalation.

## 5.4 Security-scoped bookmark lifecycle
- Goal: ensure persistence and rehydration work.
- Steps:
  1. Save bookmark for authorized directory.
  2. Restart app and resolve bookmark.
  3. Retry operation.
- Expected:
  - Access is restored when bookmark is valid.
  - Expired/invalid bookmark produces actionable recovery UX.

## 5.5 End-to-end file encryption/decryption
- Goal: validate core user flow in sandbox.
- Steps:
  1. Choose plaintext file via user grant.
  2. Encrypt with selected key.
  3. Decrypt generated output.
  4. Verify content equality.
- Expected:
  - Roundtrip succeeds.
  - No unauthorized path write/read attempts.

## 5.6 Container directory behavior
- Goal: verify app container usage for internal temp/cache paths.
- Expected:
  - Internal operations in container always succeed.
  - Cleanup semantics are stable.

## 5.7 Network behavior (if enabled)
- Goal: validate keyserver or other network-dependent flows.
- Expected:
  - Works only where intended.
  - Failure mode is clear when unavailable.

## 5.8 Hardware-key access (Pro, optional)
- Goal: validate behavior with required permissions and supported hardware.
- Expected:
  - Explicit opt-in path.
  - Clear unsupported-device/error behavior.

## 6. Entitlement Profiles

### Baseline profile (recommended)
- App Sandbox enabled
- Only required file/network entitlements
- No unnecessary temporary exceptions

### Extended profile (Pro/hardware scope)
- Add only hardware-related capabilities required by validated workflows
- Maintain strict review documentation for each capability

## 7. Execution Plan

### Phase 1: Fast baseline pass
- Runtime invocation
- Unauthorized vs authorized file access
- Core file roundtrip

### Phase 2: Persistence and failure recovery
- Bookmark lifecycle
- Permission-loss recovery
- Restart resilience

### Phase 3: Release hardening
- Repeat key flows in Release config
- Record evidence artifacts for release checklist

## 8. Evidence to Capture

- Build configuration and commit/tag
- OS version, architecture
- Test case result matrix
- Logs/screenshots for any failure
- Reproduction steps for blockers

## 9. Result Template

| Case ID | Scenario | Expected | Actual | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| SB-01 | Bundled runtime execution | Pass |  |  |  |
| SB-02 | Unauthorized external file access | Fail with guidance |  |  |  |
| SB-03 | Authorized file access | Pass |  |  |  |
| SB-04 | Bookmark restore after restart | Pass |  |  |  |
| SB-05 | Encrypt/decrypt roundtrip | Pass |  |  |  |
| SB-06 | Container path behavior | Pass |  |  |  |
| SB-07 | Network flow (if enabled) | Pass/Graceful fail |  |  |  |
| SB-08 | Hardware key flow (optional) | Pass/Graceful fail |  |  |  |

## 10. Risk Register

### High priority
- Runtime launch failure inside sandbox
- Broken bookmark restore behavior
- Permission dead-end UX

### Medium priority
- Release-vs-Debug entitlement drift
- Non-deterministic file operation outcomes

### Low priority
- Cosmetic messaging inconsistency in edge-case errors

## 11. Exit Criteria

All of the following must hold:
- No open blockers on SB-01/SB-03/SB-05.
- User recovery path exists for all expected permission failures.
- Entitlements are reviewed and documented.

---

Keep this plan versioned with release milestones. Update case IDs and expected behavior whenever sandbox-sensitive code paths change.
