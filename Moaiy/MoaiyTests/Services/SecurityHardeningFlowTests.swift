//
//  SecurityHardeningFlowTests.swift
//  MoaiyTests
//
//  Integration tests for v0.5.2 stability and security hardening.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Security Hardening Flow Tests")
@MainActor
struct SecurityHardeningFlowTests {

    @Test("Encryption blocks untrusted recipients by default and allows explicit override")
    func encryption_untrustedRecipient_requiresExplicitOverride() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "untrusted-recipient")
        let tempDir = try makeTempDirectory(label: "untrusted-recipient")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var recipientFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            recipientFingerprint = fingerprint

            let publicData = try await service.exportPublicKey(keyID: fingerprint, armor: true)
            try? await service.deleteKey(keyID: fingerprint, secret: true)
            try? await service.deleteKey(keyID: fingerprint, secret: false)

            let importURL = tempDir.appendingPathComponent("recipient-public.asc")
            try publicData.write(to: importURL, options: .atomic)
            _ = try await service.importKey(from: importURL)

            try? await service.setTrust(keyID: fingerprint, trustLevel: .none)
            let trust = try await service.checkTrust(keyID: fingerprint)
            #expect(trust != .full && trust != .ultimate)

            let plaintext = "security-check-\(UUID().uuidString)"
            do {
                _ = try await service.encrypt(
                    text: plaintext,
                    recipients: [fingerprint]
                )
                Issue.record("Expected encryption to fail for untrusted recipient")
            } catch let error as GPGError {
                switch error {
                case .encryptionFailed:
                    break
                default:
                    Issue.record("Unexpected GPGError: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }

            let ciphertext = try await service.encrypt(
                text: plaintext,
                recipients: [fingerprint],
                allowUntrustedRecipients: true
            )
            #expect(ciphertext.contains("BEGIN PGP MESSAGE"))
        } catch {
            if let recipientFingerprint {
                await cleanupKey(fingerprint: recipientFingerprint, service: service)
            }
            throw error
        }

        if let recipientFingerprint {
            await cleanupKey(fingerprint: recipientFingerprint, service: service)
        }
    }

    @Test("Key generation passphrase sanitation handles line breaks safely")
    func keyGeneration_passphraseWithLineBreaks_isSanitized() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "passphrase-sanitize")
        let rawPassphrase = "Line1\r\nLine2\nLine3"
        let sanitizedPassphrase = sanitizeBatchPassphrase(rawPassphrase)
        let plaintext = "sanitize-passphrase-\(UUID().uuidString)"
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: rawPassphrase
            )
            generatedFingerprint = fingerprint

            let ciphertext = try await service.encrypt(
                text: plaintext,
                recipients: [fingerprint]
            )
            let decrypted = try await service.decrypt(
                text: ciphertext,
                passphrase: sanitizedPassphrase
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

    @Test("Key import accepts dash-prefixed filenames")
    func keyImport_dashPrefixedFileName_succeeds() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "dash-file-name")
        let tempDir = try makeTempDirectory(label: "dash-file-name")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let exported = try await service.exportPublicKey(keyID: fingerprint, armor: true)
            let dashFile = tempDir.appendingPathComponent("-evil.asc")
            try exported.write(to: dashFile, options: .atomic)

            let result = try await service.importKey(from: dashFile)
            #expect((result.imported + result.unchanged) >= 1)
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

    @Test("Backup with private key fails restore when payload is tampered")
    func backupRestore_tamperedPayload_failsValidation() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "backup-tamper")
        let backupDir = try makeTempDirectory(label: "backup-tamper")
        defer { try? FileManager.default.removeItem(at: backupDir) }

        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let publicData = try await service.exportPublicKey(keyID: fingerprint, armor: true)
            let secretData = try await service.exportSecretKey(
                keyID: fingerprint,
                passphrase: identity.passphrase,
                armor: true
            )

            let publicName = "\(fingerprint)_public.asc"
            let secretName = "\(fingerprint)_secret.asc"
            let publicURL = backupDir.appendingPathComponent(publicName)
            let secretURL = backupDir.appendingPathComponent(secretName)
            try publicData.write(to: publicURL, options: .atomic)
            try secretData.write(to: secretURL, options: .atomic)

            let manifest = BackupManifest(
                version: "1.1",
                created: Date(),
                keyCount: 1,
                includeSecretKeys: true,
                exportedPublicKeyCount: 1,
                exportedSecretKeyCount: 1,
                failedSecretKeyCount: 0,
                keys: [
                    BackupKeyInfo(
                        fingerprint: fingerprint,
                        name: identity.name,
                        email: identity.email,
                        isSecret: true
                    )
                ],
                files: [
                    BackupManifestFileEntry(
                        fileName: publicName,
                        sha256: BackupIntegrityVerifier.sha256Hex(for: publicData),
                        kind: .publicKey
                    ),
                    BackupManifestFileEntry(
                        fileName: secretName,
                        sha256: BackupIntegrityVerifier.sha256Hex(for: secretData),
                        kind: .secretKey
                    )
                ],
                totalFiles: 2
            )

            // Tamper after manifest hash is prepared.
            var tamperedSecretData = secretData
            tamperedSecretData.append(Data("tamper".utf8))
            try tamperedSecretData.write(to: secretURL, options: .atomic)

            do {
                _ = try BackupIntegrityVerifier.validateImportableFiles(
                    in: backupDir,
                    manifest: manifest,
                    maxFileSizeBytes: Constants.Backup.maxImportFileSizeBytes
                )
                Issue.record("Expected tampered backup payload to fail integrity check")
            } catch BackupIntegrityError.fileHashMismatch {
                // Expected
            } catch {
                Issue.record("Unexpected error: \(error)")
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

    @Test("Backup with private key restores successfully when payload is intact")
    func backupRestore_intactPayload_succeeds() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "backup-intact")
        let backupDir = try makeTempDirectory(label: "backup-intact")
        defer { try? FileManager.default.removeItem(at: backupDir) }

        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let publicData = try await service.exportPublicKey(keyID: fingerprint, armor: true)
            let secretData = try await service.exportSecretKey(
                keyID: fingerprint,
                passphrase: identity.passphrase,
                armor: true
            )

            let publicName = "\(fingerprint)_public.asc"
            let secretName = "\(fingerprint)_secret.asc"
            let publicURL = backupDir.appendingPathComponent(publicName)
            let secretURL = backupDir.appendingPathComponent(secretName)
            try publicData.write(to: publicURL, options: .atomic)
            try secretData.write(to: secretURL, options: .atomic)

            let manifest = BackupManifest(
                version: "1.1",
                created: Date(),
                keyCount: 1,
                includeSecretKeys: true,
                exportedPublicKeyCount: 1,
                exportedSecretKeyCount: 1,
                failedSecretKeyCount: 0,
                keys: [
                    BackupKeyInfo(
                        fingerprint: fingerprint,
                        name: identity.name,
                        email: identity.email,
                        isSecret: true
                    )
                ],
                files: [
                    BackupManifestFileEntry(
                        fileName: publicName,
                        sha256: BackupIntegrityVerifier.sha256Hex(for: publicData),
                        kind: .publicKey
                    ),
                    BackupManifestFileEntry(
                        fileName: secretName,
                        sha256: BackupIntegrityVerifier.sha256Hex(for: secretData),
                        kind: .secretKey
                    )
                ],
                totalFiles: 2
            )

            let validation = try BackupIntegrityVerifier.validateImportableFiles(
                in: backupDir,
                manifest: manifest,
                maxFileSizeBytes: Constants.Backup.maxImportFileSizeBytes
            )
            #expect(validation.files.count == 2)

            var restoredCount = 0
            for fileURL in validation.files {
                let result = try await service.importKey(from: fileURL)
                if result.imported > 0 || result.unchanged > 0 {
                    restoredCount += 1
                }
            }
            #expect(restoredCount == 2)
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

        #expect(service.isReady == true, "GPGService must be ready for hardening flow tests")
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
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("moaiy-security-hardening-\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func sanitizeBatchPassphrase(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
