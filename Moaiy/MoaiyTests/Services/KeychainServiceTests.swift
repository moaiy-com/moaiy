//
//  KeychainServiceTests.swift
//  MoaiyTests
//
//  Unit tests for KeychainService and passphrase storage integration.
//

import Foundation
import Security
import Testing
@testable import Moaiy

private final class MockSecItemState: @unchecked Sendable {
    private let lock = NSLock()
    var addCalls: [[String: Any]] = []
    var copyCalls: [[String: Any]] = []
    var deleteCalls: [[String: Any]] = []
    var legacyStore: [String: Data] = [:]

    func recordAdd(_ query: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        addCalls.append(query)
    }

    func recordCopy(_ query: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        copyCalls.append(query)
    }

    func recordDelete(_ query: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        deleteCalls.append(query)
    }
}

@Suite("Keychain Service Tests", .serialized)
struct KeychainServiceTests {

    @Test("KeychainService save, retrieve, and delete roundtrip succeeds in test domain")
    func keychainService_roundtrip_succeeds() async throws {
#if DEBUG
        let originalToggle = KeychainService.allowLegacyKeychainFallback
        KeychainService.allowLegacyKeychainFallback = true
        defer { KeychainService.allowLegacyKeychainFallback = originalToggle }
#endif

        let testDomain = "com.moaiy.tests.keychain-\(UUID().uuidString)"
        let keychain = KeychainService(serviceDomain: testDomain)
        let fingerprint = "4D8B93C4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0"
        let passphraseText = "UnitTestingPassphrase@789"
        let securePassphrase = SecureString(passphraseText)

        defer {
            try? keychain.deletePassphrase(for: fingerprint)
        }

        #expect(!keychain.isPassphraseStored(for: fingerprint))

        // Save
        try keychain.savePassphrase(securePassphrase, for: fingerprint, requireBiometrics: false)
        #expect(keychain.isPassphraseStored(for: fingerprint))

        // Retrieve
        let retrieved = try await keychain.retrievePassphrase(for: fingerprint)
        #expect(retrieved != nil)
        #expect(retrieved?.revealString() == passphraseText)

        // Delete
        try keychain.deletePassphrase(for: fingerprint)
        #expect(!keychain.isPassphraseStored(for: fingerprint))

        let retrievedAfterDelete = try await keychain.retrievePassphrase(for: fingerprint)
        #expect(retrievedAfterDelete == nil)
    }

    @Test("When allowLegacyKeychainFallback is false, errSecMissingEntitlement throws unhandledStatus and does not query legacy Keychain")
    func keychainService_fallbackDisabled_throwsUnhandledStatusOnMissingEntitlement() async throws {
#if DEBUG
        let originalToggle = KeychainService.allowLegacyKeychainFallback
        KeychainService.allowLegacyKeychainFallback = false
        defer { KeychainService.allowLegacyKeychainFallback = originalToggle }
#endif

        let state = MockSecItemState()
        let ops = KeychainSecItemOperations(
            add: { queryDict, _ in
                let dict = (queryDict as NSDictionary as? [String: Any]) ?? [:]
                state.recordAdd(dict)
                return errSecMissingEntitlement
            },
            copyMatching: { queryDict, _ in
                let dict = (queryDict as NSDictionary as? [String: Any]) ?? [:]
                state.recordCopy(dict)
                return errSecMissingEntitlement
            }
        )

        let keychain = KeychainService(serviceDomain: "com.moaiy.tests.mock-disabled", secItemOperations: ops)
        let fpr = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

        var saveThrewUnhandled = false
        do {
            try keychain.savePassphrase(SecureString("secret"), for: fpr, requireBiometrics: false)
        } catch KeychainError.unhandledStatus(let status) {
            saveThrewUnhandled = (status == errSecMissingEntitlement)
        }
        #expect(saveThrewUnhandled)
        #expect(state.addCalls.count == 1)

        var retrieveThrewUnhandled = false
        do {
            _ = try await keychain.retrievePassphrase(for: fpr)
        } catch KeychainError.unhandledStatus(let status) {
            retrieveThrewUnhandled = (status == errSecMissingEntitlement)
        }
        #expect(retrieveThrewUnhandled)
        #expect(state.copyCalls.count == 1)

        let stored = keychain.isPassphraseStored(for: fpr)
        #expect(!stored)
        #expect(state.copyCalls.count == 2)
    }

