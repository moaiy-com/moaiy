//
//  EncryptionViewModel.swift
//  Moaiy
//
//  ViewModel for encryption/decryption functionality
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Operation History

struct EncryptionHistoryItem: Identifiable, Codable {
    let id: UUID
    let type: EncryptionViewModel.OperationType
    let timestamp: Date
    let contentPreview: String
    let success: Bool
    
    init(type: EncryptionViewModel.OperationType, context: String? = nil, success: Bool) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.contentPreview = EncryptionHistoryItem.makeSafePreview(type: type, context: context)
        self.success = success
    }

    init(
        id: UUID,
        type: EncryptionViewModel.OperationType,
        timestamp: Date,
        contentPreview: String,
        success: Bool
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.contentPreview = contentPreview
        self.success = success
    }

    private static func makeSafePreview(type: EncryptionViewModel.OperationType, context: String?) -> String {
        if let context, !context.isEmpty {
            let cleaned = context
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            return String(cleaned.prefix(80))
        }

        return type.rawValue
    }
}

@MainActor
@Observable
final class EncryptionViewModel {
    
    // MARK: - Published State
    
    var inputText = ""
    var outputText = ""
    var selectedRecipientKeys: Set<String> = []
    var selectedSignerKey: String?
    var isEncrypting = false
    var isDecrypting = false
    var errorMessage: String?
    var lastOperationType: OperationType?
    var lastOperationTime: Date?
    
    // Operation History
    var operationHistory: [EncryptionHistoryItem] = []
    var maxHistoryItems = Constants.UI.maxOperationHistory
    
    // MARK: - File Decryption State
    
    /// Pending files for decryption (set when passphrase is required)
    var pendingDecryptionFiles: [URL] = []
    var fileDecryptionProgress: Double = 0
    var isProcessingFiles = false
    var currentProcessingFileName: String?
    
    // MARK: - Private Properties
    
    private let gpgService = GPGService.shared
    
    /// Reference to shared key management view model
    let keyManagementVM: KeyManagementViewModel
    
    private let historyKey = Constants.StorageKeys.encryptionHistory
    private let bookmarkManager = FileBookmarkManager.shared
    
    // MARK: - Computed Properties
    
    /// All keys that can be used for encryption (both public and secret keys have public components)
    var availableRecipientKeys: [GPGKey] {
        // All keys can be used for encryption - secret keys also have public components
        keyManagementVM.keys
    }
    
    var availableSignerKeys: [GPGKey] {
        keyManagementVM.secretKeys
    }
    
    var canEncrypt: Bool {
        !inputText.isEmpty && !selectedRecipientKeys.isEmpty
    }
    
    var canDecrypt: Bool {
        !inputText.isEmpty
    }
    
    var hasOutput: Bool {
        !outputText.isEmpty
    }
    
    var selectedRecipients: [GPGKey] {
        availableRecipientKeys.filter { selectedRecipientKeys.contains($0.fingerprint) }
    }
    
    var recentHistory: [EncryptionHistoryItem] {
        Array(operationHistory.prefix(10))
    }
    
    var successfulOperationsCount: Int {
        operationHistory.filter { $0.success }.count
    }
    
    // MARK: - Initialization
    
    /// Initialize with optional key management view model (uses shared instance by default)
    init(keyManagement: KeyManagementViewModel? = nil) {
        self.keyManagementVM = keyManagement ?? AppState.shared.keyManagement
        loadHistory()
    }
    
    // MARK: - Text Operations
    
    /// Encrypt text with selected recipient keys
    func encryptText() async {
        guard canEncrypt else { return }
        
        isEncrypting = true
        errorMessage = nil
        lastOperationType = .encryption
        
        do {
            let recipients = Array(selectedRecipientKeys)
            outputText = try await gpgService.encrypt(text: inputText, recipients: recipients)
            lastOperationTime = Date()
            addToHistory(type: .encryption, context: nil, success: true)
            copyOutputToClipboard()
        } catch {
            errorMessage = error.localizedDescription
            outputText = ""
            addToHistory(type: .encryption, context: nil, success: false)
        }
        
        isEncrypting = false
    }
    
