//
//  TestKeyFactory.swift
//  MoaiyTests
//
//  Factory for creating test GPGKey instances
//

import Foundation
@testable import Moaiy

/// Factory for creating test GPGKey instances
enum TestKeyFactory {
    
    // MARK: - Default Test Keys
    
    /// Create a standard test key with default values
    static func makeKey(
        name: String = "Test User",
        email: String = "test@example.com",
        fingerprint: String = "A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2",
        keyID: String = "E5F6A1B2",
        algorithm: String = "RSA",
        keyLength: Int = 4096,
        isSecret: Bool = false,
        trustLevel: TrustLevel = .unknown,
        createdAt: Date? = Date(timeIntervalSinceNow: -86400 * 365), // 1 year ago
        expiresAt: Date? = nil
    ) -> GPGKey {
        GPGKey(
            id: fingerprint,
            keyID: keyID,
            fingerprint: fingerprint,
            name: name,
            email: email,
            algorithm: algorithm,
            keyLength: keyLength,
            isSecret: isSecret,
            createdAt: createdAt,
            expiresAt: expiresAt,
            trustLevel: trustLevel
        )
    }
    
    // MARK: - Specialized Test Keys
    
    /// Create a secret key
    static func makeSecretKey(
        name: String = "Secret User",
        email: String = "secret@example.com",
        trustLevel: TrustLevel = .ultimate
    ) -> GPGKey {
        makeKey(
            name: name,
            email: email,
            fingerprint: "B1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6B1B2",
            keyID: "E5F6B1B2",
            isSecret: true,
            trustLevel: trustLevel
        )
    }
    
    /// Create an expired key
    static func makeExpiredKey(
        name: String = "Expired User",
        email: String = "expired@example.com"
    ) -> GPGKey {
        makeKey(
            name: name,
            email: email,
            fingerprint: "C1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6C1B2",
            keyID: "E5F6C1B2",
            expiresAt: Date(timeIntervalSinceNow: -86400 * 30) // Expired 30 days ago
        )
    }
    
    /// Create a key expiring soon
    static func makeExpiringSoonKey(
        days: Int = 7,
        name: String = "Expiring User",
        email: String = "expiring@example.com"
    ) -> GPGKey {
        makeKey(
            name: name,
            email: email,
            fingerprint: "D1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6D1B2",
            keyID: "E5F6D1B2",
            expiresAt: Date(timeIntervalSinceNow: 86400 * Double(days))
        )
    }
    
    /// Create a key with specific trust level
    static func makeKeyWithTrust(
        _ trustLevel: TrustLevel,
        name: String? = nil,
        email: String? = nil
    ) -> GPGKey {
        makeKey(
            name: name ?? "\(trustLevel.displayName) User",
            email: email ?? "\(trustLevel.rawValue)@example.com",
            trustLevel: trustLevel
        )
    }
    
    /// Create an ECC key
    static func makeECCKey(
        name: String = "ECC User",
        email: String = "ecc@example.com"
    ) -> GPGKey {
        makeKey(
            name: name,
            email: email,
            fingerprint: "E1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6E1B2",
            keyID: "E5F6E1B2",
            algorithm: "EDDSA",
            keyLength: 256
        )
    }
    
    /// Create an RSA-2048 key
    static func makeRSA2048Key(
        name: String = "RSA2048 User",
        email: String = "rsa2048@example.com"
    ) -> GPGKey {
        makeKey(
            name: name,
            email: email,
            fingerprint: "F1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6F1B2",
            keyID: "E5F6F1B2",
            algorithm: "RSA",
            keyLength: 2048
        )
    }
    
    // MARK: - Test Key Collections
    
    /// Create a mixed collection of keys for testing
    static func makeMixedKeyCollection() -> [GPGKey] {
        [
            makeKey(name: "Alice", email: "alice@example.com"),
            makeSecretKey(name: "Bob", email: "bob@example.com"),
            makeExpiredKey(),
            makeExpiringSoonKey(days: 14, name: "Charlie", email: "charlie@example.com"),
            makeKeyWithTrust(.full, name: "Diana", email: "diana@example.com"),
            makeKeyWithTrust(.marginal, name: "Eve", email: "eve@example.com"),
            makeECCKey(),
            makeRSA2048Key()
        ]
    }
    
    /// Create a collection of only public keys
    static func makePublicKeyCollection() -> [GPGKey] {
        [
            makeKey(name: "Public Alice", email: "public.alice@example.com"),
            makeKey(name: "Public Bob", email: "public.bob@example.com"),
            makeKey(name: "Public Charlie", email: "public.charlie@example.com")
        ]
    }
    
    /// Create a collection of only secret keys
    static func makeSecretKeyCollection() -> [GPGKey] {
        [
            makeSecretKey(name: "Secret Alice", email: "secret.alice@example.com"),
            makeSecretKey(name: "Secret Bob", email: "secret.bob@example.com")
        ]
    }
}

// MARK: - TrustLevel Test Helpers

extension TrustLevel {
    /// All trust levels for testing
    static let allTestCases: [TrustLevel] = [
        .unknown,
        .none,
        .marginal,
        .full,
        .ultimate
    ]
}

// MARK: - KeyType Test Helpers

extension KeyType {
    /// All key types for testing
    static let allTestCases: [KeyType] = [
        .rsa2048,
        .rsa4096,
        .ecc
    ]
}
