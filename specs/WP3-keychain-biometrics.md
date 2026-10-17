# Work Package 3: Keychain Storage & Biometrics Integration (v1.0 Spec)

## 1. Objective
Enable seamless and secure passphrase management on macOS by integrating Apple Keychain Services and `LocalAuthentication` (`.userPresence`). Allow users to optionally store private key passphrases in the Keychain with hardware-backed access control, eliminating the friction of manual passphrase typing on every decryption operation.

## 2. Invariants & Requirements
1. **Hardware-Backed Access Control**: Passphrases stored in Keychain can be bound to `.userPresence`, delegating authentication to Touch ID, Apple Watch, or device passcode fallback.
2. **Memory Safety**: Passphrases retrieved from the Keychain are encapsulated inside `SecureString` / `SecureBytes`, providing best-effort internal buffer clearing via `memset_s` upon deallocation.
3. **Isolated Service Domain**: Keychain entries are scoped to `com.moaiy.app.passphrase` and keyed by normalized key fingerprints (removing leading 0x prefixes and trimming whitespace).
4. **Idempotent Updates**: Use add-then-update logic (`SecItemAdd` with fallback to `SecItemUpdate` and delete+add fallback) to avoid losing stored credentials on access control mutations.
5. **Non-blocking Threading**: Blocking Keychain queries (`SecItemCopyMatching`) must execute on background queues (`DispatchQueue.global`) to prevent freezing the MainActor or SwiftUI UI during biometric evaluation.
6. **Error Distinction**: Explicitly distinguish between item not found, user cancellation, and authentication failures.

## 3. Architecture Blueprint
- **Component**: `KeychainService`
  - Protocols: `KeychainManaging`
  - Methods:
    - `savePassphrase(_:for:requireBiometrics:) throws`
    - `retrievePassphrase(for:contextReason:) async throws -> SecureString?`
    - `deletePassphrase(for:) throws`
    - `isPassphraseStored(for:) -> Bool`
    - `isBiometricsAvailable() -> Bool`

## 4. Acceptance Criteria
- [x] Passphrase normalization and idempotent add-then-update logic implemented.
- [x] Background thread dispatch prevents main thread blocking during biometric evaluation.
- [x] Distinct error mapping for user cancellation and auth failures.
- [ ] Physical Touch ID prompt verified on interactive Apple Silicon hardware.
