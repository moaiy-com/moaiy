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
            return String(localized: "error_gpg_not_found")
        case .executionFailed(let message):
            return "\(String(localized: "error_execution_failed")): \(message)"
        case .invalidOutput(let message):
            return "\(String(localized: "error_invalid_output")): \(message)"
        case .keyNotFound(let identifier):
            return "\(String(localized: "error_key_not_found")): \(identifier)"
        case .keyGenerationFailed(let message):
            return "\(String(localized: "error_key_generation_failed")): \(message)"
        case .encryptionFailed(let message):
            return "\(String(localized: "error_encryption_failed")): \(message)"
        case .decryptionFailed(let message):
            return "\(String(localized: "error_decryption_failed")): \(message)"
        case .importFailed(let message):
            return "\(String(localized: "error_import_failed")): \(message)"
        case .exportFailed(let message):
            return "\(String(localized: "error_export_failed")): \(message)"
        case .invalidPassphrase:
            return String(localized: "error_invalid_passphrase")
        case .operationCancelled:
            return String(localized: "error_operation_cancelled")
        case .fileAccessDenied(let path):
            return "\(String(localized: "error_file_access_denied")): \(path)"
        case .unsupportedKeyType(let type):
            return "\(String(localized: "error_unsupported_key_type")): \(type)"
        case .trustUpdateFailed(let message):
            return "\(String(localized: "error_trust_update_failed")): \(message)"
        case .keySigningFailed(let message):
            return "\(String(localized: "error_key_signing_failed")): \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .gpgNotFound:
            return String(localized: "error_gpg_not_found_recovery")
        case .executionFailed:
            return String(localized: "error_execution_failed_recovery")
        case .invalidOutput:
            return String(localized: "error_invalid_output_recovery")
        case .keyNotFound:
            return String(localized: "error_key_not_found_recovery")
        case .keyGenerationFailed:
            return String(localized: "error_key_generation_failed_recovery")
        case .encryptionFailed:
            return String(localized: "error_encryption_failed_recovery")
        case .decryptionFailed:
            return String(localized: "error_decryption_failed_recovery")
        case .importFailed:
            return String(localized: "error_import_failed_recovery")
        case .exportFailed:
            return String(localized: "error_export_failed_recovery")
        case .invalidPassphrase:
            return String(localized: "error_invalid_passphrase_recovery")
        case .operationCancelled:
            return String(localized: "error_operation_cancelled_recovery")
        case .fileAccessDenied:
            return String(localized: "error_file_access_denied_recovery")
        case .unsupportedKeyType:
            return String(localized: "error_unsupported_key_type_recovery")
        case .trustUpdateFailed:
            return String(localized: "error_trust_update_failed_recovery")
        case .keySigningFailed:
            return String(localized: "error_key_signing_failed_recovery")
        }
    }
}
