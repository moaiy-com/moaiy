//
//  SecureMemoryAndResilienceTests.swift
//  MoaiyTests
//
//  Unit tests for memory zeroization (SecureBytes, SecureString)
//  and transient file lifecycle resilience.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Secure Memory and Resilience Tests")
struct SecureMemoryAndResilienceTests {

    @Test("SecureBytes stores payload and zeroizes memory on request")
    func secureBytes_storesPayload_andZeroizes() {
        let payload = "SecretPassphrase123!#"
        let secure = SecureBytes(utf8String: payload)
        #expect(secure.count == payload.utf8.count)
        #expect(!secure.isCleaned)

        var matched = false
        secure.withUnsafeBytes { rawBuffer in
            let extracted = String(decoding: rawBuffer, as: UTF8.self)
            matched = (extracted == payload)
        }
        #expect(matched)

        secure.zeroize()
        #expect(secure.isCleaned)
        #expect(secure.count == 0)
    }

    @Test("SecureString exposes string and zeroizes underlying representation")
    func secureString_exposesAndCleans() {
        let secret = "SuperConfidentialKey456"
        let secureStr = SecureString(secret)
        #expect(secureStr.revealString() == secret)
        #expect(!secureStr.isCleaned)

        secureStr.zeroize()
        #expect(secureStr.isCleaned)
        #expect(secureStr.revealString().isEmpty)
    }

    @Test("TransientFileRegistry tracks and purges registered temporary files")
    func transientFileRegistry_tracksAndPurgesFiles() throws {
        let registry = TransientFileRegistry.shared
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("transient-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let tempFile = tempDir.appendingPathComponent("transient.tmp")
        try Data("transient content".utf8).write(to: tempFile)
        #expect(fileManager.fileExists(atPath: tempFile.path))

        registry.register(url: tempFile)
        #expect(registry.trackedCount >= 1)

        let cleaned = registry.cleanupAll()
        #expect(cleaned >= 1)
        #expect(!fileManager.fileExists(atPath: tempFile.path))
    }

    @Test("SecureTempStorage.removeOperationDirectory unregisters directory from TransientFileRegistry")
    func secureTempStorage_removeOperationDirectory_unregistersAndDeletes() throws {
        let dir = try SecureTempStorage.makeOperationDirectory(prefix: "audit-scrub")
        let secretFile = dir.appendingPathComponent("secret.txt")
        try Data("sensitive plaintext payload".utf8).write(to: secretFile)

        let countBefore = TransientFileRegistry.shared.trackedCount
        #expect(countBefore >= 1)

        SecureTempStorage.removeOperationDirectory(dir)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
        #expect(TransientFileRegistry.shared.trackedCount == countBefore - 1)
    }

    @Test("GPGService.parseVerificationResult requires [GNUPG:] GOODSIG + VALIDSIG and rejects spoofed or revoked signals")
    func parseVerificationResult_strictlyEnforcesGNUPGStatus() {
        let validStatus = """
        [GNUPG:] GOODSIG 1122334455667788 Alice <alice@example.com>
        [GNUPG:] VALIDSIG AABBCCDDEEFF00112233445566778899AABBCCDD 2026-01-01 1767225600 0 4 0 22 8 00 AABBCCDDEEFF00112233445566778899AABBCCDD
        """
        let validResult = GPGService.parseVerificationResult(validStatus)
        #expect(validResult.isValid)
        #expect(validResult.signerKeyID == "1122334455667788")
        #expect(validResult.timestamp == Date(timeIntervalSince1970: 1767225600))

        let spoofedPlaintext = """
        GOODSIG 1122334455667788 Spoofed Signer
        VALIDSIG AABBCCDDEEFF00112233445566778899AABBCCDD 2026-01-01 1767225600
        """
        #expect(!GPGService.parseVerificationResult(spoofedPlaintext).isValid)

        let revokedStatus = """
        [GNUPG:] GOODSIG 1122334455667788 Alice <alice@example.com>
        [GNUPG:] REVKEYSIG 1122334455667788 Alice <alice@example.com>
        [GNUPG:] VALIDSIG AABBCCDDEEFF00112233445566778899AABBCCDD 2026-01-01 1767225600
        """
        #expect(!GPGService.parseVerificationResult(revokedStatus).isValid)

        let goodSigWithoutValidSig = "[GNUPG:] GOODSIG 1122334455667788 Alice <alice@example.com>"
        #expect(!GPGService.parseVerificationResult(goodSigWithoutValidSig).isValid)
    }

    @Test("BackupArchiveService creates and extracts ZIP archives without blocking")
    func backupArchiveService_zipRoundtrip_succeeds() async throws {
        let fileManager = FileManager.default
        let rootDir = try SecureTempStorage.makeOperationDirectory(prefix: "archive-test")
        defer { SecureTempStorage.removeOperationDirectory(rootDir) }

        let sourceDir = rootDir.appendingPathComponent("payload", isDirectory: true)
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let sampleFile = sourceDir.appendingPathComponent("manifest.json")
        let expectedData = Data("{\"version\":\"1.1\"}".utf8)
        try expectedData.write(to: sampleFile)

        let zipURL = rootDir.appendingPathComponent("backup.zip")
        try await BackupArchiveService.shared.createZipArchive(from: sourceDir, to: zipURL)
        #expect(fileManager.fileExists(atPath: zipURL.path))

        let extractDir = rootDir.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try await BackupArchiveService.shared.extractZipArchive(from: zipURL, to: extractDir)

        let restoredFile = extractDir.appendingPathComponent("payload/manifest.json")
        #expect(fileManager.fileExists(atPath: restoredFile.path))
        #expect(try Data(contentsOf: restoredFile) == expectedData)
    }
}
