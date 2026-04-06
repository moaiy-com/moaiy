//
//  BackupIntegrityVerifierTests.swift
//  MoaiyTests
//
//  Unit tests for backup manifest integrity validation.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Backup Integrity Verifier Tests")
struct BackupIntegrityVerifierTests {

    @Test("Manifest v1.1 rejects file hash mismatch")
    func manifestV11_rejectsHashMismatch() throws {
        let tempDir = try makeTempDirectory(label: "hash-mismatch")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileName = "ABCDEF1234567890ABCDEF1234567890ABCDEF12_public.asc"
        let fileURL = tempDir.appendingPathComponent(fileName)
        let payload = Data("public-key-data".utf8)
        try payload.write(to: fileURL, options: .atomic)

        let manifest = makeManifestV11(
            files: [
                BackupManifestFileEntry(
                    fileName: fileName,
                    sha256: BackupIntegrityVerifier.sha256Hex(for: Data("tampered".utf8)),
                    kind: .publicKey
                )
            ]
        )

        do {
            _ = try BackupIntegrityVerifier.validateImportableFiles(
                in: tempDir,
                manifest: manifest,
                maxFileSizeBytes: 1_024_000
            )
            Issue.record("Expected hash mismatch to be rejected")
        } catch BackupIntegrityError.fileHashMismatch {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Manifest v1.1 rejects extra asc files not listed in manifest")
    func manifestV11_rejectsExtraAscFiles() throws {
        let tempDir = try makeTempDirectory(label: "extra-file")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let listedName = "AAAABBBBCCCCDDDDEEEEFFFF0000111122223333_public.asc"
        let listedData = Data("listed".utf8)
        try listedData.write(to: tempDir.appendingPathComponent(listedName), options: .atomic)

        let extraName = "FFFFEEEEDDDDCCCCBBBB99998888777766665555_secret.asc"
        try Data("extra".utf8).write(to: tempDir.appendingPathComponent(extraName), options: .atomic)

        let manifest = makeManifestV11(
            files: [
                BackupManifestFileEntry(
                    fileName: listedName,
                    sha256: BackupIntegrityVerifier.sha256Hex(for: listedData),
                    kind: .publicKey
                )
            ]
        )

        do {
            _ = try BackupIntegrityVerifier.validateImportableFiles(
                in: tempDir,
                manifest: manifest,
                maxFileSizeBytes: 1_024_000
            )
            Issue.record("Expected extra asc file to be rejected")
        } catch BackupIntegrityError.fileSetMismatch {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Manifest v1.1 rejects symbolic links")
    func manifestV11_rejectsSymbolicLinks() throws {
        let tempDir = try makeTempDirectory(label: "symlink")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let targetData = Data("target-data".utf8)
        let targetURL = tempDir.appendingPathComponent("target.bin")
        try targetData.write(to: targetURL, options: .atomic)

        let linkName = "1234567890ABCDEF1234567890ABCDEF12345678_public.asc"
        let linkURL = tempDir.appendingPathComponent(linkName)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let manifest = makeManifestV11(
            files: [
                BackupManifestFileEntry(
                    fileName: linkName,
                    sha256: BackupIntegrityVerifier.sha256Hex(for: targetData),
                    kind: .publicKey
                )
            ]
        )

        do {
            _ = try BackupIntegrityVerifier.validateImportableFiles(
                in: tempDir,
                manifest: manifest,
                maxFileSizeBytes: 1_024_000
            )
            Issue.record("Expected symbolic link to be rejected")
        } catch BackupIntegrityError.unsafeFile {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Manifest v1.0 uses restricted legacy restore path")
    func manifestV10_usesRestrictedPath() throws {
        let tempDir = try makeTempDirectory(label: "legacy-path")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fingerprint = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        let allowedFile = "\(fingerprint)_public.asc"
        try Data("legacy-public".utf8).write(
            to: tempDir.appendingPathComponent(allowedFile),
            options: .atomic
        )

        // Non-asc files should be ignored by the whitelist logic.
        try Data("metadata".utf8).write(
            to: tempDir.appendingPathComponent("notes.txt"),
            options: .atomic
        )

        let manifest = BackupManifest(
            version: "1.0",
            created: Date(),
            keyCount: 1,
            includeSecretKeys: false,
            exportedPublicKeyCount: 1,
            exportedSecretKeyCount: 0,
            failedSecretKeyCount: 0,
            keys: [
                BackupKeyInfo(
                    fingerprint: fingerprint,
                    name: "Legacy User",
                    email: "legacy@example.com",
                    isSecret: false
                )
            ],
            files: nil,
            totalFiles: nil
        )

        let validation = try BackupIntegrityVerifier.validateImportableFiles(
            in: tempDir,
            manifest: manifest,
            maxFileSizeBytes: 1_024_000
        )

        #expect(validation.usedLegacyRestrictedPath == true)
        #expect(validation.files.count == 1)
        #expect(validation.files.first?.lastPathComponent == allowedFile)
    }

    @Test("Manifest v1.0 rejects unexpected asc files")
    func manifestV10_rejectsUnexpectedAscFiles() throws {
        let tempDir = try makeTempDirectory(label: "legacy-extra-asc")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fingerprint = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        let allowedFile = "\(fingerprint)_public.asc"
        try Data("legacy-public".utf8).write(
            to: tempDir.appendingPathComponent(allowedFile),
            options: .atomic
        )
        try Data("evil".utf8).write(
            to: tempDir.appendingPathComponent("BADBADBADBADBADBADBADBADBADBADBADBADBADB_public.asc"),
            options: .atomic
        )

        let manifest = BackupManifest(
            version: "1.0",
            created: Date(),
            keyCount: 1,
            includeSecretKeys: false,
            exportedPublicKeyCount: 1,
            exportedSecretKeyCount: 0,
            failedSecretKeyCount: 0,
            keys: [
                BackupKeyInfo(
                    fingerprint: fingerprint,
                    name: "Legacy User",
                    email: "legacy@example.com",
                    isSecret: false
                )
            ],
            files: nil,
            totalFiles: nil
        )

        do {
            _ = try BackupIntegrityVerifier.validateImportableFiles(
                in: tempDir,
                manifest: manifest,
                maxFileSizeBytes: 1_024_000
            )
            Issue.record("Expected unexpected asc file to be rejected")
        } catch BackupIntegrityError.fileSetMismatch {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Manifest v1.1 rejects non-whitelisted file names")
    func manifestV11_rejectsNonWhitelistedFileNames() throws {
        let tempDir = try makeTempDirectory(label: "filename-whitelist")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileName = "-evil.asc"
        let fileData = Data("payload".utf8)
        try fileData.write(to: tempDir.appendingPathComponent(fileName), options: .atomic)

        let manifest = makeManifestV11(
            files: [
                BackupManifestFileEntry(
                    fileName: fileName,
                    sha256: BackupIntegrityVerifier.sha256Hex(for: fileData),
                    kind: .publicKey
                )
            ]
        )

        do {
            _ = try BackupIntegrityVerifier.validateImportableFiles(
                in: tempDir,
                manifest: manifest,
                maxFileSizeBytes: 1_024_000
            )
            Issue.record("Expected non-whitelisted file name to be rejected")
        } catch BackupIntegrityError.invalidManifest {
            // Expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeManifestV11(files: [BackupManifestFileEntry]) -> BackupManifest {
        BackupManifest(
            version: "1.1",
            created: Date(),
            keyCount: files.count,
            includeSecretKeys: files.contains(where: { $0.kind == .secretKey }),
            exportedPublicKeyCount: files.filter { $0.kind == .publicKey }.count,
            exportedSecretKeyCount: files.filter { $0.kind == .secretKey }.count,
            failedSecretKeyCount: 0,
            keys: [],
            files: files,
            totalFiles: files.count
        )
    }

    private func makeTempDirectory(label: String) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("moaiy-backup-integrity-\(label)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
