//
//  TextEncryptionFlowTests.swift
//  MoaiyTests
//
//  Integration tests for text encryption and decryption flows.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Text Encryption Flow Tests")
@MainActor
struct TextEncryptionFlowTests {

    @Test("Text encrypt and decrypt roundtrip succeeds")
    func textEncryptDecrypt_roundtrip() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "roundtrip")
        let plaintext = "Moaiy text flow \(UUID().uuidString)"
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let ciphertext = try await service.encrypt(
                text: plaintext,
                recipients: [fingerprint]
            )
            #expect(ciphertext.contains("BEGIN PGP MESSAGE"))

            let decrypted = try await service.decrypt(
                text: ciphertext,
                passphrase: identity.passphrase
            )
            #expect(normalized(decrypted) == normalized(plaintext))
        } catch {
            if let generatedFingerprint {
                await cleanupKey(fingerprint: generatedFingerprint, service: service)
            }
            throw error
        }

        if let generatedFingerprint {
            await cleanupKey(fingerprint: generatedFingerprint, service: service)
        }
    }

    @Test("PQC text encrypt/decrypt roundtrip succeeds in isolated homes")
    func pqcTextEncryptDecrypt_roundtrip() async throws {
        let senderHome = try TestGPGHome.make(prefix: "p6-text-sender")
        let recipientHome = try TestGPGHome.make(prefix: "p6-text-recipient")
        defer {
            senderHome.cleanup()
            recipientHome.cleanup()
        }

        try await senderHome.requireKyberSupport()
        try await recipientHome.requireKyberSupport()

        let identity = makeIdentity(seed: "pqc-text")
        let plaintext = "Moaiy PQC text flow \(UUID().uuidString)"

        let fingerprint = try await recipientHome.generatePostQuantumHybridKey(
            name: identity.name,
            email: identity.email,
            passphrase: identity.passphrase
        )

        let publicKey = try await recipientHome.exportPublicKey(keyID: fingerprint)
        #expect(publicKey.contains("BEGIN PGP PUBLIC KEY BLOCK"))

        try await senderHome.importArmor(publicKey)

        let ciphertext = try await senderHome.encryptText(
            plaintext,
            recipients: [fingerprint],
            allowUntrustedRecipients: true
        )
        #expect(ciphertext.contains("BEGIN PGP MESSAGE"))

        let decrypted = try await recipientHome.decryptText(
            ciphertext,
            passphrase: identity.passphrase
        )
        #expect(normalized(decrypted) == normalized(plaintext))

        await recipientHome.killAgent()

        let wrongPassphraseResult = try await recipientHome.decryptTextResult(
            ciphertext,
            passphrase: "\(identity.passphrase)-wrong"
        )
        #expect(wrongPassphraseResult.exitCode != 0)

        guard case .invalidPassphrase? = GPGService.credentialFailureError(from: wrongPassphraseResult) else {
            Issue.record("Expected wrong PQC passphrase to map to invalidPassphrase")
            return
        }
    }

    @Test("Text decrypt fails with invalid passphrase")
    func textDecrypt_invalidPassphrase_fails() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "wrong-passphrase")
        let plaintext = "Invalid passphrase check \(UUID().uuidString)"
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let ciphertext = try await service.encrypt(
                text: plaintext,
                recipients: [fingerprint]
            )

            do {
                _ = try await service.decrypt(
                    text: ciphertext,
                    passphrase: "\(identity.passphrase)-invalid"
                )
                Issue.record("Expected decryption to fail with wrong passphrase")
            } catch let error as GPGError {
                switch error {
                case .decryptionFailed:
                    break
                default:
                    Issue.record("Unexpected GPGError: \(String(describing: error))")
                }
            } catch {
                Issue.record("Unexpected error type: \(error.localizedDescription)")
            }
        } catch {
            if let generatedFingerprint {
                await cleanupKey(fingerprint: generatedFingerprint, service: service)
            }
            throw error
        }

        if let generatedFingerprint {
            await cleanupKey(fingerprint: generatedFingerprint, service: service)
        }
    }

    @Test("Text encrypt fails when recipient is invalid")
    func textEncrypt_invalidRecipient_fails() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        do {
            _ = try await service.encrypt(
                text: "recipient-check-\(UUID().uuidString)",
                recipients: ["INVALID_RECIPIENT_1234567890"]
            )
            Issue.record("Expected encryption to fail for invalid recipient")
        } catch let error as GPGError {
            switch error {
            case .encryptionFailed:
                break
            default:
                Issue.record("Unexpected GPGError: \(String(describing: error))")
            }
        } catch {
            Issue.record("Unexpected error type: \(error.localizedDescription)")
        }
    }

    private func waitForServiceReady(_ service: GPGService) async throws {
        let timeoutNanoseconds: UInt64 = 30_000_000_000
        let stepNanoseconds: UInt64 = 200_000_000
        var elapsed: UInt64 = 0

        while !service.isReady && elapsed < timeoutNanoseconds {
            try await Task.sleep(nanoseconds: stepNanoseconds)
            elapsed += stepNanoseconds
        }

        #expect(service.isReady == true, "GPGService must be ready for text flow tests")
    }

    private func cleanupKey(fingerprint: String, service: GPGService) async {
        try? await service.deleteKey(keyID: fingerprint, secret: true)
        try? await service.deleteKey(keyID: fingerprint, secret: false)
    }

    private func makeIdentity(seed: String) -> (name: String, email: String, passphrase: String) {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let suffix = "\(seed)-\(token)"
        return (
            name: "Moaiy \(suffix)",
            email: "moaiy-\(suffix)@example.com",
            passphrase: "Moaiy-\(suffix)-Passphrase-123!"
        )
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
