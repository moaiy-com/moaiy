//
//  FileEncryptionFlowTests.swift
//  MoaiyTests
//
//  Integration tests for file encryption and decryption flows.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("File Encryption Flow Tests")
@MainActor
struct FileEncryptionFlowTests {

    @Test("File encrypt/decrypt roundtrip and existing destination overwrite succeed")
    func fileEncryptDecrypt_roundtrip_andOverwriteHandling() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let fileManager = FileManager.default
        let identity = makeIdentity(seed: "file-roundtrip")
        let plaintext = "Moaiy file flow \(UUID().uuidString)\nline-2"
        let tempDirectory = try makeTempDirectory(label: "file-roundtrip")
        var generatedFingerprint: String?

        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let sourceURL = tempDirectory.appendingPathComponent("plain.txt")
            try Data(plaintext.utf8).write(to: sourceURL, options: .atomic)

            let encryptedDestination = tempDirectory.appendingPathComponent("plain.txt.moy")
            let encryptedURL = try await service.encryptFile(
                sourceURL: sourceURL,
                destinationURL: encryptedDestination,
                recipients: [fingerprint]
            )
            #expect(encryptedURL.lastPathComponent == "plain.txt.moy")
            #expect(fileManager.fileExists(atPath: encryptedURL.path))

            let decryptedDestination = tempDirectory.appendingPathComponent("plain.decrypted.txt")
            let decryptedURL = try await service.decryptFile(
                sourceURL: encryptedURL,
                destinationURL: decryptedDestination,
                passphrase: identity.passphrase
            )
            #expect(fileManager.fileExists(atPath: decryptedURL.path))

            let decryptedText = try String(contentsOf: decryptedURL, encoding: .utf8)
            #expect(normalized(decryptedText) == normalized(plaintext))
            
            // Existing destination is replaced because the user explicitly selected it.
            let requestedEncryptedURL = tempDirectory.appendingPathComponent("output.moy")
            try Data("existing".utf8).write(to: requestedEncryptedURL, options: .atomic)

            let conflictedEncryptedURL = try await service.encryptFile(
                sourceURL: sourceURL,
                destinationURL: requestedEncryptedURL,
                recipients: [fingerprint]
            )
            #expect(conflictedEncryptedURL.lastPathComponent == "output.moy")
            #expect(fileManager.fileExists(atPath: conflictedEncryptedURL.path))

            let requestedDecryptedURL = tempDirectory.appendingPathComponent("output.txt")
            try Data("existing".utf8).write(to: requestedDecryptedURL, options: .atomic)

            let conflictedDecryptedURL = try await service.decryptFile(
                sourceURL: conflictedEncryptedURL,
                destinationURL: requestedDecryptedURL,
                passphrase: identity.passphrase
            )
            #expect(conflictedDecryptedURL.lastPathComponent == "output.txt")
            #expect(fileManager.fileExists(atPath: conflictedDecryptedURL.path))

            let conflictedDecryptedText = try String(contentsOf: conflictedDecryptedURL, encoding: .utf8)
            #expect(normalized(conflictedDecryptedText) == normalized(plaintext))
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

