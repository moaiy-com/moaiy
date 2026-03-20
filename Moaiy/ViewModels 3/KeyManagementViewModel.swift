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
    private var cancellables = Set<AnyCancellable>()
    
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
        loadKeys()
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
                    // Update existing key to mark as secret
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
    /// - Parameters:
    ///   - name: User's name
    ///   - email: User's email
    ///   - keyType: Key type (RSA-4096, RSA-2048, ECC)
    ///   - passphrase: Optional passphrase
    /// - Returns: Fingerprint of the generated key
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
            
            // Reload keys after generation
            await loadKeys()
            
            return fingerprint
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Key Import/Export
    
    /// Import a key from file or text
    /// - Parameter keyData: Key data (ASCII armored or binary)
    /// - Returns: Import result
    @discardableResult
    func importKey(_ keyData: Data) async throws -> KeyImportResult {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await gpgService.importKey(keyData)
            await loadKeys()
            return result
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Import a key from file URL
    /// - Parameter url: File URL
    /// - Returns: Import result
    @discardableResult
    func importKey(from url: URL) async throws -> KeyImportResult {
        isLoading = true
        errorMessage = nil
        
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw GPGError.fileAccessDenied(url.path)
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            let data = try Data(contentsOf: url)
            return try await importKey(data)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Export a public key
    /// - Parameter key: Key to export
    /// - Returns: ASCII armored key data
    func exportPublicKey(_ key: GPGKey) async throws -> Data {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await gpgService.exportKey(key.fingerprint, secret: false)
            isLoading = false
            return data
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    /// Export a secret key
    /// - Parameter key: Key to export
    /// - Returns: ASCII armored key data
    func exportSecretKey(_ key: GPGKey, passphrase: String? = nil) async throws -> Data {
        guard key.isSecret else {
            throw GPGError.keyNotFound("Secret key for \(key.fingerprint)")
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await gpgService.exportKey(key.fingerprint, secret: true)
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
    /// - Parameter key: Key to delete
    func deleteKey(_ key: GPGKey) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await gpgService.deleteKey(key.fingerprint, secret: key.isSecret)
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Key Search
    
    /// Find a key by fingerprint
    /// - Parameter fingerprint: Key fingerprint
    /// - Returns: Key if found
    func findKey(byFingerprint fingerprint: String) -> GPGKey? {
        keys.first { $0.fingerprint == fingerprint }
    }
    
    /// Find a key by email
    /// - Parameter email: Email address
    /// - Returns: First matching key
    func findKey(byEmail email: String) -> GPGKey? {
        keys.first { $0.email.localizedCaseInsensitiveCompare(email) == .orderedSame }
    }
    
    // MARK: - Helpers
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Refresh keys
    func refresh() async {
        await loadKeys()
    }
}
