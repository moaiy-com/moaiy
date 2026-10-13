# Work Package 3: Keychain Storage & Biometrics Integration (v1.0 Spec)

## 1. Objective
Enable seamless and secure passphrase management on macOS by integrating the Apple Keychain Services API and `LocalAuthentication` (Touch ID / Apple Watch). Allow users to optionally store private key passphrases in the Keychain with hardware-backed access control, eliminating the friction of manual passphrase typing on every decryption operation.

## 2. Invariants & Requirements
1. **Hardware-Backed Access Control**: Passphrases stored in Keychain can be bound to `kSecAccessControlBiometryAny`, delegating authentication to the Secure Enclave and Touch ID.
2. **Memory Safety**: Passphrases retrieved from the Keychain must be wrapped inside `SecureString` / `SecureBytes` and wiped using `memset_s` immediately upon completion of the cryptographic operation.
3. **Isolated Service Domain**: Keychain entries must be scoped to the service domain `com.moaiy.app.passphrase` and keyed by normalized key fingerprints.
4. **Graceful Degradation**: If biometrics are unavailable (e.g., clamshell mode without external Touch ID, or Mac Pro without Touch ID), the system must fallback gracefully to device passcode or standard user input.
5. **Full User Opt-In/Opt-Out**: Users must have explicit control to inspect, save, and purge stored passphrases on a per-key basis.

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
- [ ] Storing, retrieving, and deleting passphrases succeeds against the Keychain mock/service.
- [ ] Passphrases retrieved are encapsulated in zeroized `SecureString` structures.
- [ ] Touch ID / passcode fallback logic is covered by unit tests.
- [ ] 100% test pass rate in `MoaiyTests`.
