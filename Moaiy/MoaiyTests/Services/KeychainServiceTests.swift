//
//  KeychainServiceTests.swift
//  MoaiyTests
//
//  Unit tests for KeychainService and passphrase storage integration.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Keychain Service Tests")
struct KeychainServiceTests {

    @Test("KeychainService save, retrieve, and delete roundtrip succeeds in test domain")
    func keychainService_roundtrip_succeeds() async throws {
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
