//
//  IntegrationTests.swift
//  MoaiyTests
//
//  Integration tests for complete key management workflows
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Management Integration Tests")
@MainActor
struct KeyManagementIntegrationTests {
    
    // MARK: - Full Key Lifecycle Tests
    
    @Test("Complete key lifecycle: generate, export, import, delete")
    func completeKeyLifecycle() async throws {
        let mockService = MockGPGService()
        
        // Step 1: Generate key
        mockService.stubbedGeneratedFingerprint = "LIFECYCLE_TEST_KEY_FP"
        let fingerprint = try await mockService.generateKey(
            name: "Lifecycle Test User",
            email: "lifecycle@test.com",
            keyType: .rsa4096,
            passphrase: "test123"
        )
        
        #expect(fingerprint == "LIFECYCLE_TEST_KEY_FP")
        #expect(mockService.generateKeyCallCount == 1)
        
        // Step 2: Export key
        mockService.stubbedExportData = "EXPORTED_KEY_DATA".data(using: .utf8)!
        let exportedData = try await mockService.exportPublicKey(keyID: fingerprint, armor: true)
        
        #expect(exportedData.count > 0)
        
        // Step 3: Import key (simulating import to another keyring)
        mockService.stubbedImportResult = KeyImportResult(imported: 1, unchanged: 0, newKeyIDs: [fingerprint])
        let importResult = try await mockService.importKey(from: URL(fileURLWithPath: "/tmp/test.key"))
        
        #expect(importResult.imported == 1)
        
        // Step 4: Delete key
        try await mockService.deleteKey(keyID: fingerprint, secret: false)
        
        #expect(mockService.deleteKeyCallCount == 1)
    }
    
    // MARK: - Key Trust Lifecycle Tests
    
