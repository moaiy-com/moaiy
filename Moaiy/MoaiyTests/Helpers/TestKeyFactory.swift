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
        expiresAt: Date? = nil,
        algorithmSummary: GPGKeyAlgorithmSummary? = nil
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
            trustLevel: trustLevel,
            algorithmSummary: algorithmSummary
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

    /// Create a post-quantum hybrid key
    static func makePostQuantumHybridKey(
        name: String = "PQC User",
        email: String = "pqc@example.com",
        isSecret: Bool = false
    ) -> GPGKey {
        makeKey(
            name: name,
            email: email,
            fingerprint: "01B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F601B2",
            keyID: "E5F601B2",
            algorithm: "19",
            keyLength: 384,
            isSecret: isSecret,
            algorithmSummary: GPGKeyAlgorithmSummary.resolve(
                primaryAlgorithm: "19",
                primaryKeyLength: 384,
                encryptionSubkeys: [
                    GPGSubkeyAlgorithmMetadata(
                        algorithmID: "8",
                        algorithmName: "Kyber",
                        keyLength: 768,
                        curveOrToken: "ky768_bp256"
                    )
                ]
            )
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
        .ecc,
        .postQuantumHybrid
    ]
}

// MARK: - Isolated GPG Home Test Helper

final class TestGPGHome {
    let rootURL: URL
    let homeURL: URL
    let gpgURL: URL
    let gpgConnectAgentURL: URL?
    let gpgConfURL: URL?

    private let executor = GPGProcessExecutor()
    private var didCleanup = false

    private init(rootURL: URL, homeURL: URL, bundleURL: URL) {
        self.rootURL = rootURL
        self.homeURL = homeURL
        self.gpgURL = bundleURL.appendingPathComponent("bin/gpg")
        self.gpgConnectAgentURL = bundleURL.appendingPathComponent("bin/gpg-connect-agent")
        self.gpgConfURL = bundleURL.appendingPathComponent("bin/gpgconf")
    }

    deinit {
        cleanup()
    }

    static func make(prefix: String = "moaiy-test-gpg-home") throws -> TestGPGHome {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            throw TestGPGHomeError.bundleNotFound
        }

        let safePrefix = prefix.filter { character in
            character.isLetter || character.isNumber || character == "-"
        }
        let shortPrefix = String((safePrefix.isEmpty ? "gpg" : safePrefix).prefix(6))
        let uniqueSuffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(shortPrefix)-\(uniqueSuffix)", isDirectory: true)
        let homeURL = rootURL.appendingPathComponent("gnupg", isDirectory: true)

        try FileManager.default.createDirectory(
            at: homeURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: homeURL.path)

        return TestGPGHome(rootURL: rootURL, homeURL: homeURL, bundleURL: bundleURL)
    }

    func execute(
        arguments: [String],
        input: String? = nil,
        timeout: TimeInterval = Constants.GPG.defaultTimeout
    ) async throws -> GPGExecutionResult {
        try await executor.execute(
            executableURL: gpgURL,
            arguments: arguments,
            environment: [:],
            gpgHome: homeURL,
            input: input,
            timeout: timeout
        )
    }

    func ensureAgentRunning(timeout: TimeInterval = 10) async throws {
        guard let gpgConnectAgentURL, FileManager.default.fileExists(atPath: gpgConnectAgentURL.path) else {
            return
        }

        let result = try await executor.execute(
            executableURL: gpgConnectAgentURL,
            arguments: ["/bye"],
            environment: [:],
            gpgHome: homeURL,
            input: nil,
            timeout: timeout
        )

        guard result.exitCode == 0 else {
            throw TestGPGHomeError.agentStartFailed(result.stderr ?? "gpg-connect-agent failed")
        }
    }

    func killAgent(timeout: TimeInterval = 10) async {
        guard let gpgConfURL, FileManager.default.fileExists(atPath: gpgConfURL.path) else {
            return
        }

        _ = try? await executor.execute(
            executableURL: gpgConfURL,
            arguments: ["--kill", "gpg-agent"],
            environment: [:],
            gpgHome: homeURL,
            input: nil,
            timeout: timeout
        )
    }

    var homePermissions: Int? {
        guard
            let permissions = try? FileManager.default.attributesOfItem(atPath: homeURL.path)[.posixPermissions] as? NSNumber
        else {
            return nil
        }
        return permissions.intValue & 0o777
    }

    func cleanup() {
        guard !didCleanup else { return }
        didCleanup = true
        try? FileManager.default.removeItem(at: rootURL)
    }
}

enum TestGPGHomeError: Error, CustomStringConvertible {
    case bundleNotFound
    case agentStartFailed(String)

    var description: String {
        switch self {
        case .bundleNotFound:
            return "gpg.bundle was not found in the test bundle"
        case .agentStartFailed(let message):
            return "Failed to start gpg-agent: \(message)"
        }
    }
}

extension TestGPGHome {
    func requireKyberSupport() async throws {
        let result = try await execute(arguments: ["--with-colons", "--list-config"])
        let capabilities = GPGCapabilities.parseListConfig(result.stdout ?? "")
        guard capabilities.supportsKyber else {
            throw GPGError.unsupportedKeyType("Kyber-768")
        }
    }

