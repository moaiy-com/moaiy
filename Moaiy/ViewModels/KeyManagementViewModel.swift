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
    var isSystemKeyringMigrationRunning = false

    // Filter options
    var filterKeyType: KeyTypeFilter = .all
    var filterTrustLevel: TrustLevel? = nil
    var filterAlgorithm: String? = nil
    var showExpiredKeys: Bool = true

    // Search history
    var searchHistory: [String] = []
    private let maxSearchHistory = Constants.UI.maxSearchHistory

    // Retry configuration
    private var retryCount = 0
    private let maxRetries = Constants.GPG.maxRetries
    private var retryTask: Task<Void, Never>?

    // Expiration reminder service
    let expirationReminder = ExpirationReminderService()
    
    // MARK: - Private Properties
    
    private let gpgService = GPGService.shared
    
    // MARK: - Computed Properties

    var filteredKeys: [GPGKey] {
        var result = keys

        // Text search
        if !searchText.isEmpty {
            result = result.filter { key in
                key.name.localizedCaseInsensitiveContains(searchText) ||
                key.email.localizedCaseInsensitiveContains(searchText) ||
                key.fingerprint.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Key type filter
        switch filterKeyType {
        case .all:
            break
        case .publicOnly:
            result = result.filter { !$0.isSecret }
        case .secretOnly:
            result = result.filter { $0.isSecret }
        }

        // Trust level filter
        if let trustLevel = filterTrustLevel {
            result = result.filter { $0.trustLevel == trustLevel }
        }

        // Algorithm filter
        if let algorithm = filterAlgorithm {
            result = result.filter { $0.algorithm.localizedCaseInsensitiveContains(algorithm) }
        }

        // Expired keys filter
        if !showExpiredKeys {
            result = result.filter { !$0.isExpired }
        }

        return result
    }

    var availableAlgorithms: [String] {
        let algorithms = Set(keys.map { $0.algorithm })
        return Array(algorithms).sorted()
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
            // Wait for GPGService readiness with a hard timeout to avoid infinite wait.
            let timeout: UInt64 = 15_000_000_000
            let interval: UInt64 = 100_000_000
            var elapsed: UInt64 = 0

            while !gpgService.isReady && elapsed < timeout {
                try? await Task.sleep(nanoseconds: interval)
                elapsed += interval
            }

            guard gpgService.isReady else {
                logger.error("GPGService readiness timed out")
                errorMessage = String(localized: "error_gpg_not_found")
                return
            }

            await loadKeys()
        }
    }
    
    // MARK: - Key Loading

    /// Load all keys from GPG with auto-retry
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
            retryCount = 0 // Reset retry count on success

            // Update expiration reminders
            expirationReminder.updateKeys(keys)
            await expirationReminder.scheduleReminders()
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to load keys: \(error.localizedDescription)")

            // Auto-retry with exponential backoff
            if retryCount < maxRetries {
                retryCount += 1
                let delay = UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000) // 2^n seconds
                logger.info("Scheduling retry \(self.retryCount)/\(self.maxRetries) in \(delay / 1_000_000_000) seconds")

                retryTask?.cancel()
                retryTask = Task {
                    try? await Task.sleep(nanoseconds: delay)
                    if !Task.isCancelled {
                        await loadKeys()
                    }
                }
            }
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
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Temporary files inside our container are often readable without a security scope.
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw GPGError.fileAccessDenied(url.path)
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

    /// Import a key from keyserver using URL/fingerprint/key ID/email query.
    @discardableResult
    func importKeyFromKeyserver(query: String, keyserver: String) async throws -> KeyImportResult {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await gpgService.importFromKeyserver(
                query: query,
                keyserver: keyserver
            )
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
        logger.info("Exporting public key for: \(key.fingerprint)")

        do {
            let data = try await gpgService.exportPublicKey(keyID: key.fingerprint, armor: true)
            logger.info("Successfully exported public key, size: \(data.count) bytes")
            return data
        } catch {
            logger.error("Failed to export public key: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Export a secret key
    func exportSecretKey(_ key: GPGKey, passphrase: String) async throws -> Data {
        guard key.isSecret else {
            throw GPGError.keyNotFound("Secret key for \(key.fingerprint)")
        }

        logger.info("Exporting secret key for: \(key.fingerprint)")

        do {
            let data = try await gpgService.exportSecretKey(keyID: key.fingerprint, passphrase: passphrase, armor: true)
            logger.info("Successfully exported secret key, size: \(data.count) bytes")
            return data
        } catch {
            logger.error("Failed to export secret key: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Key Deletion

    /// Delete a key with specified option
    /// - Parameters:
    ///   - key: The key to delete
    ///   - option: Which part of the key to delete (secret only, public only, or both)
    func deleteKey(_ key: GPGKey, option: DeleteKeyOption = .both) async throws {
        isLoading = true
        errorMessage = nil

        do {
            switch option {
            case .secretOnly:
                // Delete only the secret key
                try await gpgService.deleteKey(keyID: key.fingerprint, secret: true)
            case .publicOnly:
                // Delete only the public key
                try await gpgService.deleteKey(keyID: key.fingerprint, secret: false)
            case .both:
                // Delete both secret and public keys
                // Note: GPG requires deleting secret key first
                if key.isSecret {
                    try await gpgService.deleteKey(keyID: key.fingerprint, secret: true)
                }
                try await gpgService.deleteKey(keyID: key.fingerprint, secret: false)
            }
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

    // MARK: - Key Edit Operations

    /// Update expiration date for an existing key
    func updateKeyExpiration(for key: GPGKey, expiresAt: Date?, passphrase: String?) async throws {
        isLoading = true
        errorMessage = nil

        do {
            try await gpgService.updateKeyExpiration(
                keyID: key.fingerprint,
                expiresAt: expiresAt,
                passphrase: passphrase
            )
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Add user ID to an existing key
    func addUserID(to key: GPGKey, name: String, email: String, passphrase: String?) async throws {
        isLoading = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            isLoading = false
            throw GPGError.invalidOutput(String(localized: "error_invalid_output"))
        }
        guard isValidEmail(trimmedEmail) else {
            isLoading = false
            throw GPGError.invalidOutput(String(localized: "error_invalid_output"))
        }

        do {
            try await gpgService.addUserID(
                keyID: key.fingerprint,
                name: trimmedName,
                email: trimmedEmail,
                passphrase: passphrase
            )
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Change passphrase for a secret key
    func changePassphrase(for key: GPGKey, oldPassphrase: String, newPassphrase: String) async throws {
        guard key.isSecret else {
            throw GPGError.keyNotFound("Secret key for \(key.fingerprint)")
        }

        let oldPassphrase = oldPassphrase.trimmingCharacters(in: .newlines)
        let newPassphrase = newPassphrase.trimmingCharacters(in: .newlines)

        guard !oldPassphrase.isEmpty else {
            throw GPGError.invalidPassphrase
        }
        guard !newPassphrase.isEmpty else {
            throw GPGError.invalidPassphrase
        }

        isLoading = true
        errorMessage = nil

        do {
            try await gpgService.changePassphrase(
                keyID: key.fingerprint,
                oldPassphrase: oldPassphrase,
                newPassphrase: newPassphrase
            )
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
        retryCount = 0
    }

    func refresh() async {
        retryCount = 0 // Reset retry count on manual refresh
        await loadKeys()
    }

    func migrateKeysFromExternalKeyring(at sourceURL: URL) async throws -> KeyMigrationResult {
        guard !isSystemKeyringMigrationRunning else {
            throw GPGError.operationCancelled
        }

        isSystemKeyringMigrationRunning = true
        errorMessage = nil

        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        guard hasSecurityScope || FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            isSystemKeyringMigrationRunning = false
            throw GPGError.fileAccessDenied(sourceURL.path)
        }
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let result = try await gpgService.migrateKeys(fromExternalGPGHome: sourceURL)
            await loadKeys()
            isSystemKeyringMigrationRunning = false
            return result
        } catch {
            errorMessage = error.localizedDescription
            isSystemKeyringMigrationRunning = false
            throw error
        }
    }

    // MARK: - Search History

    func addToSearchHistory(_ query: String) {
        guard !query.isEmpty else { return }

        // Remove if already exists
        if let index = searchHistory.firstIndex(of: query) {
            searchHistory.remove(at: index)
        }

        // Add to beginning
        searchHistory.insert(query, at: 0)

        // Limit history size
        if searchHistory.count > maxSearchHistory {
            searchHistory = Array(searchHistory.prefix(maxSearchHistory))
        }
    }

    func clearSearchHistory() {
        searchHistory = []
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailPattern, options: .regularExpression) != nil
    }

    // MARK: - Filter Management

    func resetFilters() {
        filterKeyType = .all
        filterTrustLevel = nil
        filterAlgorithm = nil
        showExpiredKeys = true
        searchText = ""
    }

    var hasActiveFilters: Bool {
        filterKeyType != .all ||
        filterTrustLevel != nil ||
        filterAlgorithm != nil ||
        !showExpiredKeys ||
        !searchText.isEmpty
    }
}

// MARK: - Filter Types

enum KeyTypeFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case publicOnly = "public"
    case secretOnly = "secret"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return String(localized: "filter_all_keys")
        case .publicOnly:
            return String(localized: "filter_public_keys")
        case .secretOnly:
            return String(localized: "filter_secret_keys")
        }
    }
}
