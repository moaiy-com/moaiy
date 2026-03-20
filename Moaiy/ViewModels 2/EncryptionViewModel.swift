//
//  EncryptionViewModel.swift
//  Moaiy
//
//  ViewModel for encryption/decryption functionality
//

import Foundation
import Combine

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
    
    // MARK: - Private Properties
    
    private let gpgService = GPGService.shared
    private let keyManagementVM = KeyManagementViewModel()
    
    // MARK: - Computed Properties
    
    var availableRecipientKeys: [GPGKey] {
        keyManagementVM.publicKeys
    }
    
    var availableSignerKeys: [GPGKey] {
        keyManagementVM.secretKeys
    }
    
    var canEncrypt: Bool {
        !inputText.isEmpty && !selectedRecipientKeys.isEmpty
    }
    
    var canDecrypt: Bool {
        !inputText.isEmpty && selectedSignerKey != nil
    }
    
    var hasOutput: Bool {
        !outputText.isEmpty
    }
    
    var selectedRecipients: [GPGKey] {
        availableRecipientKeys.filter { selectedRecipientKeys.contains($0.fingerprint) }
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await keyManagementVM.loadKeys()
        }
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
            outputText = try await gpgService.encryptText(inputText, recipients: recipients)
            
            lastOperationTime = Date()
            
            // Copy to clipboard automatically
            copyOutputToClipboard()
        } catch {
            errorMessage = error.localizedDescription
            outputText = ""
        }
        
        isEncrypting = false
    }
    
    /// Decrypt text with selected signer key
    /// - Parameter passphrase: Optional passphrase for the key
    func decryptText(passphrase: String? = nil) async {
        guard canDecrypt else { return }
        
        isDecrypting = true
        errorMessage = nil
        lastOperationType = .decryption
        
        do {
            guard let signerFingerprint = selectedSignerKey else {
                throw GPGError.keyNotFound("No signer key selected")
            }
            
            outputText = try await gpgService.decryptText(inputText, passphrase: passphrase)
            
            lastOperationTime = Date()
        } catch {
            errorMessage = error.localizedDescription
            outputText = ""
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
    func encryptFile(sourceURL: URL, to destinationURL: URL) async throws -> URL {
        guard !selectedRecipientKeys.isEmpty else {
            throw GPGError.encryptionFailed("No recipient keys selected")
        }
        
        isEncrypting = true
        errorMessage = nil
        lastOperationType = .fileEncryption
        
        do {
            let recipients = Array(selectedRecipientKeys)
            try await gpgService.encryptFile(at: sourceURL, to: destinationURL, recipients: recipients)
            
            lastOperationTime = Date()
            isEncrypting = false
            
            return destinationURL
        } catch {
            errorMessage = error.localizedDescription
            isEncrypting = false
            throw error
        }
    }
    
    /// Decrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - passphrase: Optional passphrase
    /// - Returns: URL of decrypted file
    @discardableResult
    func decryptFile(sourceURL: URL, to destinationURL: URL, passphrase: String? = nil) async throws -> URL {
        isDecrypting = true
        errorMessage = nil
        lastOperationType = .fileDecryption
        
        do {
            try await gpgService.decryptFile(at: sourceURL, to: destinationURL, passphrase: passphrase)
            
            lastOperationTime = Date()
            isDecrypting = false
            
            return destinationURL
        } catch {
            errorMessage = error.localizedDescription
            isDecrypting = false
            throw error
        }
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
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
        #endif
    }
    
    /// Paste from clipboard to input
    func pasteFromClipboard() {
        #if os(macOS)
        if let content = NSPasteboard.general.string(forType: .string) {
            inputText = content
        }
        #endif
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
}

// MARK: - Supporting Types

extension EncryptionViewModel {
    enum OperationType: String {
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
    }
}
