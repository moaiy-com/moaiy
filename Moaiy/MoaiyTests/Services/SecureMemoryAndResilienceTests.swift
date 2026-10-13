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
}
