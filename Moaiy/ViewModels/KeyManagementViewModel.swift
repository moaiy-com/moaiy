//
//  KeyManagementViewModel.swift
//  Moaiy
//
//  ViewModel for key management functionality
//

import Foundation
import Combine

@MainActor
@Observable
final class KeyManagementViewModel {
    
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
            await loadKeys()
        }
    }
    
    // MARK: - Key Loading
    
    /// Load all keys from GPG
    func loadKeys() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load both public and secret keys
            let publicKeys = try await gpgService.listKeys(secretOnly: false)
            let secretKeys = try await gpgService.listKeys(secretOnly: true)
            
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
                        expiresAt: secretKey.expiresAt
                    )
                } else {
                    allKeys.append(secretKey)
                }
            }
            
            keys = allKeys.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load keys: \(error)")
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
    
    // MARK: - Helpers
    
    func clearError() {
        errorMessage = nil
    }
    
    func refresh() async {
        await loadKeys()
    }
}
