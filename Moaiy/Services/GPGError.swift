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
    case keyserverUploadFailed(String)
    
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
        case .keyserverUploadFailed(let message):
            return "\(String(localized: "error_keyserver_upload_failed")): \(message)"
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
        case .keyserverUploadFailed:
            return String(localized: "error_keyserver_upload_failed_recovery")
        }
    }
}

enum UserFacingErrorContext {
    case general
    case keyList
    case encrypt
    case decrypt
    case sign
    case verify
    case backup
    case importKey
    case exportKey
    case trust
    case keyEdit
    case keyserverUpload
}

enum UserFacingErrorMapper {
    static func message(for error: Error, context: UserFacingErrorContext = .general) -> String {
        if let gpgError = error as? GPGError {
            return message(for: gpgError, context: context)
        }
        return mapRawMessage(error.localizedDescription, context: context)
    }

    static func alertTitleKey(for context: UserFacingErrorContext) -> String {
        switch context {
        case .general:
            return "error_occurred"
        case .keyList:
            return "key_list_alert_title_failure"
        case .encrypt:
            return "encrypt_alert_title_failure"
        case .decrypt:
            return "decrypt_alert_title_failure"
        case .sign:
            return "sign_alert_title_failure"
        case .verify:
            return "verify_alert_title_failure"
        case .backup:
            return "backup_alert_title_failure"
        case .importKey:
            return "import_alert_title_failure"
        case .exportKey:
            return "export_alert_title_failure"
        case .trust:
            return "trust_alert_title_failure"
        case .keyEdit:
            return "edit_alert_title_failure"
        case .keyserverUpload:
            return "upload_alert_title_failure"
        }
    }

    private static func message(for error: GPGError, context: UserFacingErrorContext) -> String {
        switch error {
        case .gpgNotFound:
            return String(localized: "error_gpg_not_found")
        case .invalidPassphrase:
            return String(localized: "error_invalid_passphrase")
        case .operationCancelled:
            return String(localized: "error_operation_cancelled")
        case .encryptionFailed:
            return String(localized: "error_encryption_failed")
        case .decryptionFailed:
            return String(localized: "error_decryption_failed")
        case .importFailed:
            return String(localized: "error_import_failed")
        case .exportFailed:
            return String(localized: "error_export_failed")
        case .keyNotFound:
            if context == .decrypt {
                return String(localized: "error_decryption_requires_private_key")
            }
            return String(localized: "error_key_not_found")
        case .keyGenerationFailed:
            return String(localized: "error_key_generation_failed")
        case .fileAccessDenied:
            return String(localized: "error_file_access_denied")
        case .unsupportedKeyType:
            return String(localized: "error_unsupported_key_type")
        case .trustUpdateFailed:
            return String(localized: "error_trust_update_failed")
        case .keySigningFailed:
            return String(localized: "error_key_signing_failed")
        case .keyserverUploadFailed:
            return String(localized: "error_keyserver_upload_failed")
        case .invalidOutput(let message), .executionFailed(let message):
            return mapRawMessage(message, context: context)
        }
    }

    private static func mapRawMessage(_ rawMessage: String, context: UserFacingErrorContext) -> String {
        if isFriendlyMessage(rawMessage) {
            return rawMessage
        }

        let lowercasedMessage = rawMessage.lowercased()
        if lowercasedMessage.contains("cancelled") {
            return String(localized: "error_operation_cancelled")
        }
        if lowercasedMessage.contains("bad passphrase")
            || lowercasedMessage.contains("invalid passphrase")
            || lowercasedMessage.contains("wrong passphrase") {
            return String(localized: "error_invalid_passphrase")
        }
        if lowercasedMessage.contains("permission denied")
            || lowercasedMessage.contains("access denied")
            || lowercasedMessage.contains("operation not permitted") {
            return String(localized: "error_file_access_denied")
        }
        if lowercasedMessage.contains("no secret key")
            || lowercasedMessage.contains("secret key not available")
            || lowercasedMessage.contains("decryption requires a private key") {
            return String(localized: "error_decryption_requires_private_key")
        }
        if context == .verify {
            return friendlyVerifyMessage(from: lowercasedMessage)
        }

        return defaultMessage(for: context)
    }

    private static func friendlyVerifyMessage(from lowercasedMessage: String) -> String {
        if lowercasedMessage.contains("badsig")
            || lowercasedMessage.contains("errsig")
            || lowercasedMessage.contains("bad signature")
            || lowercasedMessage.contains("we couldn't verify this signature")
            || lowercasedMessage.contains("please check the selected files and try again") {
            return String(localized: "verify_signature_error_bad_signature")
        }
        if lowercasedMessage.contains("no_pubkey")
            || lowercasedMessage.contains("no public key") {
            return String(localized: "verify_signature_error_missing_public_key")
        }
        if lowercasedMessage.contains("nodata")
            || lowercasedMessage.contains("no signature found")
            || lowercasedMessage.contains("no valid openpgp data found") {
            return String(localized: "verify_signature_error_no_signature")
        }
        if lowercasedMessage.contains("can't open signed data")
            || lowercasedMessage.contains("no such file or directory")
            || lowercasedMessage.contains("should be the first file") {
            return String(localized: "verify_signature_error_missing_original")
        }
        return String(localized: "verify_signature_error_generic")
    }

    private static func defaultMessage(for context: UserFacingErrorContext) -> String {
        switch context {
        case .general:
            return String(localized: "error_operation_failed_generic")
        case .keyList:
            return String(localized: "key_list_error_load_failed")
        case .encrypt:
            return String(localized: "error_encryption_failed")
        case .decrypt:
            return String(localized: "error_decryption_failed")
        case .sign:
            return String(localized: "error_key_signing_failed")
        case .verify:
            return String(localized: "verify_signature_error_generic")
        case .backup:
            return String(localized: "backup_error_operation_failed")
        case .importKey:
            return String(localized: "error_import_failed")
        case .exportKey:
            return String(localized: "error_export_failed")
        case .trust:
            return String(localized: "error_trust_update_failed")
        case .keyEdit:
            return String(localized: "edit_error_operation_failed")
        case .keyserverUpload:
            return String(localized: "error_keyserver_upload_failed")
        }
    }

    private static func isFriendlyMessage(_ message: String) -> Bool {
        let friendlyMessages = [
            String(localized: "verify_signature_error_no_signature"),
            String(localized: "verify_signature_error_bad_signature"),
            String(localized: "verify_signature_error_missing_public_key"),
            String(localized: "verify_signature_error_missing_original"),
            String(localized: "verify_signature_error_generic"),
            String(localized: "verify_signature_failed"),
            String(localized: "error_operation_failed_generic"),
            String(localized: "key_list_error_load_failed"),
            String(localized: "backup_error_operation_failed"),
            String(localized: "edit_error_operation_failed")
        ]
        return friendlyMessages.contains(message)
    }
}