    @Test("errSecItemNotFound on Data Protection Keychain does not trigger legacy Keychain query")
    func keychainService_itemNotFound_doesNotQueryLegacyKeychain() async throws {
#if DEBUG
        let originalToggle = KeychainService.allowLegacyKeychainFallback
        KeychainService.allowLegacyKeychainFallback = true
        defer { KeychainService.allowLegacyKeychainFallback = originalToggle }
#endif

        let state = MockSecItemState()
        let ops = KeychainSecItemOperations(
            copyMatching: { queryDict, _ in
                let dict = (queryDict as NSDictionary as? [String: Any]) ?? [:]
                state.recordCopy(dict)
                return errSecItemNotFound
            }
        )

        let keychain = KeychainService(serviceDomain: "com.moaiy.tests.mock-notfound", secItemOperations: ops)
        let fpr = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"

        let retrieved = try await keychain.retrievePassphrase(for: fpr)
        #expect(retrieved == nil)
        // Must only query Data Protection Keychain once; errSecItemNotFound must NOT fallback to legacy query
        #expect(state.copyCalls.count == 1)
        #expect((state.copyCalls.first?[kSecUseDataProtectionKeychain as String] as? Bool) == true)

        let stored = keychain.isPassphraseStored(for: fpr)
        #expect(!stored)
        #expect(state.copyCalls.count == 2)
        #expect((state.copyCalls.last?[kSecUseDataProtectionKeychain as String] as? Bool) == true)
    }

    @Test("When allowLegacyKeychainFallback is true, errSecMissingEntitlement falls back to legacy Keychain for read and write")
    func keychainService_fallbackEnabled_readsAndWritesLegacyKeychainOnMissingEntitlement() async throws {
#if DEBUG
        let originalToggle = KeychainService.allowLegacyKeychainFallback
        KeychainService.allowLegacyKeychainFallback = true
        defer { KeychainService.allowLegacyKeychainFallback = originalToggle }

        let state = MockSecItemState()
        let ops = KeychainSecItemOperations(
            add: { queryDict, _ in
                let dict = (queryDict as NSDictionary as? [String: Any]) ?? [:]
                state.recordAdd(dict)
                if (dict[kSecUseDataProtectionKeychain as String] as? Bool) == true {
                    return errSecMissingEntitlement
                }
                if let account = dict[kSecAttrAccount as String] as? String,
                   let data = dict[kSecValueData as String] as? Data {
                    state.legacyStore[account] = data
                    return errSecSuccess
                }
                return errSecParam
            },
            copyMatching: { queryDict, resultPtr in
                let dict = (queryDict as NSDictionary as? [String: Any]) ?? [:]
                state.recordCopy(dict)
                if (dict[kSecUseDataProtectionKeychain as String] as? Bool) == true {
                    return errSecMissingEntitlement
                }
                guard let account = dict[kSecAttrAccount as String] as? String,
                      let data = state.legacyStore[account] else {
                    return errSecItemNotFound
                }
                if let resultPtr {
                    resultPtr.pointee = data as CFData
                }
                return errSecSuccess
            },
            delete: { queryDict in
                let dict = (queryDict as NSDictionary as? [String: Any]) ?? [:]
                state.recordDelete(dict)
                if (dict[kSecUseDataProtectionKeychain as String] as? Bool) == true {
                    return errSecMissingEntitlement
                }
                if let account = dict[kSecAttrAccount as String] as? String {
                    state.legacyStore.removeValue(forKey: account)
                }
                return errSecSuccess
            }
        )

        let keychain = KeychainService(serviceDomain: "com.moaiy.tests.mock-enabled", secItemOperations: ops)
        let fpr = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"

        try keychain.savePassphrase(SecureString("fallback-pass-999"), for: fpr, requireBiometrics: false)
        #expect(state.addCalls.count == 2)
        #expect(keychain.isPassphraseStored(for: fpr))

        let retrieved = try await keychain.retrievePassphrase(for: fpr)
        #expect(retrieved?.revealString() == "fallback-pass-999")

        try keychain.deletePassphrase(for: fpr)
        #expect(!keychain.isPassphraseStored(for: fpr))
#endif
    }

    @Test("Deleting non-existent key from Keychain does not throw error")
    func keychainService_deleteNonExistent_doesNotThrow() throws {
        let testDomain = "com.moaiy.tests.keychain-\(UUID().uuidString)"
        let keychain = KeychainService(serviceDomain: testDomain)
        let randomFingerprint = "NONEXISTENT_KEY_\(UUID().uuidString)"

        try keychain.deletePassphrase(for: randomFingerprint)
        #expect(!keychain.isPassphraseStored(for: randomFingerprint))
    }

    @Test("Biometrics query executes safely")
    func keychainService_biometricsQuery_executesSafely() {
        let keychain = KeychainService.shared
        _ = keychain.isBiometricsAvailable()
        _ = keychain.biometryType()
    }
}