    func generatePostQuantumHybridKey(
        name: String,
        email: String,
        passphrase: String?
    ) async throws -> String {
        try await ensureAgentRunning()

        let userID = "\(name) <\(email)>"
        let result = try await execute(
            arguments: GPGCommandBuilder.postQuantumHybridKeyGenerationArguments(userID: userID),
            input: GPGCommandBuilder.postQuantumHybridKeyGenerationInput(passphrase: passphrase),
            timeout: 60
        )

        guard result.exitCode == 0 else {
            throw GPGError.keyGenerationFailed(result.stderr ?? result.stdout ?? "PQC key generation failed")
        }

        guard let output = result.stdout,
              let fingerprint = GPGService.keyCreatedFingerprint(from: output) else {
            throw GPGError.keyGenerationFailed("Missing generated PQC key fingerprint")
        }

        return fingerprint
    }

    func exportPublicKey(keyID: String) async throws -> String {
        let result = try await execute(arguments: ["--armor", "--export", keyID])
        guard result.exitCode == 0, let output = result.stdout, !output.isEmpty else {
            throw GPGError.exportFailed(result.stderr ?? "Failed to export public key")
        }
        return output
    }

    func exportSecretKey(keyID: String, passphrase: String) async throws -> String {
        try await ensureAgentRunning()

        let result = try await execute(
            arguments: [
                "--armor",
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--export-secret-key",
                "--",
                keyID
            ],
            input: passphrase + "\n"
        )
        guard result.exitCode == 0, let output = result.stdout, !output.isEmpty else {
            if let credentialError = GPGService.credentialFailureError(from: result) {
                throw credentialError
            }
            throw GPGError.exportFailed(result.stderr ?? result.stdout ?? "Failed to export secret key")
        }
        return output
    }

    @discardableResult
    func importArmor(_ armor: String) async throws -> GPGExecutionResult {
        let result = try await execute(arguments: ["--batch", "--import"], input: armor)
        guard result.exitCode == 0 else {
            throw GPGError.importFailed(result.stderr ?? result.stdout ?? "Failed to import armored key")
        }
        return result
    }

    func encryptText(
        _ plaintext: String,
        recipients: [String],
        allowUntrustedRecipients: Bool
    ) async throws -> String {
        var arguments = [
            "--encrypt",
            "--armor",
            "--batch",
            "--cipher-algo", Constants.GPG.defaultCipherAlgorithm
        ]

        if allowUntrustedRecipients {
            arguments.append(contentsOf: ["--trust-model", "always"])
        }

        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }

        let result = try await execute(arguments: arguments, input: plaintext)
        guard result.exitCode == 0, let output = result.stdout, !output.isEmpty else {
            throw GPGError.encryptionFailed(result.stderr ?? result.stdout ?? "PQC text encryption failed")
        }
        return output
    }

    func decryptTextResult(_ ciphertext: String, passphrase: String) async throws -> GPGExecutionResult {
        try await ensureAgentRunning()
        return try await execute(
            arguments: ["--decrypt", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0"],
            input: passphrase + "\n" + ciphertext
        )
    }

    func decryptText(_ ciphertext: String, passphrase: String) async throws -> String {
        let result = try await decryptTextResult(ciphertext, passphrase: passphrase)
        guard result.exitCode == 0, let output = result.stdout, !output.isEmpty else {
            if let credentialError = GPGService.credentialFailureError(from: result) {
                throw credentialError
            }
            throw GPGError.decryptionFailed(result.stderr ?? result.stdout ?? "PQC text decryption failed")
        }
        return output
    }

    func encryptFile(
        sourceURL: URL,
        destinationURL: URL,
        recipients: [String],
        allowUntrustedRecipients: Bool
    ) async throws -> URL {
        var arguments = [
            "--encrypt",
            "--batch",
            "--yes",
            "--cipher-algo", Constants.GPG.defaultCipherAlgorithm
        ]

        if allowUntrustedRecipients {
            arguments.append(contentsOf: ["--trust-model", "always"])
        }

        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }

        arguments.append(contentsOf: ["--output", destinationURL.path, "--", sourceURL.path])

        let result = try await execute(arguments: arguments)
        guard result.exitCode == 0, FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw GPGError.encryptionFailed(result.stderr ?? result.stdout ?? "PQC file encryption failed")
        }

        return destinationURL
    }

    func decryptFileResult(
        sourceURL: URL,
        destinationURL: URL,
        passphrase: String
    ) async throws -> GPGExecutionResult {
        try await ensureAgentRunning()
        return try await execute(
            arguments: [
                "--decrypt",
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--status-fd", "1",
                "--output", destinationURL.path,
                "--", sourceURL.path
            ],
            input: passphrase + "\n"
        )
    }

    func decryptFile(
        sourceURL: URL,
        destinationURL: URL,
        passphrase: String
    ) async throws -> URL {
        let result = try await decryptFileResult(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            passphrase: passphrase
        )

        guard result.exitCode == 0, FileManager.default.fileExists(atPath: destinationURL.path) else {
            if let credentialError = GPGService.credentialFailureError(from: result) {
                throw credentialError
            }
            throw GPGError.decryptionFailed(result.stderr ?? result.stdout ?? "PQC file decryption failed")
        }

        return destinationURL
    }
}
