//
//  KeychainService.swift
//  Moaiy
//
//  Keychain integration service for storing and retrieving private key passphrases.
//  Supports Apple Secure Enclave & LocalAuthentication (Touch ID / Passcode).
//

import Foundation
import Security
import LocalAuthentication
import os.log

public enum KeychainError: LocalizedError, Equatable {
    case itemNotFound
    case userCancelled
    case authenticationFailed(String)
    case duplicateItem
    case accessControlFailed(String)
    case unexpectedData
    case unhandledStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Passphrase not found in system Keychain."
        case .userCancelled:
            return "User cancelled Keychain authentication."
        case .authenticationFailed(let reason):
            return "Keychain authentication failed: \(reason)"
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

    /// Normalizes key identifier by removing 0x prefix, spaces, and converting to uppercase
    public static func normalizeKeyReference(_ key: String) -> String {
        var trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("0X") {
            trimmed = String(trimmed.dropFirst(2))
        }
        return trimmed
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
        let normalizedFingerprint = Self.normalizeKeyReference(keyFingerprint)

        var secretData = Data()
        passphrase.withUnsafeUTF8 { rawBuffer in
            secretData = Data(rawBuffer)
        }
        defer {
            secretData.resetBytes(in: 0..<secretData.count)
        }

        var accessControl: SecAccessControl?
        if requireBiometrics {
            var error: Unmanaged<CFError>?
            // .userPresence covers Touch ID, Apple Watch, and device passcode
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                &error
            )
            if let error = error?.takeRetainedValue() {
                let description = CFErrorCopyDescription(error) as String? ?? "Unknown error"
                logger.error("Failed to create biometric access control: \(description)")
                throw KeychainError.accessControlFailed(description)
            }
        }

        func makeAddQuery(useDataProtection: Bool) -> [String: Any] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceDomain,
                kSecAttrAccount as String: normalizedFingerprint,
                kSecValueData as String: secretData
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as String] = true
                if let accessControl = accessControl {
                    query[kSecAttrAccessControl as String] = accessControl
                } else {
                    query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                }
            } else {
                query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            }
            return query
        }

        var useDataProtection = true
        var query = makeAddQuery(useDataProtection: true)
        var status = SecItemAdd(query as CFDictionary, nil)

        // Fallback to standard macOS Keychain in ad-hoc signed Debug/Test builds (-34018 errSecMissingEntitlement)
        if status == errSecMissingEntitlement && !requireBiometrics {
            useDataProtection = false
            query = makeAddQuery(useDataProtection: false)
            status = SecItemAdd(query as CFDictionary, nil)
        }

        if status == errSecDuplicateItem {
            // Attempt update; if update fails (often happens when changing SecAccessControl), fallback to delete + add
            var updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceDomain,
                kSecAttrAccount as String: normalizedFingerprint
            ]
            if useDataProtection {
                updateQuery[kSecUseDataProtectionKeychain as String] = true
            }
            var attributesToUpdate: [String: Any] = [
                kSecValueData as String: secretData
            ]
            if useDataProtection, let accessControl = accessControl {
                attributesToUpdate[kSecAttrAccessControl as String] = accessControl
            }
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            if updateStatus == errSecSuccess {
                logger.info("Successfully updated existing Keychain passphrase for key: \(normalizedFingerprint)")
                return
            }

            // Fallback: delete old item and re-add with new access control attributes
            logger.notice("SecItemUpdate failed (\(updateStatus)), falling back to delete and re-add.")
            try? deletePassphrase(for: normalizedFingerprint)
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
            logger.info("Successfully re-added Keychain passphrase for key: \(normalizedFingerprint)")
            return
        }

        guard status == errSecSuccess else {
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
        let normalizedFingerprint = Self.normalizeKeyReference(keyFingerprint)

        // Dispatch blocking SecItemCopyMatching to background thread so MainActor is not blocked
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                func makeCopyQuery(useDataProtection: Bool) -> [String: Any] {
                    var query: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrService as String: self.serviceDomain,
                        kSecAttrAccount as String: normalizedFingerprint,
                        kSecReturnData as String: true,
                        kSecMatchLimit as String: kSecMatchLimitOne
                    ]
                    if useDataProtection {
                        query[kSecUseDataProtectionKeychain as String] = true
                    }
                    if let contextReason = contextReason {
                        let context = LAContext()
                        context.localizedReason = contextReason
                        query[kSecUseAuthenticationContext as String] = context
                    }
                    return query
                }

                var item: CFTypeRef?
                var status = SecItemCopyMatching(makeCopyQuery(useDataProtection: true) as CFDictionary, &item)
                if status == errSecMissingEntitlement || status == errSecItemNotFound {
                    let fallbackStatus = SecItemCopyMatching(makeCopyQuery(useDataProtection: false) as CFDictionary, &item)
                    if status == errSecMissingEntitlement || fallbackStatus == errSecSuccess {
                        status = fallbackStatus
                    }
                }

                if status == errSecItemNotFound {
                    continuation.resume(returning: nil)
                    return
                }

                if status == errSecUserCanceled || status == -128 {
                    continuation.resume(throwing: KeychainError.userCancelled)
                    return
                }

                if status == errSecAuthFailed {
                    continuation.resume(throwing: KeychainError.authenticationFailed("Biometric or passcode authentication failed."))
                    return
                }

                guard status == errSecSuccess else {
                    self.logger.error("SecItemCopyMatching failed with status: \(status)")
                    continuation.resume(throwing: KeychainError.unhandledStatus(status))
                    return
                }

                guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: KeychainError.unexpectedData)
                    return
                }

                let secureString = SecureString(string)
                continuation.resume(returning: secureString)
            }
        }
    }

    // MARK: - Delete Passphrase

    public func deletePassphrase(for keyFingerprint: String) throws {
        let normalizedFingerprint = Self.normalizeKeyReference(keyFingerprint)

        let dpQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint,
            kSecUseDataProtectionKeychain as String: true
        ]

        var status = SecItemDelete(dpQuery as CFDictionary)
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint
        ]
        let legacyStatus = SecItemDelete(legacyQuery as CFDictionary)
        if status == errSecMissingEntitlement || legacyStatus == errSecSuccess {
            status = legacyStatus
        }

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("SecItemDelete failed with status: \(status)")
            throw KeychainError.unhandledStatus(status)
        }

        logger.info("Successfully deleted Keychain entry for key: \(normalizedFingerprint)")
    }

    // MARK: - Status Query

    public func isPassphraseStored(for keyFingerprint: String) -> Bool {
        let normalizedFingerprint = Self.normalizeKeyReference(keyFingerprint)

        let context = LAContext()
        context.interactionNotAllowed = true

        let dpQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: normalizedFingerprint,
            kSecUseAuthenticationContext as String: context,
            kSecUseDataProtectionKeychain as String: true
        ]

        let status = SecItemCopyMatching(dpQuery as CFDictionary, nil)
        if status == errSecSuccess || status == errSecInteractionNotAllowed {
            return true
        }
        if status == errSecMissingEntitlement || status == errSecItemNotFound {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceDomain,
                kSecAttrAccount as String: normalizedFingerprint,
                kSecUseAuthenticationContext as String: context
            ]
            let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, nil)
            return legacyStatus == errSecSuccess || legacyStatus == errSecInteractionNotAllowed
        }
        return false
    }
}