    /// Decrypt text
    /// - Parameter passphrase: Passphrase for the private key
    func decryptText(passphrase: String) async {
        guard !inputText.isEmpty else { return }
        
        isDecrypting = true
        errorMessage = nil
        lastOperationType = .decryption
        
        do {
            outputText = try await gpgService.decrypt(text: inputText, passphrase: passphrase)
            lastOperationTime = Date()
            addToHistory(type: .decryption, context: nil, success: true)
        } catch {
            errorMessage = error.localizedDescription
            outputText = ""
            addToHistory(type: .decryption, context: nil, success: false)
        }
        
        isDecrypting = false
    }
    
    // MARK: - File Operations
    
    /// Encrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    /// - Returns: URL of encrypted file
    @discardableResult
    func encryptFile(sourceURL: URL, destinationURL: URL) async throws -> URL {
        guard !selectedRecipientKeys.isEmpty else {
            throw GPGError.encryptionFailed("No recipient keys selected")
        }
        
        isEncrypting = true
        errorMessage = nil
        lastOperationType = .fileEncryption
        
        do {
            let recipients = Array(selectedRecipientKeys)
            try await gpgService.encryptFile(sourceURL: sourceURL, destinationURL: destinationURL, recipients: recipients)
            lastOperationTime = Date()
            addToHistory(type: .fileEncryption, context: sourceURL.lastPathComponent, success: true)
            isEncrypting = false
            return destinationURL
        } catch {
            errorMessage = error.localizedDescription
            addToHistory(type: .fileEncryption, context: sourceURL.lastPathComponent, success: false)
            isEncrypting = false
            throw error
        }
    }
    
    /// Decrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - passphrase: Passphrase
    /// - Returns: URL of decrypted file
    @discardableResult
    func decryptFile(sourceURL: URL, destinationURL: URL, passphrase: String) async throws -> URL {
        isDecrypting = true
        errorMessage = nil
        lastOperationType = .fileDecryption
        
        do {
            try await gpgService.decryptFile(sourceURL: sourceURL, destinationURL: destinationURL, passphrase: passphrase)
            lastOperationTime = Date()
            addToHistory(type: .fileDecryption, context: sourceURL.lastPathComponent, success: true)
            isDecrypting = false
            return destinationURL
        } catch {
            errorMessage = error.localizedDescription
            addToHistory(type: .fileDecryption, context: sourceURL.lastPathComponent, success: false)
            isDecrypting = false
            throw error
        }
    }
    
    // MARK: - Batch File Decryption
    
    /// Set pending files for decryption (triggers passphrase input)
    /// - Parameter files: Files to decrypt
    func setPendingDecryptionFiles(_ files: [URL]) {
        pendingDecryptionFiles = files
    }
    
    /// Process pending file decryptions with the provided passphrase
    /// - Parameter passphrase: Passphrase for decryption
    /// - Returns: Number of successfully decrypted files
    @discardableResult
    func processPendingFileDecryptions(passphrase: String) async -> Int {
        guard !pendingDecryptionFiles.isEmpty else { return 0 }
        
        isProcessingFiles = true
        fileDecryptionProgress = 0
        errorMessage = nil
        lastOperationType = .fileDecryption
        
        let totalFiles = Double(pendingDecryptionFiles.count)
        var completedFiles = 0
        
        for sourceURL in pendingDecryptionFiles {
            currentProcessingFileName = sourceURL.lastPathComponent
            
            // Start accessing security-scoped resource
            let hasAccess = await bookmarkManager.startAccessing(url: sourceURL)
            
            defer {
                if hasAccess {
                    Task { await bookmarkManager.stopAccessing(url: sourceURL) }
                }
            }
            
            // Remove .gpg extension for output
            let destName = sourceURL.lastPathComponent.hasSuffix(".gpg")
                ? String(sourceURL.lastPathComponent.dropLast(4))
                : sourceURL.lastPathComponent + ".decrypted"
            let destinationURL = sourceURL.deletingLastPathComponent()
                .appendingPathComponent(destName)
            
            do {
                _ = try await gpgService.decryptFile(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    passphrase: passphrase
                )
                completedFiles += 1
                addToHistory(type: .fileDecryption, context: sourceURL.lastPathComponent, success: true)
            } catch {
                addToHistory(type: .fileDecryption, context: sourceURL.lastPathComponent, success: false)
                // Continue with remaining files even if one fails
            }
            
            fileDecryptionProgress = Double(completedFiles) / totalFiles
        }
        
        isProcessingFiles = false
        currentProcessingFileName = nil
        lastOperationTime = Date()
        
        // Clear pending files after processing
        pendingDecryptionFiles.removeAll()
        
        return completedFiles
    }
    
