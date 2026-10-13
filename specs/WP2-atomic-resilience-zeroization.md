# Work Package 2: Atomic Resilience & Memory Zeroization (v1.0 Spec)

## 1. Objective
Protect user privacy and cryptographic integrity by guaranteeing that:
1. Sensitive secrets (passphrases, temporary symmetric keys) are actively zeroized in memory upon scope exit.
2. Interrupted or terminated operations (cancellations, crashes, `NSApplication.willTerminateNotification`, signals) cleanly wipe any partially staged or transient plaintext files.

## 2. Invariants & Requirements
1. **Memory Zeroization**: Secret buffers must be cleansed using Darwin `memset_s` on deallocation, defeating compiler dead-code elimination.
2. **Crash & Termination Hook**: Active scratch files and directories must be registered in a centralized thread-safe registry (`TransientFileRegistry`), guaranteeing that termination triggers immediate cleanup.
3. **Defense Against Swap/Dumps**: Passphrase holders (`SecureBytes`) must keep heap footprint minimal and prevent long-lived plaintext memory residency.
4. **Non-blocking App Exit**: Termination cleanup routines must execute synchronously within 300ms without deadlock.

## 3. Architecture Blueprint
- **Component**: `SecureMemory` (`SecureBytes`, `SecureString`)
  - Internal byte buffer `[UInt8]` zeroized via `memset_s`.
- **Component**: `TransientFileRegistry`
  - Thread-safe tracking of active temporary directories and files.
  - Automatic hook into `NSApplication.willTerminateNotification`.
  - Signal-safe exit cleanup triggers.
- **Integration**:
  - `MoaiyApp` initializes `TransientFileRegistry.shared.setupLifecycleHooks()`.

## 4. Acceptance Criteria
- [ ] `SecureBytes` proves memory zeroing via test harness upon `deinit` or explicit `zeroize()`.
- [ ] Registered transient files are purged immediately upon termination trigger.
- [ ] Zeroization utilities conform to Swift Concurrency (`Sendable`).
- [ ] 100% test pass rate in `MoaiyTests`.
