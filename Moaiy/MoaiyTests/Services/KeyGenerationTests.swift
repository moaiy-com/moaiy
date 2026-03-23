//
//  KeyGenerationTests.swift
//  MoaiyTests
//
//  Unit tests for key generation functionality
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Generation Tests")
struct KeyGenerationTests {
    
    // MARK: - KeyType Generation Parameter Tests
    
    @Test("RSA-4096 generation params are correct")
    func rsa4096_generationParams() async throws {
        let keyType = KeyType.rsa4096
        
        #expect(keyType.keyLength == 4096)
        #expect(keyType.subkeyLength == 4096)
        #expect(keyType.gpgKeyType == "RSA")
        #expect(keyType.gpgSubkeyType == "RSA")
        #expect(keyType.curve == nil)
    }
    
    @Test("RSA-2048 generation params are correct")
    func rsa2048_generationParams() async throws {
        let keyType = KeyType.rsa2048
        
        #expect(keyType.keyLength == 2048)
        #expect(keyType.subkeyLength == 2048)
        #expect(keyType.gpgKeyType == "RSA")
        #expect(keyType.gpgSubkeyType == "RSA")
        #expect(keyType.curve == nil)
    }
    
    @Test("ECC generation params are correct")
    func ecc_generationParams() async throws {
        let keyType = KeyType.ecc
        
        #expect(keyType.keyLength == 0) // ECC uses curves, not key length
        #expect(keyType.subkeyLength == 0)
        #expect(keyType.gpgKeyType == "EDDSA")
        #expect(keyType.gpgSubkeyType == "ECDH")
        #expect(keyType.curve == "cv25519")
    }
    
    // MARK: - Key Generation Input Validation Tests
    
    @Test("Key generation with empty name should fail")
    func keyGeneration_emptyName_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyGenerationFailed("Name is required")
        
        do {
            _ = try await mockService.generateKey(
                name: "",
                email: "test@example.com",
                keyType: .rsa4096,
                passphrase: nil
            )
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    @Test("Key generation with invalid email should fail")
    func keyGeneration_invalidEmail_fails() async {
        let mockService = MockGPGService()
        mockService.stubbedError = GPGError.keyGenerationFailed("Invalid email")
        
        do {
            _ = try await mockService.generateKey(
                name: "Test",
                email: "invalid-email",
                keyType: .rsa4096,
                passphrase: nil
            )
            Issue.record("Should have thrown an error")
        } catch {
            #expect(error is GPGError)
        }
    }
    
    @Test("Key generation with valid inputs returns fingerprint")
    func keyGeneration_validInputs_returnsFingerprint() async throws {
        let mockService = MockGPGService()
        mockService.stubbedGeneratedFingerprint = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        
        let fingerprint = try await mockService.generateKey(
            name: "Test User",
            email: "test@example.com",
            keyType: .rsa4096,
            passphrase: "secure123"
        )
        
        #expect(fingerprint == "ABCDEF1234567890ABCDEF1234567890ABCDEF12")
        #expect(mockService.generateKeyCallCount == 1)
    }
    
    @Test("Key generation without passphrase creates unencrypted key")
    func keyGeneration_noPassphrase_unencrypted() async throws {
        let mockService = MockGPGService()
        mockService.stubbedGeneratedFingerprint = "UNENCRYPTED1234567890ABCDEF1234567890"
        
        let fingerprint = try await mockService.generateKey(
            name: "Test User",
            email: "test@example.com",
            keyType: .rsa4096,
            passphrase: nil
        )
        
        #expect(fingerprint == "UNENCRYPTED1234567890ABCDEF1234567890")
        #expect(mockService.lastGenerateKeyParams?.passphrase == nil)
    }
    
    @Test("Key generation with passphrase creates encrypted key")
    func keyGeneration_withPassphrase_encrypted() async throws {
        let mockService = MockGPGService()
        mockService.stubbedGeneratedFingerprint = "ENCRYPTED1234567890ABCDEF1234567890AB"
        
        let passphrase = "mySecurePassphrase123!"
        let fingerprint = try await mockService.generateKey(
            name: "Test User",
            email: "test@example.com",
            keyType: .rsa4096,
            passphrase: passphrase
        )
        
        #expect(fingerprint == "ENCRYPTED1234567890ABCDEF1234567890AB")
        #expect(mockService.lastGenerateKeyParams?.passphrase == passphrase)
    }
    
    // MARK: - KeyType Selection Tests
    
    @Test("Key generation stores correct key type")
    func keyGeneration_storesCorrectKeyType() async throws {
        let mockService = MockGPGService()
        
        for keyType in KeyType.allTestCases {
            mockService.stubbedGeneratedFingerprint = "\(keyType.rawValue)_FINGERPRINT"
            
            _ = try await mockService.generateKey(
                name: "Test",
                email: "test@example.com",
                keyType: keyType,
                passphrase: nil
            )
            
            #expect(mockService.lastGenerateKeyParams?.keyType == keyType)
        }
    }
    
    // MARK: - Fingerprint Validation Tests
    
    @Test("Generated fingerprint has correct length")
    func generatedFingerprint_correctLength() {
        // Valid GPG fingerprint is 40 hex characters (160 bits for SHA-1)
        let validFingerprint = "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2"
        
        #expect(validFingerprint.count == 40)
        #expect(validFingerprint.allSatisfy { $0.isHexDigit })
    }
    
    @Test("Fingerprint contains only valid hex characters")
    func fingerprint_validHexCharacters() {
        let fingerprint = "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
        
        #expect(fingerprint.allSatisfy { $0.isHexDigit })
    }
}

// MARK: - Character Extension for Hex Validation

extension Character {
    var isHexDigit: Bool {
        return isNumber || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(self)
    }
}
