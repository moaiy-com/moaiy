//
//  KeychainService.swift
//  Moaiy
//
//  Keychain integration service for storing and retrieving private key passphrases.
//  Supports Apple Secure Enclave & LocalAuthentication (Touch ID / Apple Watch).
//

import Foundation
import Security
import LocalAuthentication
import os.log

public enum KeychainError: LocalizedError, Equatable {
    case itemNotFound
    case duplicateItem
    case accessControlFailed(String)
    case unexpectedData
    case unhandledStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Passphrase not found in system Keychain."
        case .duplicateItem:
            return "A passphrase entry for this key already exists in Keychain."
        case .accessControlFailed(let reason):
            return "Failed to configure hardware access control: \(reason)"
        case .unexpectedData:
            return "Unexpected data format encountered in Keychain."
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error: \(message) (\(status))"
            }
            return "Unhandled Keychain status code: \(status)"
        }
    }
}

public protocol KeychainManaging: Sendable {
    func savePassphrase(_ passphrase: SecureString, for keyFingerprint: String, requireBiometrics: Bool) throws
    func retrievePassphrase(for keyFingerprint: String, contextReason: String?) async throws -> SecureString?
    func deletePassphrase(for keyFingerprint: String) throws
    func isPassphraseStored(for keyFingerprint: String) -> Bool
    func isBiometricsAvailable() -> Bool
}

public final class KeychainService: KeychainManaging, @unchecked Sendable {
    public static let shared = KeychainService()

    private let logger = Logger(subsystem: "com.moaiy.app", category: "KeychainService")
    public static let defaultServiceDomain = "com.moaiy.app.passphrase"

    private let serviceDomain: String

    public init(serviceDomain: String = defaultServiceDomain) {
        self.serviceDomain = serviceDomain
    }

    // MARK: - Biometrics Availability

    public func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func biometryType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    // MARK: - Save Passphrase

    public func savePassphrase(
        _ passphrase: SecureString,
        for keyFingerprint: String,
        requireBiometrics: Bool = false
    ) throws {
        let normalizedFingerprint = keyFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Remove existing item if present
        try? deletePassphrase(for: normalizedFingerprint)

        var accessControl: SecAccessControl?
        if requireBiometrics {
            var error: Unmanaged<CFError>?
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryAny,
                &error
            )
            if let error = error?.takeRetainedValue() {
                let description = CFErrorCopyDescription(error) as String? ?? "Unknown error"
                logger.error("Failed to create biometric access control: \(description)")
                throw KeychainError.accessControlFailed(description)
            }
        }

        let secretData = passphrase.revealString().data(using: .utf8) ?? Data()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint,
            kSecValueData as String: secretData
        ]

        if let accessControl = accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            logger.error("SecItemAdd failed with status: \(status)")
            throw KeychainError.unhandledStatus(status)
        }

        logger.info("Successfully stored passphrase in Keychain for key: \(normalizedFingerprint)")
    }

    // MARK: - Retrieve Passphrase

    public func retrievePassphrase(
        for keyFingerprint: String,
        contextReason: String? = nil
    ) async throws -> SecureString? {
        let normalizedFingerprint = keyFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let contextReason = contextReason {
            let context = LAContext()
            context.localizedReason = contextReason
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            logger.error("SecItemCopyMatching failed with status: \(status)")
            throw KeychainError.unhandledStatus(status)
        }

        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return SecureString(string)
    }

    // MARK: - Delete Passphrase

    public func deletePassphrase(for keyFingerprint: String) throws {
        let normalizedFingerprint = keyFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("SecItemDelete failed with status: \(status)")
            throw KeychainError.unhandledStatus(status)
        }

        logger.info("Successfully deleted Keychain entry for key: \(normalizedFingerprint)")
    }

    // MARK: - Status Query

    public func isPassphraseStored(for keyFingerprint: String) -> Bool {
        let normalizedFingerprint = keyFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }
}