    /// Cancel pending file decryptions
    func cancelPendingDecryptions() {
        pendingDecryptionFiles.removeAll()
        isProcessingFiles = false
        currentProcessingFileName = nil
    }
    
    // MARK: - Key Selection
    
    /// Toggle a recipient key selection
    /// - Parameter key: Key to toggle
    func toggleRecipientKey(_ key: GPGKey) {
        if selectedRecipientKeys.contains(key.fingerprint) {
            selectedRecipientKeys.remove(key.fingerprint)
        } else {
            selectedRecipientKeys.insert(key.fingerprint)
        }
    }
    
    /// Select a signer key for decryption
    /// - Parameter key: Key to select
    func selectSignerKey(_ key: GPGKey?) {
        selectedSignerKey = key?.fingerprint
    }
    
    /// Select all available recipient keys
    func selectAllRecipients() {
        selectedRecipientKeys = Set(availableRecipientKeys.map { $0.fingerprint })
    }
    
    /// Clear all recipient selections
    func clearAllRecipients() {
        selectedRecipientKeys.removeAll()
    }
    
    // MARK: - Clipboard
    
    /// Copy output to clipboard
    func copyOutputToClipboard() {
        guard !outputText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
    
    /// Paste from clipboard to input
    func pasteFromClipboard() {
        if let content = NSPasteboard.general.string(forType: .string) {
            inputText = content
        }
    }
    
    // MARK: - State Management
    
    /// Clear all state
    func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
        lastOperationType = nil
        lastOperationTime = nil
    }
    
    /// Swap input and output (for re-encryption)
    func swapInputOutput() {
        let temp = inputText
        inputText = outputText
        outputText = temp
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear operation history
    func clearHistory() {
        operationHistory.removeAll()
        saveHistory()
    }
    
    // MARK: - History Management
    
    private func addToHistory(type: OperationType, context: String?, success: Bool) {
        let item = EncryptionHistoryItem(type: type, context: context, success: success)
        operationHistory.insert(item, at: 0)
        
        // Limit history size
        if operationHistory.count > maxHistoryItems {
            operationHistory = Array(operationHistory.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(operationHistory)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("Failed to save encryption history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }
        
        do {
            let decoded = try JSONDecoder().decode([EncryptionHistoryItem].self, from: data)
            // Migrate legacy history to safe previews so plaintext/ciphertext is no longer retained.
            operationHistory = decoded.map { item in
                let safePreview = item.type.isFileOperation ? item.contentPreview : item.type.rawValue
                return EncryptionHistoryItem(
                    id: item.id,
                    type: item.type,
                    timestamp: item.timestamp,
                    contentPreview: String(safePreview.prefix(80)),
                    success: item.success
                )
            }
            saveHistory()
        } catch {
            print("Failed to load encryption history: \(error)")
            operationHistory = []
        }
    }
}

// MARK: - Supporting Types

extension EncryptionViewModel {
    enum OperationType: String, Codable {
        case encryption = "Encryption"
        case decryption = "Decryption"
        case fileEncryption = "File Encryption"
        case fileDecryption = "File Decryption"
        
        var isFileOperation: Bool {
            self == .fileEncryption || self == .fileDecryption
        }
        
        var isEncryption: Bool {
            self == .encryption || self == .fileEncryption
        }
        
        var icon: String {
            switch self {
            case .encryption, .fileEncryption:
                return "lock.fill"
            case .decryption, .fileDecryption:
                return "lock.open.fill"
            }
        }
    }
}