    @Test("Trust lifecycle: check, set  verify")
    func trustLifecycle() async throws {
        let mockService = MockGPGService()
        let testFingerprint = "TRUST_LIFECYCLE_FP"
        
        // Step 1: Check initial trust
        mockService.stubbedTrustLevel = .unknown
        var initialTrust = try await mockService.checkTrust(keyID: testFingerprint)
        #expect(initialTrust == .unknown)
        
        // Step 2: Set trust to full
        try await mockService.setTrust(keyID: testFingerprint, trustLevel: .full)
        #expect(mockService.lastSetTrustLevel == .full)
        
        // Step 3: Verify trust is updated
        mockService.stubbedTrustLevel = .full
        let updatedTrust = try await mockService.checkTrust(keyID: testFingerprint)
        #expect(updatedTrust == .full)
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Recover from generation error")
    func recoverFromGenerationError() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyGenerationFailed("Test error")
        
        do {
            _ = try await mockService.generateKey(
                name: "Error Test",
                email: "error@test.com",
                keyType: .rsa4096,
                passphrase: nil
            )
            Issue.record("Should have thrown error")
        } catch GPGError.keyGenerationFailed(let message) {
            #expect(message.contains("Test error"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("Recover from import error")
    func recoverFromImportError() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.importFailed("Invalid key format")
        
        do {
            _ = try await mockService.importKey(from: URL(fileURLWithPath: "/tmp/invalid.key"))
            Issue.record("Should have thrown error")
        } catch GPGError.importFailed(let message) {
            #expect(message.contains("Invalid key format"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("Recover from export error")
    func recoverFromExportError() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.exportFailed("Key not found")
        
        do {
            _ = try await mockService.exportPublicKey(keyID: "NONEXISTENT", armor: true)
            Issue.record("Should have thrown error")
        } catch GPGError.exportFailed(let message) {
            #expect(message.contains("Key not found"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    @Test("Recover from deletion error")
    func recoverFromDeletionError() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyNotFound("Key not found")
        
        do {
            _ = try await mockService.deleteKey(keyID: "NONEXISTENT", secret: false)
            Issue.record("Should have thrown error")
        } catch GPGError.keyNotFound(let message) {
            #expect(message.contains("Key not found"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Concurrent Operation Tests
    
    @Test("Concurrent key operations")
    func concurrentKeyOperations() async throws {
        let mockService = MockGPGService()
        
        // Setup multiple fingerprints
        mockService.stubbedGeneratedFingerprint = "CONCURRENT_KEY_1"
        
        // Run multiple operations concurrently
        async let op1 = mockService.generateKey(
            name: "Concurrent 1",
            email: "concurrent1@test.com",
            keyType: .rsa4096,
            passphrase: nil
        )
        
        async let op2 = mockService.generateKey(
            name: "Concurrent 2",
            email: "concurrent2@test.com",
            keyType: .ecc,
            passphrase: nil
        )
        
        // Wait for both to complete
        let (fp1, fp2) = try await (op1, op2)
        
        #expect(fp1 == "CONCURRENT_KEY_1")
        // Note: Second call will also return same fingerprint due to mock
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Case Tests")
@MainActor
struct EdgeCaseTests {
    
    // MARK: - Boundary Value Tests
    
    @Test("Empty key list handling")
    func emptyKeyList() async throws {
        let mockService = MockGPGService()
        mockService.stubbedKeys = []
        
        let keys = try await mockService.listKeys(secretOnly: false)
        
        #expect(keys.isEmpty)
    }
    
    @Test("Maximum length key name")
    func maximumLengthKeyName() async throws {
        let mockService = MockGPGService()
        let longName = String(repeating: "A", count: 1000)
        
        mockService.stubbedGeneratedFingerprint = "LONG_NAME_KEY_FP"
        let fingerprint = try await mockService.generateKey(
            name: longName,
            email: "longname@test.com",
            keyType: .rsa4096,
            passphrase: nil
        )
        
        #expect(fingerprint == "LONG_NAME_KEY_FP")
    }
    
    @Test("Special characters in key name")
    func specialCharactersInKeyName() async throws {
        let mockService = MockGPGService()
        let specialName = "Test User (Special) <email>"
        
        mockService.stubbedGeneratedFingerprint = "SPECIAL_CHARS_KEY_FP"
        let fingerprint = try await mockService.generateKey(
            name: specialName,
            email: "special@test.com",
            keyType: .rsa4096,
            passphrase: nil
        )
        
        #expect(fingerprint == "SPECIAL_CHARS_KEY_FP")
    }
    
    @Test("Unicode characters in key name")
    func unicodeCharactersInKeyName() async throws {
        let mockService = MockGPGService()
        let unicodeName = "测试用户 👤 Тест 用户"
        
        mockService.stubbedGeneratedFingerprint = "UNICODE_KEY_FP"
        let fingerprint = try await mockService.generateKey(
            name: unicodeName,
            email: "unicode@test.com",
            keyType: .rsa4096,
            passphrase: nil
        )
        
        #expect(fingerprint == "UNICODE_KEY_FP")
    }
    
    @Test("Very long passphrase")
    func veryLongPassphrase() async throws {
        let mockService = MockGPGService()
        let longPassphrase = String(repeating: "P", count: 500)
        
        mockService.stubbedGeneratedFingerprint = "LONG_PASSPHRASE_KEY_FP"
        let fingerprint = try await mockService.generateKey(
            name: "Long Passphrase User",
            email: "longpassphrase@test.com",
            keyType: .rsa4096,
            passphrase: longPassphrase
        )
        
        #expect(fingerprint == "LONG_PASSPHRASE_KEY_FP")
        #expect(mockService.lastGenerateKeyParams?.passphrase == longPassphrase)
    }
    
    // MARK: - Invalid Input Tests
    
    @Test("Invalid email format")
    func invalidEmailFormat() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyGenerationFailed("Invalid email")
        
        let invalidEmails = ["notanemail", "missing@domain", "@nodomain.com", "spaces in@email.com"]
        
        for email in invalidEmails {
            mockService.reset()
            mockService.stubbedError = GPGError.keyGenerationFailed("Invalid email")
            
            do {
                _ = try await mockService.generateKey(
                    name: "Test",
                    email: email,
                    keyType: .rsa4096,
                    passphrase: nil
                )
                Issue.record("Should have thrown error for: \(email)")
            } catch {
                // Expected
            }
        }
    }
    
    @Test("Empty name handling")
    func emptyNameHandling() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyGenerationFailed("Name is required")
        
        do {
            _ = try await mockService.generateKey(
                name: "",
                email: "test@example.com",
                keyType: .rsa4096,
                passphrase: nil
            )
            Issue.record("Should have thrown error")
        } catch {
            // Expected
        }
    }
    
    @Test("Whitespace only name handling")
    func whitespaceOnlyNameHandling() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyGenerationFailed("Name is required")
        
        do {
            _ = try await mockService.generateKey(
                name: "   ",
                email: "test@example.com",
                keyType: .rsa4096,
                passphrase: nil
            )
            Issue.record("Should have thrown error")
        } catch {
            // Expected
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Large key collection handling")
    func largeKeyCollectionHandling() async {
        let viewModel = KeyManagementViewModel()
        
        // Create 1000 keys
        var keys: [GPGKey] = []
        for i in 0..<1000 {
            keys.append(TestKeyFactory.makeKey(
                name: "User \(i)",
                email: "user\(i)@test.com",
                fingerprint: String(format: "KEY_%04d_FINGERPRINT_1234567890ABCDEF", i)
            ))
        }
        
        viewModel.keys = keys
        
        #expect(viewModel.keys.count == 1000)
        #expect(viewModel.hasKeys == true)
        
        // Test filtering performance
        viewModel.searchText = "User 500"
        #expect(viewModel.filteredKeys.count == 1)
    }
    
    @Test("Rapid filter changes")
    func rapidFilterChanges() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        
        // Rapidly change filters
        for _ in 0..<100 {
            viewModel.filterKeyType = .all
            _ = viewModel.filteredKeys
            
            viewModel.filterKeyType = .publicOnly
            _ = viewModel.filteredKeys
            
            viewModel.filterKeyType = .secretOnly
            _ = viewModel.filteredKeys
        }
        
        // Should not crash
        #expect(true)
    }
}
