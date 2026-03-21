//
//  KeyManagementViewModel.swift
//  Moaiy
//
//  ViewModel for key management functionality
//

import Foundation
import os.log

@MainActor
@Observable
final class KeyManagementViewModel {
    
    private let logger = Logger(subsystem: "com.moaiy.app", category: "KeyManagement")
    
    // MARK: - Published State
    
    var keys: [GPGKey] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""
    
    // MARK: - Private Properties
    
    private let gpgService = GPGService.shared
    
    // MARK: - Computed Properties
    
    var filteredKeys: [GPGKey] {
        if searchText.isEmpty {
            return keys
        }
        return keys.filter { key in
            key.name.localizedCaseInsensitiveContains(searchText) ||
            key.email.localizedCaseInsensitiveContains(searchText) ||
            key.fingerprint.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var publicKeys: [GPGKey] {
        keys.filter { !$0.isSecret }
    }
    
    var secretKeys: [GPGKey] {
        keys.filter { $0.isSecret }
    }
    
    var hasKeys: Bool {
        !keys.isEmpty
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            // Wait for GPGService to be ready
            while !gpgService.isReady {
                logger.debug("Waiting for GPGService to be ready...")
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            await loadKeys()
        }
    }
    
    // MARK: - Key Loading
    
    /// Load all keys from GPG
    func loadKeys() async {
        logger.info("Loading keys...")
        logger.info("GPGService.isReady = \(self.gpgService.isReady)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load both public and secret keys
            let publicKeys = try await gpgService.listKeys(secretOnly: false)
            logger.info("Loaded \(publicKeys.count) public keys")
            
            let secretKeys = try await gpgService.listKeys(secretOnly: true)
            logger.info("Loaded \(secretKeys.count) secret keys")
            
            // Merge keys, marking secret ones
            var allKeys = publicKeys
            for secretKey in secretKeys {
                if let index = allKeys.firstIndex(where: { $0.fingerprint == secretKey.fingerprint }) {
                    allKeys[index] = GPGKey(
                        id: secretKey.id,
                        keyID: secretKey.keyID,
                        fingerprint: secretKey.fingerprint,
                        name: secretKey.name,
                        email: secretKey.email,
                        algorithm: secretKey.algorithm,
                        keyLength: secretKey.keyLength,
                        isSecret: true,
                        createdAt: secretKey.createdAt,
                        expiresAt: secretKey.expiresAt,
                        trustLevel: secretKey.trustLevel
                    )
                } else {
                    allKeys.append(secretKey)
                }
            }
            
            keys = allKeys.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            logger.info("Total keys after merge: \(self.keys.count)")
            for key in keys {
                logger.info("Key: \(key.name) <\(key.email)> trust=\(key.trustLevel.displayName)")
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to load keys: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Key Generation
    
    /// Generate a new key pair
    @discardableResult
    func generateKey(name: String, email: String, keyType: KeyType, passphrase: String?) async throws -> String {
        isLoading = true
        errorMessage = nil
        
        do {
            let fingerprint = try await gpgService.generateKey(
                name: name,
                email: email,
                keyType: keyType,
                passphrase: passphrase
            )
            
            await loadKeys()
            return fingerprint
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Key Import/Export
    
    /// Import a key from file URL
    @discardableResult
    func importKey(from url: URL) async throws -> KeyImportResult {
        isLoading = true
        errorMessage = nil
        
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw GPGError.fileAccessDenied(url.path)
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            let result = try await gpgService.importKey(from: url)
            await loadKeys()
            return result
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Export a public key
    func exportPublicKey(_ key: GPGKey) async throws -> Data {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await gpgService.exportPublicKey(keyID: key.fingerprint, armor: true)
            isLoading = false
            return data
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Export a secret key
    func exportSecretKey(_ key: GPGKey, passphrase: String) async throws -> Data {
        guard key.isSecret else {
            throw GPGError.keyNotFound("Secret key for \(key.fingerprint)")
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await gpgService.exportSecretKey(keyID: key.fingerprint, passphrase: passphrase, armor: true)
            isLoading = false
            return data
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Key Deletion
    
    /// Delete a key
    func deleteKey(_ key: GPGKey) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await gpgService.deleteKey(keyID: key.fingerprint, secret: key.isSecret)
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Trust Management
    
    /// Check trust level for a key
    func checkTrust(for key: GPGKey) async -> TrustLevel {
        do {
            return try await gpgService.checkTrust(keyID: key.fingerprint)
        } catch {
            print("Failed to check trust: \(error)")
            return .unknown
        }
    }
    
    /// Set trust level for a key
    func setTrust(for key: GPGKey, trustLevel: TrustLevel) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await gpgService.setTrust(keyID: key.fingerprint, trustLevel: trustLevel)
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Get detailed trust information for a key
    func getTrustDetails(for key: GPGKey) async throws -> KeyTrustDetails {
        try await gpgService.getTrustDetails(keyID: key.fingerprint)
    }
    
    /// Sign a key to indicate trust
    /// - Parameters:
    ///   - keyToSign: The key to sign
    ///   - signerKey: Your key to sign with (nil for default)
    ///   - passphrase: Passphrase for signing key
    ///   - trustLevel: Optional trust level to set after signing
    func signKey(keyToSign: GPGKey, signerKey: GPGKey?, passphrase: String, trustLevel: TrustLevel? = nil) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await gpgService.signKey(
                keyID: keyToSign.fingerprint,
                signerKeyID: signerKey?.fingerprint,
                passphrase: passphrase,
                trustLevel: trustLevel
            )
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Update the trust database
    func updateTrustDB() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await gpgService.updateTrustDB()
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    func refresh() async {
        await loadKeys()
    }
}
