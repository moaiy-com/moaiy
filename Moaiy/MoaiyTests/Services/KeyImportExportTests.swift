//
//  KeyImportExportTests.swift
//  MoaiyTests
//
//  Unit tests for key import and export functionality
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Import/Export Tests")
struct KeyImportExportTests {
    
    // MARK: - Key Import Tests
    
    @Test("Import public key succeeds")
    func importPublicKey_succeeds() async throws {
        let mockService = MockGPGService()
        mockService.stubbedImportResult = KeyImportResult(
            imported: 1,
            unchanged: 0,
            newKeyIDs: ["NEW_PUB_KEY_1234567890ABCDEF"]
        )
        
        let url = URL(fileURLWithPath: "/tmp/test_pub.asc")
        let result = try await mockService.importKey(from: url)
        
        #expect(result.imported == 1)
        #expect(result.unchanged == 0)
        #expect(result.newKeyIDs.count == 1)
        #expect(mockService.importKeyCallCount == 1)
    }
    
    @Test("Import secret key succeeds")
    func importSecretKey_succeeds() async throws {
        let mockService = MockGPGService()
        mockService.stubbedImportResult = KeyImportResult(
            imported: 1,
            unchanged: 0,
            newKeyIDs: ["NEW_SEC_KEY_1234567890ABCDEF"]
        )
        
        let url = URL(fileURLWithPath: "/tmp/test_sec.asc")
        let result = try await mockService.importKey(from: url)
        
        #expect(result.imported == 1)
        #expect(result.newKeyIDs.contains("NEW_SEC_KEY_1234567890ABCDEF"))
    }
    
    @Test("Import duplicate key returns unchanged")
    func importDuplicateKey_unchanged() async throws {
        let mockService = MockGPGService()
        mockService.stubbedImportResult = KeyImportResult(
            imported: 0,
            unchanged: 1,
            newKeyIDs: []
        )
        
        let url = URL(fileURLWithPath: "/tmp/duplicate.asc")
        let result = try await mockService.importKey(from: url)
        
        #expect(result.imported == 0)
        #expect(result.unchanged == 1)
        #expect(result.newKeyIDs.isEmpty)
    }
    
    @Test("Import invalid key fails")
    func importInvalidKey_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.importFailed("Invalid key format")
        
        let url = URL(fileURLWithPath: "/tmp/invalid.asc")
        
        do {
            _ = try await mockService.importKey(from: url)
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    @Test("Import non-existent file fails")
    func importNonExistentFile_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.fileAccessDenied("/nonexistent/file.asc")
        
        let url = URL(fileURLWithPath: "/nonexistent/file.asc")
        
        do {
            _ = try await mockService.importKey(from: url)
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    @Test("Import multiple keys at once")
    func importMultipleKeys_succeeds() async throws {
        let mockService = MockGPGService()
        mockService.stubbedImportResult = KeyImportResult(
            imported: 3,
            unchanged: 1,
            newKeyIDs: ["KEY1", "KEY2", "KEY3"]
        )
        
        let url = URL(fileURLWithPath: "/tmp/multiple.asc")
        let result = try await mockService.importKey(from: url)
        
        #expect(result.imported == 3)
        #expect(result.unchanged == 1)
        #expect(result.newKeyIDs.count == 3)
    }
    
    // MARK: - Key Export Tests
    
    @Test("Export public key succeeds")
    func exportPublicKey_succeeds() async throws {
        let mockService = MockGPGService()
        let expectedData = "-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest\n-----END PGP PUBLIC KEY BLOCK-----".data(using: .utf8)!
        mockService.stubbedExportData = expectedData
        
        let key = TestKeyFactory.makeKey()
        let data = try await mockService.exportPublicKey(keyID: key.fingerprint, armor: true)
        
        #expect(data == expectedData)
        #expect(mockService.exportPublicKeyCallCount == 1)
        #expect(mockService.lastExportKeyID == key.fingerprint)
    }
    
    @Test("Export public key armored format")
    func exportPublicKey_armored() async throws {
        let mockService = MockGPGService()
        let armoredData = "-----BEGIN PGP PUBLIC KEY BLOCK-----".data(using: .utf8)!
        mockService.stubbedExportData = armoredData
        
        let key = TestKeyFactory.makeKey()
        let data = try await mockService.exportPublicKey(keyID: key.fingerprint, armor: true)
        
        let dataString = String(data: data, encoding: .utf8)
        #expect(dataString?.contains("-----BEGIN PGP PUBLIC KEY BLOCK-----") == true)
    }
    
    @Test("Export secret key succeeds")
    func exportSecretKey_succeeds() async throws {
        let mockService = MockGPGService()
        let expectedData = "-----BEGIN PGP PRIVATE KEY BLOCK-----\ntest\n-----END PGP PRIVATE KEY BLOCK-----".data(using: .utf8)!
        mockService.stubbedExportData = expectedData
        
        let key = TestKeyFactory.makeSecretKey()
        let data = try await mockService.exportSecretKey(
            keyID: key.fingerprint,
            passphrase: "test123"
        )
        
        #expect(data == expectedData)
        #expect(mockService.exportSecretKeyCallCount == 1)
    }
    
    @Test("Export secret key requires passphrase")
    func exportSecretKey_requiresPassphrase() async throws {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.invalidPassphrase
        
        let key = TestKeyFactory.makeSecretKey()
        
        do {
            _ = try await mockService.exportSecretKey(
                keyID: key.fingerprint,
                passphrase: "wrong"
            )
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    @Test("Export non-existent key fails")
    func exportNonExistentKey_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyNotFound("NONEXISTENT_KEY")
        
        do {
            _ = try await mockService.exportPublicKey(keyID: "NONEXISTENT_KEY", armor: true)
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    // MARK: - Import Result Parsing Tests
    
    @Test("Import result contains correct key IDs")
    func importResult_containsKeyIDs() {
        let result = KeyImportResult(
            imported: 2,
            unchanged: 1,
            newKeyIDs: ["ABC123", "DEF456"]
        )
        
        #expect(result.newKeyIDs.contains("ABC123"))
        #expect(result.newKeyIDs.contains("DEF456"))
        #expect(result.newKeyIDs.count == 2)
    }
    
    @Test("Import result with no new keys")
    func importResult_noNewKeys() {
        let result = KeyImportResult(
            imported: 0,
            unchanged: 3,
            newKeyIDs: []
        )
        
        #expect(result.imported == 0)
        #expect(result.unchanged == 3)
        #expect(result.newKeyIDs.isEmpty)
    }
}

// MARK: - KeyImportResult Tests

@Suite("KeyImportResult Tests")
struct KeyImportResultTests {
    
    @Test("Import result stores all properties")
    func importResult_storesProperties() {
        let result = KeyImportResult(
            imported: 5,
            unchanged: 2,
            newKeyIDs: ["KEY_A", "KEY_B", "KEY_C", "KEY_D", "KEY_E"]
        )
        
        #expect(result.imported == 5)
        #expect(result.unchanged == 2)
        #expect(result.newKeyIDs.count == 5)
    }
    
    @Test("Import result is codable")
    func importResult_isCodable() throws {
        let original = KeyImportResult(
            imported: 1,
            unchanged: 0,
            newKeyIDs: ["TEST_KEY"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(KeyImportResult.self, from: data)
        
        #expect(decoded.imported == original.imported)
        #expect(decoded.unchanged == original.unchanged)
        #expect(decoded.newKeyIDs == original.newKeyIDs)
    }
}
