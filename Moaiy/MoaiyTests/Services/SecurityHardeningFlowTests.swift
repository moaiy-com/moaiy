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

    @Test("Imported public key with full ownertrust still requires explicit encryption override")
    func fileEncryption_importedPublicKey_ownerTrustFull_requiresOverride() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "ownertrust-vs-validity")
        let tempDir = try makeTempDirectory(label: "ownertrust-vs-validity")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var importedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            importedFingerprint = fingerprint

            let publicData = try await service.exportPublicKey(keyID: fingerprint, armor: true)
            try? await service.deleteKey(keyID: fingerprint, secret: true)
            try? await service.deleteKey(keyID: fingerprint, secret: false)

            let importURL = tempDir.appendingPathComponent("recipient-public-ownertrust-full.asc")
            try publicData.write(to: importURL, options: .atomic)
            _ = try await service.importKey(from: importURL)

            // Simulate the problematic real-world state:
            // ownertrust is full, but key validity stays unknown for imported public keys.
            try await service.setTrust(keyID: fingerprint, trustLevel: .full)
            let ownerTrust = try await service.checkTrust(keyID: fingerprint)
            #expect(ownerTrust == .full)

            let listedKeys = try await service.listKeys(secretOnly: false)
            guard let listedImportedKey = listedKeys.first(where: { $0.fingerprint == fingerprint }) else {
                Issue.record("Imported key should appear in key list")
                return
            }

            #expect(listedImportedKey.trustLevel == .unknown)
            #expect(listedImportedKey.isTrusted == false)

            let sourceURL = tempDir.appendingPathComponent("plain.txt")
            try Data("ownertrust-validity-check".utf8).write(to: sourceURL, options: .atomic)

            let blockedOutputURL = tempDir.appendingPathComponent("blocked.moy")
            do {
                _ = try await service.encryptFile(
                    sourceURL: sourceURL,
                    destinationURL: blockedOutputURL,
                    recipients: [fingerprint]
                )
                Issue.record("Expected encryption to fail without explicit untrusted override")
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

            let allowedOutputURL = tempDir.appendingPathComponent("allowed.moy")
            let finalURL = try await service.encryptFile(
                sourceURL: sourceURL,
                destinationURL: allowedOutputURL,
                recipients: [fingerprint],
                allowUntrustedRecipients: true
            )
            #expect(FileManager.default.fileExists(atPath: finalURL.path))
        } catch {
            if let importedFingerprint {
                await cleanupKey(fingerprint: importedFingerprint, service: service)
            }
            throw error
        }

        if let importedFingerprint {
            await cleanupKey(fingerprint: importedFingerprint, service: service)
        }
    }

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

    @Test("Changing passphrase from unprotected key with empty current passphrase requires the new passphrase afterward")
    func changePassphrase_unprotectedKey_emptyOld_setsNewPassphrase() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "change-pass-empty-old")
        let firstPassphrase = "Moaiy-First-\(UUID().uuidString.prefix(8))!"
        let secondPassphrase = "Moaiy-Second-\(UUID().uuidString.prefix(8))!"
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: nil
            )
            generatedFingerprint = fingerprint

            try await service.changePassphrase(
                keyID: fingerprint,
                oldPassphrase: "",
                newPassphrase: firstPassphrase
            )

            do {
                try await service.changePassphrase(
                    keyID: fingerprint,
                    oldPassphrase: "wrong-\(UUID().uuidString.prefix(6))",
                    newPassphrase: secondPassphrase
                )
                Issue.record("Expected invalid passphrase after setting a new passphrase")
            } catch let error as GPGError {
                switch error {
                case .invalidPassphrase:
                    break
                default:
                    Issue.record("Unexpected GPGError: \(error)")
                }
            }

            try await service.changePassphrase(
                keyID: fingerprint,
                oldPassphrase: firstPassphrase,
                newPassphrase: secondPassphrase
            )
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

    @Test("Changing passphrase from unprotected key tolerates accidental old-passphrase input")
    func changePassphrase_unprotectedKey_typedOld_fallsBackAndSetsNewPassphrase() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "change-pass-typed-old")
        let typedOldPassphrase = "typed-old-\(UUID().uuidString.prefix(6))"
        let firstPassphrase = "Moaiy-Fallback-\(UUID().uuidString.prefix(8))!"
        let secondPassphrase = "Moaiy-Verify-\(UUID().uuidString.prefix(8))!"
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: nil
            )
            generatedFingerprint = fingerprint

            try await service.changePassphrase(
                keyID: fingerprint,
                oldPassphrase: typedOldPassphrase,
                newPassphrase: firstPassphrase
            )

            do {
                try await service.changePassphrase(
                    keyID: fingerprint,
                    oldPassphrase: typedOldPassphrase,
                    newPassphrase: secondPassphrase
                )
                Issue.record("Typed old passphrase should not unlock the updated key")
            } catch let error as GPGError {
                switch error {
                case .invalidPassphrase:
                    break
                default:
                    Issue.record("Unexpected GPGError: \(error)")
                }
            }

            try await service.changePassphrase(
                keyID: fingerprint,
                oldPassphrase: firstPassphrase,
                newPassphrase: secondPassphrase
            )
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

    @Test("Secret key passphrase requirement detection distinguishes protected and unprotected keys")
    func secretKeyRequiresPassphrase_detectsProtectionState() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let protectedIdentity = makeIdentity(seed: "key-protected")
        let unprotectedIdentity = makeIdentity(seed: "key-unprotected")
        var protectedFingerprint: String?
        var unprotectedFingerprint: String?

        do {
            let protected = try await service.generateKey(
                name: protectedIdentity.name,
                email: protectedIdentity.email,
                keyType: .ecc,
                passphrase: protectedIdentity.passphrase
            )
            protectedFingerprint = protected

            let unprotected = try await service.generateKey(
                name: unprotectedIdentity.name,
                email: unprotectedIdentity.email,
                keyType: .ecc,
                passphrase: nil
            )
            unprotectedFingerprint = unprotected

            let protectedRequires = try await service.secretKeyRequiresPassphrase(keyID: protected)
            let unprotectedRequires = try await service.secretKeyRequiresPassphrase(keyID: unprotected)

            #expect(protectedRequires == true)
            #expect(unprotectedRequires == false)
        } catch {
            if let protectedFingerprint {
                await cleanupKey(fingerprint: protectedFingerprint, service: service)
            }
            if let unprotectedFingerprint {
                await cleanupKey(fingerprint: unprotectedFingerprint, service: service)
            }
            throw error
        }

        if let protectedFingerprint {
            await cleanupKey(fingerprint: protectedFingerprint, service: service)
        }
        if let unprotectedFingerprint {
            await cleanupKey(fingerprint: unprotectedFingerprint, service: service)
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

    @Test("Subkey lifecycle supports add update disable enable and revoke")
    func subkeyLifecycle_addUpdateDisableEnableAndRevoke() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "subkey-lifecycle")
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .rsa2048,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let beforeSubkeys = try await service.listSubkeys(primaryKeyID: fingerprint)
            let beforeFingerprints = Set(beforeSubkeys.map(\.fingerprint))

            let addedExpiresAt = Calendar.current.date(byAdding: .year, value: 1, to: Date())
            try await service.addSubkey(
                primaryKeyID: fingerprint,
                usage: .encrypt,
                expiresAt: addedExpiresAt,
                passphrase: identity.passphrase
            )

            let afterAddSubkeys = try await service.listSubkeys(primaryKeyID: fingerprint)
            #expect(afterAddSubkeys.count == beforeSubkeys.count + 1)

            guard let newSubkey = afterAddSubkeys.first(where: { !beforeFingerprints.contains($0.fingerprint) }) else {
                Issue.record("Expected one newly added subkey")
                return
            }
            #expect(newSubkey.usages.contains(.encrypt))

            let updatedExpiresAt = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
            try await service.updateSubkeyExpiration(
                primaryKeyID: fingerprint,
                subkeyFingerprint: newSubkey.fingerprint,
                expiresAt: updatedExpiresAt,
                passphrase: identity.passphrase
            )

            let afterUpdateSubkeys = try await service.listSubkeys(primaryKeyID: fingerprint)
            guard let updatedSubkey = afterUpdateSubkeys.first(where: { $0.fingerprint == newSubkey.fingerprint }) else {
                Issue.record("Updated subkey should remain listed")
                return
            }

            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"

            #expect(updatedSubkey.expiresAt != nil)
            #expect(
                formatter.string(from: updatedSubkey.expiresAt ?? .distantPast)
                    == formatter.string(from: updatedExpiresAt)
            )

            try await service.disableSubkey(
                primaryKeyID: fingerprint,
                subkeyFingerprint: newSubkey.fingerprint,
                passphrase: identity.passphrase
            )

            let afterDisableSubkeys = try await service.listSubkeys(primaryKeyID: fingerprint)
            guard let disabledSubkey = afterDisableSubkeys.first(where: { $0.fingerprint == newSubkey.fingerprint }) else {
                Issue.record("Disabled subkey should remain listed")
                return
            }
            #expect(disabledSubkey.status == .expired || disabledSubkey.isExpired)

            let enabledExpiresAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            try await service.enableSubkey(
                primaryKeyID: fingerprint,
                subkeyFingerprint: newSubkey.fingerprint,
                expiresAt: enabledExpiresAt,
                passphrase: identity.passphrase
            )

            let afterEnableSubkeys = try await service.listSubkeys(primaryKeyID: fingerprint)
            guard let enabledSubkey = afterEnableSubkeys.first(where: { $0.fingerprint == newSubkey.fingerprint }) else {
                Issue.record("Enabled subkey should remain listed")
                return
            }
            #expect(enabledSubkey.status != .revoked)
            #expect(!enabledSubkey.isExpired)

            try await service.revokeSubkey(
                primaryKeyID: fingerprint,
                subkeyFingerprint: newSubkey.fingerprint,
                reason: .noLongerUsed,
                description: "integration revoke",
                passphrase: identity.passphrase
            )

            let afterRevokeSubkeys = try await service.listSubkeys(primaryKeyID: fingerprint)
            guard let revokedSubkey = afterRevokeSubkeys.first(where: { $0.fingerprint == newSubkey.fingerprint }) else {
                Issue.record("Revoked subkey should remain listed")
                return
            }
            #expect(revokedSubkey.status == .revoked)
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

    @Test("Subkey add wrong passphrase maps to localized invalid passphrase message")
    func subkeyAdd_wrongPassphrase_mapsToLocalizedMessage() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "subkey-wrong-passphrase")
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .rsa2048,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            do {
                try await service.addSubkey(
                    primaryKeyID: fingerprint,
                    usage: .sign,
                    expiresAt: nil,
                    passphrase: "wrong-\(identity.passphrase)"
                )
                Issue.record("Expected invalid passphrase error")
            } catch {
                let mapped = UserFacingErrorMapper.message(for: error, context: .keyEdit)
                #expect(mapped == AppLocalization.string("error_invalid_passphrase"))
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

    @Test("Ownertrust export and import restores trust assignment")
    func ownertrustExportImport_roundtripRestoresTrust() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "ownertrust-export-import")
        let tempDir = try makeTempDirectory(label: "ownertrust-export-import")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var fingerprintToCleanup: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .ecc,
                passphrase: identity.passphrase
            )
            fingerprintToCleanup = fingerprint

            let publicData = try await service.exportPublicKey(keyID: fingerprint, armor: true)
            try? await service.deleteKey(keyID: fingerprint, secret: true)
            try? await service.deleteKey(keyID: fingerprint, secret: false)

            let importURL = tempDir.appendingPathComponent("ownertrust-recipient.asc")
            try publicData.write(to: importURL, options: .atomic)
            _ = try await service.importKey(from: importURL)

            try await service.setTrust(keyID: fingerprint, trustLevel: .full)
            let fullTrust = try await service.checkTrust(keyID: fingerprint)
            #expect(fullTrust == .full)

            let exportedOwnerTrust = try await service.exportOwnerTrust()
            #expect(!exportedOwnerTrust.isEmpty)

            try await service.setTrust(keyID: fingerprint, trustLevel: .none)
            let noneTrust = try await service.checkTrust(keyID: fingerprint)
            #expect(noneTrust != .full)

            let ownerTrustFileURL = tempDir.appendingPathComponent("ownertrust.txt")
            try exportedOwnerTrust.write(to: ownerTrustFileURL, options: .atomic)
            try await service.importOwnerTrust(from: ownerTrustFileURL)

            let restoredTrust = try await service.checkTrust(keyID: fingerprint)
            #expect(restoredTrust == .full)
        } catch {
            if let fingerprintToCleanup {
                await cleanupKey(fingerprint: fingerprintToCleanup, service: service)
            }
            throw error
        }

        if let fingerprintToCleanup {
            await cleanupKey(fingerprint: fingerprintToCleanup, service: service)
        }
    }

    @Test("Revocation certificate lifecycle supports generate and import")
    func revocationCertificate_generateAndImport() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "revocation-lifecycle")
        let tempDir = try makeTempDirectory(label: "revocation-lifecycle")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .rsa2048,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            let revocationData = try await service.generateRevocationCertificate(
                keyID: fingerprint,
                reason: .keyCompromised,
                description: "integration test revocation",
                passphrase: identity.passphrase
            )
            #expect(!revocationData.isEmpty)
            let armorText = String(data: revocationData, encoding: .utf8) ?? ""
            #expect(armorText.contains("BEGIN PGP PUBLIC KEY BLOCK"))

            let revocationURL = tempDir.appendingPathComponent("revocation.asc")
            try revocationData.write(to: revocationURL, options: .atomic)
            try await service.importRevocationCertificate(from: revocationURL)
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

    @Test("Revocation generate wrong passphrase maps to localized invalid passphrase message")
    func revocationGenerate_wrongPassphrase_mapsToLocalizedMessage() async throws {
        let service = GPGService.shared
        try await waitForServiceReady(service)

        let identity = makeIdentity(seed: "revocation-wrong-passphrase")
        var generatedFingerprint: String?

        do {
            let fingerprint = try await service.generateKey(
                name: identity.name,
                email: identity.email,
                keyType: .rsa2048,
                passphrase: identity.passphrase
            )
            generatedFingerprint = fingerprint

            do {
                _ = try await service.generateRevocationCertificate(
                    keyID: fingerprint,
                    reason: .keyCompromised,
                    description: "wrong passphrase check",
                    passphrase: "wrong-\(identity.passphrase)"
                )
                Issue.record("Expected invalid passphrase error")
            } catch {
                let mapped = UserFacingErrorMapper.message(for: error, context: .keyEdit)
                #expect(mapped == AppLocalization.string("error_invalid_passphrase"))
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
