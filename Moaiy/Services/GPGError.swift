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
    case smartCardNotPresent
    case smartCardUnavailable
    case smartCardPinInvalid
    
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
        case .smartCardNotPresent:
            return String(localized: "error_smartcard_not_present")
        case .smartCardUnavailable:
            return String(localized: "error_smartcard_unavailable")
        case .smartCardPinInvalid:
            return String(localized: "error_smartcard_pin_invalid")
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
        case .smartCardNotPresent:
            return String(localized: "error_smartcard_not_present_recovery")
        case .smartCardUnavailable:
            return String(localized: "error_smartcard_unavailable_recovery")
        case .smartCardPinInvalid:
            return String(localized: "error_smartcard_pin_invalid_recovery")
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

    static func decryptionKeyMismatchMessage(
        recipientKeyIDs: [String],
        availableSecretKeys: [GPGKey]
    ) -> String {
        let baseMessage = String(localized: "error_decryption_requires_private_key")
        guard !recipientKeyIDs.isEmpty else {
            return baseMessage
        }

        let normalizedRecipientIDs = recipientKeyIDs.compactMap(normalizedTail16(for:))
        guard !normalizedRecipientIDs.isEmpty else {
            return baseMessage
        }

        let recipientSet = Set(normalizedRecipientIDs)
        let matchingSecretKeys = availableSecretKeys
            .filter(\.isSecret)
            .filter { key in
                guard let keyTail16 = normalizedTail16(for: key.fingerprint) ?? normalizedTail16(for: key.keyID) else {
                    return false
                }
                return recipientSet.contains(keyTail16)
            }

        let keyHint: String
        if matchingSecretKeys.isEmpty {
            keyHint = normalizedRecipientIDs.joined(separator: ", ")
        } else {
            keyHint = matchingSecretKeys.map { key in
                "\(key.name) <\(key.email)> (\(key.keyID))"
            }.joined(separator: ", ")
        }

        return "\(baseMessage)\n\(String(localized: "label_key_id")): \(keyHint)"
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
        case .keyserverUploadFailed(let message):
            return mapRawMessage(message, context: .keyserverUpload)
        case .smartCardNotPresent:
            return String(localized: "error_smartcard_not_present")
        case .smartCardUnavailable:
            return String(localized: "error_smartcard_unavailable")
        case .smartCardPinInvalid:
            return String(localized: "error_smartcard_pin_invalid")
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
        if lowercasedMessage.contains("card not present")
            || lowercasedMessage.contains("card removed") {
            return String(localized: "error_smartcard_not_present")
        }
        if lowercasedMessage.contains("operation not supported by device")
            || lowercasedMessage.contains("openpgp card not available")
            || lowercasedMessage.contains("no smartcard daemon") {
            return String(localized: "error_smartcard_unavailable")
        }
        if lowercasedMessage.contains("bad pin")
            || lowercasedMessage.contains("invalid pin")
            || lowercasedMessage.contains("wrong pin") {
            return String(localized: "error_smartcard_pin_invalid")
        }
        if lowercasedMessage.contains("bad passphrase")
            || lowercasedMessage.contains("invalid passphrase")
            || lowercasedMessage.contains("wrong passphrase")
            || lowercasedMessage.contains("no passphrase given") {
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
        if context == .keyserverUpload {
            if lowercasedMessage.contains("no dirmngr")
                || lowercasedMessage.contains("can't connect to the dirmngr")
                || lowercasedMessage.contains("keyserver rejected upload")
                || lowercasedMessage.contains("hkp upload failed") {
                return String(localized: "error_keyserver_upload_unavailable")
            }
            if lowercasedMessage.contains("timed out")
                || lowercasedMessage.contains("offline")
                || lowercasedMessage.contains("network")
                || lowercasedMessage.contains("could not connect")
                || lowercasedMessage.contains("connection refused") {
                return String(localized: "error_keyserver_upload_network")
            }
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

    private static func normalizedTail16(for value: String) -> String? {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if normalized.lowercased().hasPrefix("0x") {
            normalized.removeFirst(2)
        }
        normalized = normalized.replacingOccurrences(of: " ", with: "")

        guard normalized.range(of: "^[A-Fa-f0-9]{8,40}$", options: .regularExpression) != nil else {
            return nil
        }

        return String(normalized.uppercased().suffix(16))
    }
}
