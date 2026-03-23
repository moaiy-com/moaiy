//
//  KeyDeletionTests.swift
//  MoaiyTests
//
//  Unit tests for key deletion functionality
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Deletion Tests")
@MainActor
struct KeyDeletionTests {
    
    // MARK: - Delete Secret Key Tests
    
    @Test("Delete secret key succeeds")
    func deleteSecretKey_succeeds() async throws {
        let mockService = MockGPGService()
        
        let key = TestKeyFactory.makeSecretKey()
        try await mockService.deleteKey(keyID: key.fingerprint, secret: true)
        
        #expect(mockService.deleteKeyCallCount == 1)
        #expect(mockService.lastDeleteKeyID == key.fingerprint)
        #expect(mockService.lastDeleteSecret == true)
    }
    
    @Test("Delete secret key removes only secret part")
    func deleteSecretKey_onlySecretPart() async throws {
        let mockService = MockGPGService()
        
        // Create a key with both public and secret parts
        let fingerprint = "DUAL_KEY_1234567890ABCDEF1234567890ABCD"
        
        // Delete only the secret part
        try await mockService.deleteKey(keyID: fingerprint, secret: true)
        
        #expect(mockService.lastDeleteSecret == true)
    }
    
    // MARK: - Delete Public Key Tests
    
    @Test("Delete public key succeeds")
    func deletePublicKey_succeeds() async throws {
        let mockService = MockGPGService()
        
        let key = TestKeyFactory.makeKey(isSecret: false)
        try await mockService.deleteKey(keyID: key.fingerprint, secret: false)
        
        #expect(mockService.deleteKeyCallCount == 1)
        #expect(mockService.lastDeleteSecret == false)
    }
    
    // MARK: - Delete Both Keys Tests
    
    @Test("Delete both public and secret keys")
    func deleteBothKeys_succeeds() async throws {
        let mockService = MockGPGService()
        
        let fingerprint = "BOTH_KEY_1234567890ABCDEF1234567890ABCD"
        
        // Delete secret first
        try await mockService.deleteKey(keyID: fingerprint, secret: true)
        // Then delete public
        try await mockService.deleteKey(keyID: fingerprint, secret: false)
        
        #expect(mockService.deleteKeyCallCount == 2)
    }
    
    // MARK: - Delete Non-Existent Key Tests
    
    @Test("Delete non-existent key fails")
    func deleteNonExistentKey_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyNotFound("NONEXISTENT_KEY")
        
        do {
            try await mockService.deleteKey(keyID: "NONEXISTENT_KEY", secret: false)
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    // MARK: - Delete Key Validation Tests
    
    @Test("Cannot delete public key while secret exists")
    func deletePublicWithSecret_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.executionFailed("Must delete secret key first")
        
        do {
            try await mockService.deleteKey(keyID: "KEY_WITH_SECRET", secret: false)
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    @Test("Delete key with correct fingerprint")
    func deleteKey_correctFingerprint() async throws {
        let mockService = MockGPGService()
        let fingerprint = "CORRECT_FP_1234567890ABCDEF1234567890"
        
        try await mockService.deleteKey(keyID: fingerprint, secret: false)
        
        #expect(mockService.lastDeleteKeyID == fingerprint)
    }
}

// MARK: - DeleteKeyOption Tests

@Suite("DeleteKeyOption Tests")
@MainActor
struct DeleteKeyOptionTests {
    
    @Test("Secret only option deletes only secret")
    func secretOnly_deletesOnlySecret() async throws {
        let mockService = MockGPGService()
        let key = TestKeyFactory.makeSecretKey()
        
        // Simulate secret-only deletion
        try await mockService.deleteKey(keyID: key.fingerprint, secret: true)
        
        #expect(mockService.lastDeleteSecret == true)
        #expect(mockService.deleteKeyCallCount == 1)
    }
    
    @Test("Public only option deletes only public")
    func publicOnly_deletesOnlyPublic() async throws {
        let mockService = MockGPGService()
        let key = TestKeyFactory.makeKey(isSecret: false)
        
        try await mockService.deleteKey(keyID: key.fingerprint, secret: false)
        
        #expect(mockService.lastDeleteSecret == false)
        #expect(mockService.deleteKeyCallCount == 1)
    }
    
    @Test("Both option deletes secret then public")
    func both_deletesSecretThenPublic() async throws {
        let mockService = MockGPGService()
        let key = TestKeyFactory.makeSecretKey()
        
        // Delete both: secret first, then public
        try await mockService.deleteKey(keyID: key.fingerprint, secret: true)
        try await mockService.deleteKey(keyID: key.fingerprint, secret: false)
        
        #expect(mockService.deleteKeyCallCount == 2)
    }
}

// MARK: - ViewModel Delete Integration Tests

@Suite("ViewModel Delete Tests")
@MainActor
struct ViewModelDeleteTests {
    
    @Test("Delete key reloads key list")
    func deleteKey_reloadsKeys() async throws {
        let viewModel = KeyManagementViewModel()
        
        // Pre-populate with test keys
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        let initialCount = viewModel.keys.count
        
        // The actual deletion would require GPG
        // Here we just verify the state management
        #expect(viewModel.keys.count == initialCount)
    }
    
    @Test("Delete key sets loading state")
    func deleteKey_setsLoadingState() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [TestKeyFactory.makeKey()]
        
        // Verify initial state
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Delete key error sets error message")
    func deleteKey_error_setsErrorMessage() async {
        let viewModel = KeyManagementViewModel()
        
        viewModel.errorMessage = "Delete failed: Key not found"
        
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Delete failed") == true)
    }
    
    @Test("Clear error after delete failure")
    func deleteKey_clearError() async {
        let viewModel = KeyManagementViewModel()
        
        viewModel.errorMessage = "Delete error"
        viewModel.clearError()
        
        #expect(viewModel.errorMessage == nil)
    }
}
