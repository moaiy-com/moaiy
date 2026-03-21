//
//  GPGError.swift
//  Moaiy
//
//  GPG operation error types
//

import Foundation

/// Errors that can occur during GPG operations
enum GPGError: Error, LocalizedError {
    case gpgNotFound
    case executionFailed(String)
    case invalidOutput(String)
    case keyNotFound(String)
    case keyGenerationFailed(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case importFailed(String)
    case exportFailed(String)
    case invalidPassphrase
    case operationCancelled
    case fileAccessDenied(String)
    case unsupportedKeyType(String)
    case trustUpdateFailed(String)
    case keySigningFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .gpgNotFound:
            return "GPG executable not found in application bundle"
        case .executionFailed(let message):
            return "GPG execution failed: \(message)"
        case .invalidOutput(let message):
            return "Invalid GPG output: \(message)"
        case .keyNotFound(let identifier):
            return "Key not found: \(identifier)"
        case .keyGenerationFailed(let message):
            return "Key generation failed: \(message)"
        case .encryptionFailed(let message):
            return "Encryption failed: \(message)"
        case .decryptionFailed(let message):
            return "Decryption failed: \(message)"
        case .importFailed(let message):
            return "Key import failed: \(message)"
        case .exportFailed(let message):
            return "Key export failed: \(message)"
        case .invalidPassphrase:
            return "Invalid passphrase"
        case .operationCancelled:
            return "Operation was cancelled"
        case .fileAccessDenied(let path):
            return "File access denied: \(path)"
        case .unsupportedKeyType(let type):
            return "Unsupported key type: \(type)"
        case .trustUpdateFailed(let message):
            return "Trust update failed: \(message)"
        case .keySigningFailed(let message):
            return "Key signing failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .gpgNotFound:
            return "Please reinstall the application"
        case .executionFailed:
            return "Check GPG installation and try again"
        case .invalidOutput:
            return "Try updating GPG version"
        case .keyNotFound:
            return "Import the key first or check the key ID"
        case .keyGenerationFailed:
            return "Check input parameters and try again"
        case .encryptionFailed:
            return "Ensure you have valid recipient keys"
        case .decryptionFailed:
            return "Ensure you have the correct private key and passphrase"
        case .importFailed:
            return "Check if the key file is valid"
        case .exportFailed:
            return "Check file permissions and disk space"
        case .invalidPassphrase:
            return "Check your passphrase and try again"
        case .operationCancelled:
            return "Try the operation again"
        case .fileAccessDenied:
            return "Grant file access permission in Settings"
        case .unsupportedKeyType:
            return "Use RSA-4096 or ECC (Curve25519)"
        case .trustUpdateFailed:
            return "Check key ID and try again"
        case .keySigningFailed:
            return "Ensure you have the correct signing key and passphrase"
        }
    }
}