    @Test("decryptFile respects preferred secret key and fails when mismatched")
    func decryptFile_preferredSecretKey_mismatchFails() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let fileManager = FileManager.default
        let sender = makeIdentity(seed: "preferred-secret-a")
        let other = makeIdentity(seed: "preferred-secret-b")
        let plaintext = "preferred-secret-key-\(UUID().uuidString)"
        let tempDirectory = try makeTempDirectory(label: "preferred-secret-key")
        var senderFingerprint: String?
        var otherFingerprint: String?

        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        do {
            let fpA = try await service.generateKey(
                name: sender.name,
                email: sender.email,
                keyType: .ecc,
                passphrase: sender.passphrase
            )
            senderFingerprint = fpA

            let fpB = try await service.generateKey(
                name: other.name,
                email: other.email,
                keyType: .ecc,
                passphrase: other.passphrase
            )
            otherFingerprint = fpB

            let sourceURL = tempDirectory.appendingPathComponent("input.txt")
            try Data(plaintext.utf8).write(to: sourceURL, options: .atomic)

            let encryptedURL = try await service.encryptFile(
                sourceURL: sourceURL,
                destinationURL: tempDirectory.appendingPathComponent("input.txt.moy"),
                recipients: [fpA]
            )

            let mismatchedDestination = tempDirectory.appendingPathComponent("mismatch.txt")
            do {
                _ = try await service.decryptFile(
                    sourceURL: encryptedURL,
                    destinationURL: mismatchedDestination,
                    passphrase: sender.passphrase,
                    preferredSecretKey: fpB
                )
                Issue.record("Expected decrypt to fail when preferred secret key does not match recipient")
            } catch let error as GPGError {
                switch error {
                case .keyNotFound, .decryptionFailed:
                    break
                default:
                    Issue.record("Unexpected GPGError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }

            let matchedDestination = tempDirectory.appendingPathComponent("matched.txt")
            let matchedURL = try await service.decryptFile(
                sourceURL: encryptedURL,
                destinationURL: matchedDestination,
                passphrase: sender.passphrase,
                preferredSecretKey: fpA
            )
            #expect(fileManager.fileExists(atPath: matchedURL.path))
            let decryptedText = try String(contentsOf: matchedURL, encoding: .utf8)
            #expect(normalized(decryptedText) == normalized(plaintext))
        } catch {
            if let senderFingerprint {
                await cleanupKey(fingerprint: senderFingerprint, service: service)
            }
            if let otherFingerprint {
                await cleanupKey(fingerprint: otherFingerprint, service: service)
            }
            throw error
        }

        if let senderFingerprint {
            await cleanupKey(fingerprint: senderFingerprint, service: service)
        }
        if let otherFingerprint {
            await cleanupKey(fingerprint: otherFingerprint, service: service)
        }
    }

    @Test("decryptFile with wrong passphrase fails and does not produce output")
    func decryptFile_wrongPassphraseFailsWithoutOutput() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let fileManager = FileManager.default
        let identity = makeIdentity(seed: "wrong-passphrase")
        let plaintext = "wrong-passphrase-\(UUID().uuidString)"
        let tempDirectory = try makeTempDirectory(label: "wrong-passphrase")
        var generatedFingerprint: String?

        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let sourceURL = tempDirectory.appendingPathComponent("input.txt")
            try Data(plaintext.utf8).write(to: sourceURL, options: .atomic)

            let encryptedURL = try await service.encryptFile(
                sourceURL: sourceURL,
                destinationURL: tempDirectory.appendingPathComponent("input.txt.moy"),
                recipients: [fingerprint]
            )

            let wrongPassphraseOutput = tempDirectory.appendingPathComponent("wrong-passphrase.txt")
            do {
                _ = try await service.decryptFile(
                    sourceURL: encryptedURL,
                    destinationURL: wrongPassphraseOutput,
                    passphrase: "totally-wrong-passphrase",
                    preferredSecretKey: fingerprint
                )
                Issue.record("Expected decrypt to fail when passphrase is incorrect")
            } catch let error as GPGError {
                switch error {
                case .invalidPassphrase, .decryptionFailed:
                    break
                default:
                    Issue.record("Unexpected GPGError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }

            #expect(fileManager.fileExists(atPath: wrongPassphraseOutput.path) == false)
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

    private func waitForServiceReady(_ service: GPGService) async throws {
        let timeoutNanoseconds: UInt64 = 30_000_000_000
        let stepNanoseconds: UInt64 = 200_000_000
        var elapsed: UInt64 = 0

        while !service.isReady && elapsed < timeoutNanoseconds {
            try await Task.sleep(nanoseconds: stepNanoseconds)
            elapsed += stepNanoseconds
        }

        #expect(service.isReady == true, "GPGService must be ready for file flow tests")
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

    private func makeTempDirectory(label: String) throws -> URL {
        let fileManager = FileManager.default
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("moaiy-\(label)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
