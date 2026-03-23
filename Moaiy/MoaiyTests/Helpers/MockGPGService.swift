//
//  MockGPGService.swift
//  MoaiyTests
//
//  Mock GPGService for unit testing
//

import Foundation
@testable import Moaiy

/// Mock implementation of GPGService for testing
/// Note: Not marked as @MainActor to allow flexible usage in tests
final class MockGPGService: @unchecked Sendable {
    
    // MARK: - Thread Safety
    
    private let lock = NSLock()
    
    // MARK: - Configuration
    
    /// Whether the service is ready
    var isReady: Bool = true
    
    /// GPG version string
    var gpgVersion: String = "gpg (GnuPG) 2.4.0"
    
    // MARK: - Stubbed Results
    
    /// Keys to return from listKeys
    var stubbedKeys: [GPGKey] = []
    
    /// Secret keys to return from listKeys(secretOnly: true)
    var stubbedSecretKeys: [GPGKey] = []
    
    /// Error to throw from any operation
    var stubbedError: Error?
    
    /// Fingerprint to return from generateKey
    var stubbedGeneratedFingerprint: String = "GENERATED_FINGERPRINT_ABC123"
    
    /// Result to return from importKey
    var stubbedImportResult: KeyImportResult = KeyImportResult(imported: 1, unchanged: 0, newKeyIDs: ["NEW_KEY_ID"])
    
    /// Data to return from export operations
    var stubbedExportData: Data = "-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest\n-----END PGP PUBLIC KEY BLOCK-----".data(using: .utf8)!
    
    /// Trust level to return from checkTrust
    var stubbedTrustLevel: TrustLevel = .unknown
    
    /// Trust details to return from getTrustDetails
    var stubbedTrustDetails: KeyTrustDetails?
    
    /// Verification result to return from verify
    var stubbedVerificationResult: VerificationResult = VerificationResult(isValid: true, signerKeyID: nil, timestamp: nil)
    
    // MARK: - Call Tracking
    
    /// Track which methods were called
    var listKeysCallCount = 0
    var generateKeyCallCount = 0
    var importKeyCallCount = 0
    var exportPublicKeyCallCount = 0
    var exportSecretKeyCallCount = 0
    var deleteKeyCallCount = 0
    var checkTrustCallCount = 0
    var setTrustCallCount = 0
    var signKeyCallCount = 0
    var updateTrustDBCallCount = 0
    
    /// Track arguments passed to methods
    var lastListKeysSecretOnly: Bool?
    var lastGenerateKeyParams: (name: String, email: String, keyType: KeyType, passphrase: String?)?
    var lastImportFileURL: URL?
    var lastExportKeyID: String?
    var lastDeleteKeyID: String?
    var lastDeleteSecret: Bool?
    var lastSetTrustLevel: TrustLevel?
    
    // MARK: - Reset
    
    /// Reset all stubbed values and call counts
    func reset() {
        isReady = true
        gpgVersion = "gpg (GnuPG) 2.4.0"
        stubbedKeys = []
        stubbedSecretKeys = []
        stubbedError = nil
        stubbedGeneratedFingerprint = "GENERATED_FINGERPRINT_ABC123"
        stubbedImportResult = KeyImportResult(imported: 1, unchanged: 0, newKeyIDs: ["NEW_KEY_ID"])
        stubbedExportData = "-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest\n-----END PGP PUBLIC KEY BLOCK-----".data(using: .utf8)!
        stubbedTrustLevel = .unknown
        stubbedTrustDetails = nil
        
        listKeysCallCount = 0
        generateKeyCallCount = 0
        importKeyCallCount = 0
        exportPublicKeyCallCount = 0
        exportSecretKeyCallCount = 0
        deleteKeyCallCount = 0
        checkTrustCallCount = 0
        setTrustCallCount = 0
        signKeyCallCount = 0
        updateTrustDBCallCount = 0
        
        lastListKeysSecretOnly = nil
        lastGenerateKeyParams = nil
        lastImportFileURL = nil
        lastExportKeyID = nil
        lastDeleteKeyID = nil
        lastDeleteSecret = nil
        lastSetTrustLevel = nil
    }
    
    // MARK: - Mock Methods
    
    /// Mock listKeys
    func listKeys(secretOnly: Bool = false) async throws -> [GPGKey] {
        listKeysCallCount += 1
        lastListKeysSecretOnly = secretOnly
        
        if let error = stubbedError {
            throw error
        }
        
        return secretOnly ? stubbedSecretKeys : stubbedKeys
    }
    
    /// Mock generateKey
    func generateKey(name: String, email: String, keyType: KeyType, passphrase: String?) async throws -> String {
        generateKeyCallCount += 1
        lastGenerateKeyParams = (name, email, keyType, passphrase)
        
        if let error = stubbedError {
            throw error
        }
        
        return stubbedGeneratedFingerprint
    }
    
    /// Mock importKey
    func importKey(from url: URL) async throws -> KeyImportResult {
        importKeyCallCount += 1
        lastImportFileURL = url
        
        if let error = stubbedError {
            throw error
        }
        
        return stubbedImportResult
    }
    
    /// Mock exportPublicKey
    func exportPublicKey(keyID: String, armor: Bool = true) async throws -> Data {
        exportPublicKeyCallCount += 1
        lastExportKeyID = keyID
        
        if let error = stubbedError {
            throw error
        }
        
        return stubbedExportData
    }
    
    /// Mock exportSecretKey
    func exportSecretKey(keyID: String, passphrase: String, armor: Bool = true) async throws -> Data {
        exportSecretKeyCallCount += 1
        lastExportKeyID = keyID
        
        if let error = stubbedError {
            throw error
        }
        
        return stubbedExportData
    }
    
    /// Mock deleteKey
    func deleteKey(keyID: String, secret: Bool = false) async throws {
        deleteKeyCallCount += 1
        lastDeleteKeyID = keyID
        lastDeleteSecret = secret
        
        if let error = stubbedError {
            throw error
        }
    }
    
    /// Mock checkTrust
    func checkTrust(keyID: String) async throws -> TrustLevel {
        checkTrustCallCount += 1
        lastExportKeyID = keyID
        
        if let error = stubbedError {
            throw error
        }
        
        return stubbedTrustLevel
    }
    
    /// Mock setTrust
    func setTrust(keyID: String, trustLevel: TrustLevel) async throws {
        setTrustCallCount += 1
        lastExportKeyID = keyID
        lastSetTrustLevel = trustLevel
        
        if let error = stubbedError {
            throw error
        }
    }
    
    /// Mock signKey
    func signKey(keyID: String, signerKeyID: String?, passphrase: String, trustLevel: TrustLevel?) async throws {
        signKeyCallCount += 1
        
        if let error = stubbedError {
            throw error
        }
    }
    
    /// Mock updateTrustDB
    func updateTrustDB() async throws {
        updateTrustDBCallCount += 1
        
        if let error = stubbedError {
            throw error
        }
    }
    
    /// Mock getTrustDetails
    func getTrustDetails(keyID: String) async throws -> KeyTrustDetails {
        if let error = stubbedError {
            throw error
        }
        
        return stubbedTrustDetails ?? KeyTrustDetails(
            keyID: keyID,
            ownerTrust: stubbedTrustLevel,
            calculatedTrust: stubbedTrustLevel,
            signatureCount: 0
        )
    }
}
