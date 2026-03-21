//
//  GPGService.swift
//  Moaiy
//
//  Core GPG service for encryption, decryption, and key management
//

import Foundation
import os.log

/// Service class for GPG operations
@MainActor
@Observable
final class GPGService {
    
    private let logger = Logger(subsystem: "com.moaiy.app", category: "GPGService")
    
    // MARK: - Singleton
    
    static let shared = GPGService()
    
    // MARK: - Properties
    
    private(set) var isReady = false
    private(set) var gpgVersion: String?
    
    // MARK: - Private Properties
    
    private var gpgURL: URL?
    private var gpgHome: URL?
    
    private var gpgPath: String {
        gpgURL?.path ?? ""
    }
    
    // MARK: - Constants
    
    private let gpgBundleName = "gpg.bundle"
    private let gpgExecutableName = "gpg"
    
    // MARK: - Initialization
    
    private init() {
        setupGPG()
    }
    
    // MARK: - Setup
    
    /// Setup GPG executable and environment
    private func setupGPG() {
        Task {
            do {
                try findGPGExecutable()
                logger.info("Found GPG at: \(self.gpgPath)")
                try setupGPGHome()
                logger.info("GPG home directory: \(self.gpgHome?.path ?? "nil")")
                try await verifyGPG()
                logger.info("GPG version: \(self.gpgVersion ?? "unknown")")
                self.isReady = true
                logger.info("Setup complete, isReady = true")
            } catch {
                logger.error("Setup failed: \(error.localizedDescription)")
                self.isReady = false
            }
        }
    }
    
    /// Find GPG executable in app bundle
    private func findGPGExecutable() throws {
        logger.debug("Looking for GPG executable...")
        
        // Look for bundled GPG first
        if let bundleURL = Bundle.main.url(forResource: gpgBundleName, withExtension: nil) {
            logger.debug("Found gpg.bundle at: \(bundleURL.path)")
            let executableURL = bundleURL.appendingPathComponent("bin/\(gpgExecutableName)")
            if FileManager.default.fileExists(atPath: executableURL.path) {
                gpgURL = executableURL
                logger.info("Using bundled GPG: \(executableURL.path)")
                return
            }
        } else {
            logger.debug("No gpg.bundle found in app bundle")
        }
        
        // Fallback to system GPG (for development)
        let systemPath = "/usr/local/bin/gpg"
        logger.debug("Checking system path: \(systemPath), exists: \(FileManager.default.fileExists(atPath: systemPath))")
        if FileManager.default.fileExists(atPath: systemPath) {
            gpgURL = URL(fileURLWithPath: systemPath)
            logger.info("Using system GPG: \(systemPath)")
            return
        }
        
        // Try Homebrew path
        let homebrewPath = "/opt/homebrew/bin/gpg"
        logger.debug("Checking homebrew path: \(homebrewPath), exists: \(FileManager.default.fileExists(atPath: homebrewPath))")
        if FileManager.default.fileExists(atPath: homebrewPath) {
            gpgURL = URL(fileURLWithPath: homebrewPath)
            logger.info("Using Homebrew GPG: \(homebrewPath)")
            return
        }
        
        throw GPGError.gpgNotFound
    }
    
    /// Setup GPG home directory in app container
    private func setupGPGHome() throws {
        // For development: use system's ~/.gnupg to access existing keys
        // For production: use app's own gnupg directory with bundled GPG
        
        // Development mode: use system GPG home to access existing keys
        let systemGPGHome = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gnupg")
        if FileManager.default.fileExists(atPath: systemGPGHome.path) {
            gpgHome = systemGPGHome
            logger.info("Using system GPG home (development mode): \(systemGPGHome.path)")
            return
        }
        
        // Production: create app-specific GPG home
        guard let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw GPGError.fileAccessDenied("Application Support directory")
        }
        
        let gnupgHome = containerURL.appendingPathComponent("gnupg")
        
        if !FileManager.default.fileExists(atPath: gnupgHome.path) {
            try FileManager.default.createDirectory(at: gnupgHome, withIntermediateDirectories: true)
            
            // Set appropriate permissions for GPG home
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: gnupgHome.path
            )
        }
        
        gpgHome = gnupgHome
    }
    
    /// Verify GPG is working
    private func verifyGPG() async throws {
        let result = try await executeGPG(arguments: ["--version"])
        
        if let output = result.stdout {
            let version = output.components(separatedBy: "\n").first ?? "Unknown"
            self.gpgVersion = version
        }
    }
    
    // MARK: - Key Management
    
    /// List all keys (public and secret)
    /// - Parameter secretOnly: If true, only list secret keys
    /// - Returns: Array of GPGKey objects
    func listKeys(secretOnly: Bool = false) async throws -> [GPGKey] {
        let arguments = secretOnly
            ? ["--list-secret-keys", "--with-colons", "--fixed-list-mode"]
            : ["--list-keys", "--with-colons", "--fixed-list-mode"]
        
        let result = try await executeGPG(arguments: arguments)
        
        guard let output = result.stdout else {
            throw GPGError.invalidOutput("No output from key list")
        }
        
        return parseKeyList(output, secretOnly: secretOnly)
    }
    
    /// Generate a new key pair
    /// - Parameters:
    ///   - name: User's name
    ///   - email: User's email
    ///   - keyType: Key type (RSA-4096, RSA-2048, ECC)
    ///   - passphrase: Optional passphrase for the key
    /// - Returns: Fingerprint of the generated key
    func generateKey(name: String, email: String, keyType: KeyType, passphrase: String? = nil) async throws -> String {
        // Build key generation parameters
        let keyParams = buildKeyGenerationParams(
            name: name,
            email: email,
            keyType: keyType,
            passphrase: passphrase
        )
        
        let result = try await executeGPG(
            arguments: ["--batch", "--gen-key", "--status-fd", "1"],
            input: keyParams
        )
        
        // Extract fingerprint from output
        guard let output = result.stdout,
              let fingerprintRange = output.range(of: "KEY_CREATED ([A-Z]+) ", options: .regularExpression) else {
            throw GPGError.keyGenerationFailed("Failed to get key fingerprint")
        }
        
        let fingerprintStart = fingerprintRange.upperBound
        let fingerprintEnd = output.index(fingerprintStart, offsetBy: 40)
        let fingerprint = String(output[fingerprintStart..<fingerprintEnd])
        
        return fingerprint
    }
    
    /// Import a key from file
    /// - Parameter fileURL: URL of the key file
    /// - Returns: Import results
    func importKey(from fileURL: URL) async throws -> KeyImportResult {
        let result = try await executeGPG(
            arguments: ["--import", "--status-fd", "1", fileURL.path]
        )
        
        guard let output = result.stdout else {
            throw GPGError.importFailed("No output from import")
        }
        
        return parseImportResult(output)
    }
    
    /// Export a public key
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - armor: If true, export in ASCII armor format
    /// - Returns: Exported key data
    func exportPublicKey(keyID: String, armor: Bool = true) async throws -> Data {
        var arguments = ["--export", keyID]
        if armor {
            arguments.insert("--armor", at: 0)
        }
        
        let result = try await executeGPG(arguments: arguments)
        
        guard let data = result.data else {
            throw GPGError.exportFailed("No key data exported")
        }
        
        return data
    }
    
    /// Export a secret key
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - passphrase: Key passphrase
    ///   - armor: If true, export in ASCII armor format
    /// - Returns: Exported key data
    func exportSecretKey(keyID: String, passphrase: String, armor: Bool = true) async throws -> Data {
        var arguments = ["--export-secret-key", "--batch", "--yes", keyID]
        if armor {
            arguments.insert("--armor", at: 0)
        }
        
        // Set passphrase via environment
        let result = try await executeGPG(
            arguments: arguments,
            environment: ["GPG_PASSPHRASE": passphrase]
        )
        
        guard let data = result.data else {
            throw GPGError.exportFailed("No key data exported")
        }
        
        return data
    }
    
    /// Delete a key
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - secret: If true, delete secret key
    func deleteKey(keyID: String, secret: Bool = false) async throws {
        var arguments = ["--batch", "--yes", "--delete-keys", keyID]
        if secret {
            arguments = ["--batch", "--yes", "--delete-secret-keys", keyID]
        }
        
        _ = try await executeGPG(arguments: arguments)
    }
    
    // MARK: - Encryption & Decryption
    
    /// Encrypt text
    /// - Parameters:
    ///   - text: Text to encrypt
    ///   - recipients: Array of key IDs to encrypt for
    ///   - sign: If true, also sign the message
    ///   - signingKey: Key ID to sign with (required if sign is true)
    /// - Returns: Encrypted text
    func encrypt(text: String, recipients: [String], sign: Bool = false, signingKey: String? = nil) async throws -> String {
        var arguments = ["--encrypt", "--armor", "--batch"]
        
        // Add recipients
        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }
        
        // Add signing if requested
        if sign, let signingKey = signingKey {
            arguments.append(contentsOf: ["--sign", "--local-user", signingKey])
        }
        
        let result = try await executeGPG(arguments: arguments, input: text)
        
        guard let output = result.stdout else {
            throw GPGError.encryptionFailed("No output from encryption")
        }
        
        return output
    }
    
    /// Decrypt text
    /// - Parameters:
    ///   - text: Text to decrypt
    ///   - passphrase: Passphrase for the private key
    /// - Returns: Decrypted text
    func decrypt(text: String, passphrase: String) async throws -> String {
        let result = try await executeGPG(
            arguments: ["--decrypt", "--batch", "--passphrase-fd", "0"],
            input: passphrase + "\n" + text
        )
        
        guard let output = result.stdout else {
            throw GPGError.decryptionFailed("No output from decryption")
        }
        
        return output
    }
    
    /// Encrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - recipients: Array of key IDs to encrypt for
    ///   - armor: If true, output ASCII armor format
    func encryptFile(sourceURL: URL, destinationURL: URL, recipients: [String], armor: Bool = false) async throws {
        var arguments = ["--encrypt", "--batch", "--yes"]
        
        // Add recipients
        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }
        
        // Add armor flag
        if armor {
            arguments.append("--armor")
        }
        
        // Add input/output
        arguments.append(contentsOf: ["--output", destinationURL.path, sourceURL.path])
        
        _ = try await executeGPG(arguments: arguments)
    }
    
    /// Decrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - passphrase: Passphrase for the private key
    func decryptFile(sourceURL: URL, destinationURL: URL, passphrase: String) async throws {
        let result = try await executeGPG(
            arguments: [
                "--decrypt",
                "--batch",
                "--yes",
                "--passphrase-fd", "0",
                "--output", destinationURL.path,
                sourceURL.path
            ],
            input: passphrase
        )
        
        if result.exitCode != 0 {
            throw GPGError.decryptionFailed(result.stderr ?? "Unknown error")
        }
    }
    
    // MARK: - Signing & Verification
    
    /// Sign text
    /// - Parameters:
    ///   - text: Text to sign
    ///   - keyID: Key ID to sign with
    ///   - passphrase: Passphrase for the private key
    ///   - clearSign: If true, use clear-sign format
    /// - Returns: Signed text
    func sign(text: String, keyID: String, passphrase: String, clearSign: Bool = true) async throws -> String {
        var arguments = ["--batch", "--passphrase-fd", "0", "--local-user", keyID]
        
        if clearSign {
            arguments.append("--clearsign")
        } else {
            arguments.append("--sign")
        }
        
        arguments.append("--armor")
        
        let result = try await executeGPG(arguments: arguments, input: passphrase + "\n" + text)
        
        guard let output = result.stdout else {
            throw GPGError.encryptionFailed("No output from signing")
        }
        
        return output
    }
    
    /// Verify a signature
    /// - Parameter text: Signed text to verify
    /// - Returns: Verification result
    func verify(text: String) async throws -> VerificationResult {
        let result = try await executeGPG(
            arguments: ["--verify", "--status-fd", "1"],
            input: text
        )
        
        guard let output = result.stdout else {
            throw GPGError.invalidOutput("No output from verification")
        }
        
        return parseVerificationResult(output)
    }
    
    // MARK: - Trust Management
    
    /// Check the trust level of a key
    /// - Parameter keyID: Key ID or fingerprint
    /// - Returns: Current trust level
    func checkTrust(keyID: String) async throws -> TrustLevel {
        let result = try await executeGPG(
            arguments: ["--list-keys", "--with-colons", "--fixed-list-mode", keyID]
        )
        
        guard let output = result.stdout else {
            throw GPGError.invalidOutput("No output from key list")
        }
        
        // Parse trust from output
        for line in output.components(separatedBy: "\n") {
            let fields = line.components(separatedBy: ":")
            if (fields[0] == "pub" || fields[0] == "sec") && fields.count >= 9 {
                return TrustLevel(gpgCode: fields[8]) ?? .unknown
            }
        }
        
        return .unknown
    }
    
    /// Set the owner trust level for a key
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - trustLevel: Trust level to set
    func setTrust(keyID: String, trustLevel: TrustLevel) async throws {
        // Use --edit-key with trust command
        let trustCommand = "trust\n\(trustLevel.gpgCode)\ny\n"
        
        let result = try await executeGPG(
            arguments: ["--command-fd", "0", "--edit-key", keyID],
            input: trustCommand
        )
        
        if result.exitCode != 0 {
            throw GPGError.trustUpdateFailed(result.stderr ?? "Unknown error")
        }
    }
    
    /// Update the trust database
    func updateTrustDB() async throws {
        let result = try await executeGPG(arguments: ["--check-trustdb"])
        
        if result.exitCode != 0 {
            throw GPGError.trustUpdateFailed(result.stderr ?? "Unknown error")
        }
    }
    
    /// Sign a key to indicate trust
    /// - Parameters:
    ///   - keyID: Key ID to sign
    ///   - signerKeyID: Your key ID to sign with (optional, uses default)
    ///   - passphrase: Passphrase for signing key
    ///   - trustLevel: Local trust level to set after signing
    func signKey(keyID: String, signerKeyID: String?, passphrase: String, trustLevel: TrustLevel? = nil) async throws {
        var arguments = ["--command-fd", "0", "--batch", "--yes"]
        
        if let signerKeyID = signerKeyID {
            arguments.append(contentsOf: ["--local-user", signerKeyID])
        }
        
        arguments.append(contentsOf: ["--sign-key", keyID])
        
        var input = passphrase + "\n"
        if let trustLevel = trustLevel {
            input += "trust\n\(trustLevel.gpgCode)\ny\nsave\n"
        }
        
        let result = try await executeGPG(arguments: arguments, input: input)
        
        if result.exitCode != 0 {
            throw GPGError.keySigningFailed(result.stderr ?? "Unknown error")
        }
    }
    
    /// Check key validity and trust details
    /// - Parameter keyID: Key ID or fingerprint
    /// - Returns: Detailed trust information
    func getTrustDetails(keyID: String) async throws -> KeyTrustDetails {
        let result = try await executeGPG(
            arguments: ["--list-keys", "--with-colons", "--fixed-list-mode", "--with-fingerprint", keyID]
        )
        
        guard let output = result.stdout else {
            throw GPGError.invalidOutput("No output from key list")
        }
        
        var ownerTrust: TrustLevel = .unknown
        var calculatedTrust: TrustLevel = .unknown
        var signatureCount = 0
        
        for line in output.components(separatedBy: "\n") {
            let fields = line.components(separatedBy: ":")
            
            switch fields[0] {
            case "pub", "sec":
                if fields.count >= 9 {
                    ownerTrust = TrustLevel(gpgCode: fields[8]) ?? .unknown
                }
            case "uid":
                if fields.count >= 9 {
                    calculatedTrust = TrustLevel(gpgCode: fields[8]) ?? .unknown
                }
            case "sig":
                signatureCount += 1
            default:
                break
            }
        }
        
        return KeyTrustDetails(
            keyID: keyID,
            ownerTrust: ownerTrust,
            calculatedTrust: calculatedTrust,
            signatureCount: signatureCount
        )
    }
    
    // MARK: - Private Helpers
    
    /// Execute GPG command
    private func executeGPG(
        arguments: [String],
        input: String? = nil,
        environment: [String: String] = [:]
    ) async throws -> GPGExecutionResult {
        guard let gpgURL = gpgURL else {
            throw GPGError.gpgNotFound
        }
        
        let process = Process()
        process.executableURL = gpgURL
        process.arguments = arguments
        
        // Set environment
        var env = ProcessInfo.processInfo.environment
        
        // Set GPG home directory
        if let gpgHome = gpgHome {
            env["GNUPGHOME"] = gpgHome.path
        }
        
        // Add custom environment variables
        for (key, value) in environment {
            env[key] = value
        }
        
        process.environment = env
        
        // Setup pipes
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        var stdinPipe: Pipe?
        
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        if input != nil {
            stdinPipe = Pipe()
            process.standardInput = stdinPipe
        }
        
        // Execute
        do {
            try process.run()
            
            // Write input if provided
            if let input = input, let stdinPipe = stdinPipe {
                let inputData = input.data(using: .utf8)
                stdinPipe.fileHandleForWriting.write(inputData ?? Data())
                try? stdinPipe.fileHandleForWriting.close()
            }
            
            process.waitUntilExit()
        } catch {
            throw GPGError.executionFailed(error.localizedDescription)
        }
        
        // Read output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let result = GPGExecutionResult(
            exitCode: Int(process.terminationStatus),
            stdout: stdout?.isEmpty == false ? stdout : nil,
            stderr: stderr?.isEmpty == false ? stderr : nil,
            data: stdoutData.isEmpty ? nil : stdoutData
        )
        
        return result
    }
    
    /// Parse key list output
    private func parseKeyList(_ output: String, secretOnly: Bool) -> [GPGKey] {
        var keys: [GPGKey] = []
        var currentKey: GPGKeyBuilder?
        
        for line in output.components(separatedBy: "\n") {
            let fields = line.components(separatedBy: ":")
            
            guard fields.count >= 1 else { continue }
            
            let recordType = fields[0]
            
            switch recordType {
            case "pub", "sec":
                // Start of a new key
                if let key = currentKey?.build() {
                    keys.append(key)
                }
                currentKey = GPGKeyBuilder()
                currentKey?.isSecret = secretOnly
                if fields.count >= 10 {
                    currentKey?.keyID = fields[4]
                    currentKey?.createdAt = parseTimestamp(fields[5])
                    currentKey?.expiresAt = parseTimestamp(fields[6])
                    currentKey?.algorithm = fields[3]
                    currentKey?.keyLength = Int(fields[2]) ?? 0
                    currentKey?.fingerprint = fields[4] // Will be overwritten by fpr record
                    // Field 8 is ownertrust for pub records
                    if fields.count >= 9 {
                        currentKey?.trustLevel = TrustLevel(gpgCode: fields[8]) ?? .unknown
                    }
                }
                
            case "fpr":
                if fields.count >= 10 {
                    currentKey?.fingerprint = fields[9]
                }
                
            case "uid":
                if fields.count >= 10 {
                    let userID = fields[9]
                    // Parse name and email from "Name <email>"
                    if let emailRange = userID.range(of: "<(.+)>", options: .regularExpression) {
                        let emailStart = userID.index(emailRange.lowerBound, offsetBy: 1)
                        let emailEnd = userID.index(emailRange.upperBound, offsetBy: -1)
                        currentKey?.email = String(userID[emailStart..<emailEnd])
                        currentKey?.name = String(userID[userID.startIndex..<emailRange.lowerBound])
                            .trimmingCharacters(in: .whitespaces)
                    } else {
                        currentKey?.name = userID
                    }
                    // UID record field 8 contains the calculated trust
                    if fields.count >= 9, currentKey?.trustLevel == .unknown {
                        currentKey?.trustLevel = TrustLevel(gpgCode: fields[8]) ?? .unknown
                    }
                }
            default:
                break
            }
        }
        
        // Add last key
        if let key = currentKey?.build() {
            keys.append(key)
        }
        
        return keys
    }
    
    /// Parse timestamp
    private func parseTimestamp(_ string: String) -> Date? {
        guard let timestamp = Double(string), timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// Build key generation parameters
    private func buildKeyGenerationParams(
        name: String,
        email: String,
        keyType: KeyType,
        passphrase: String?
    ) -> String {
        var params = """
        %echo Generating key
        Key-Type: \(keyType.gpgKeyType)
        Key-Length: \(keyType.keyLength)
        Key-Usage: sign,encrypt
        Subkey-Type: \(keyType.gpgSubkeyType)
        Subkey-Length: \(keyType.subkeyLength)
        Subkey-Usage: encrypt
        Name-Real: \(name)
        Name-Email: \(email)
        Expire-Date: 0
        
        """
        
        if let passphrase = passphrase, !passphrase.isEmpty {
            params += "Passphrase: \(passphrase)\n"
        } else {
            params += "%no-protection\n"
        }
        
        params += "%commit\n%echo Key generation complete\n"
        
        return params
    }
    
    /// Parse import result
    private func parseImportResult(_ output: String) -> KeyImportResult {
        var imported = 0
        var unchanged = 0
        var newKeys: [String] = []
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("IMPORT_OK") {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 4 {
                    newKeys.append(parts[3])
                }
            }
            if line.contains("IMPORT_RES") {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    imported = Int(parts[1]) ?? 0
                    unchanged = Int(parts[2]) ?? 0
                }
            }
        }
        
        return KeyImportResult(
            imported: imported,
            unchanged: unchanged,
            newKeyIDs: newKeys
        )
    }
    
    /// Parse verification result
    private func parseVerificationResult(_ output: String) -> VerificationResult {
        var isValid = false
        var signerKeyID: String?
        var timestamp: Date?
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("GOODSIG") {
                isValid = true
                let parts = line.components(separatedBy: " ")
                if parts.count >= 3 {
                    signerKeyID = parts[2]
                }
            }
            if line.contains("VALIDSIG") {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 4 {
                    if let ts = Double(parts[3]) {
                        timestamp = Date(timeIntervalSince1970: ts)
                    }
                }
            }
        }
        
        return VerificationResult(
            isValid: isValid,
            signerKeyID: signerKeyID,
            timestamp: timestamp
        )
    }
}

// MARK: - Supporting Types

/// GPG execution result
struct GPGExecutionResult {
    let exitCode: Int
    let stdout: String?
    let stderr: String?
    let data: Data?
}

/// GPG Key trust level
enum TrustLevel: String, CaseIterable, Identifiable {
    case unknown = "unknown"
    case none = "none"
    case marginal = "marginal"
    case full = "full"
    case ultimate = "ultimate"
    
    var id: String { rawValue }
    
    /// GPG trust database character code
    var gpgCode: String {
        switch self {
        case .unknown: return "-"
        case .none: return "n"
        case .marginal: return "m"
        case .full: return "f"
        case .ultimate: return "u"
        }
    }
    
    /// Initialize from GPG colon output code
    init?(gpgCode: String) {
        switch gpgCode {
        case "-", "": self = .unknown
        case "n": self = .none
        case "m": self = .marginal
        case "f": self = .full
        case "u": self = .ultimate
        default: return nil
        }
    }
    
    /// Display name for UI (non-localized, for debugging)
    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .none: return "None"
        case .marginal: return "Marginal"
        case .full: return "Full"
        case .ultimate: return "Ultimate"
        }
    }
    
    /// Localized name for UI
    var localizedName: String {
        switch self {
        case .unknown: return String(localized: "trust_level_unknown")
        case .none: return String(localized: "trust_level_none")
        case .marginal: return String(localized: "trust_level_marginal")
        case .full: return String(localized: "trust_level_full")
        case .ultimate: return String(localized: "trust_level_ultimate")
    }
    }
    
    /// Localized description of trust level
    var localizedDescription: String {
        switch self {
        case .unknown: return String(localized: "trust_desc_unknown")
        case .none: return String(localized: "trust_desc_none")
        case .marginal: return String(localized: "trust_desc_marginal")
        case .full: return String(localized: "trust_desc_full")
        case .ultimate: return String(localized: "trust_desc_ultimate")
        }
    }
}

/// GPG Key model
struct GPGKey: Identifiable, Hashable {
    let id: String
    let keyID: String
    let fingerprint: String
    let name: String
    let email: String
    let algorithm: String
    let keyLength: Int
    let isSecret: Bool
    let createdAt: Date?
    let expiresAt: Date?
    let trustLevel: TrustLevel
    
    /// Display-friendly key type
    var displayKeyType: String {
        "\(algorithm)-\(keyLength)"
    }
    
    /// Check if key is expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }
    
    /// Check if key is trusted enough for encryption
    var isTrusted: Bool {
        trustLevel == .full || trustLevel == .ultimate
    }
}

/// Key import result
struct KeyImportResult {
    let imported: Int
    let unchanged: Int
    let newKeyIDs: [String]
}

/// Verification result
struct VerificationResult {
    let isValid: Bool
    let signerKeyID: String?
    let timestamp: Date?
}

/// Key trust details
struct KeyTrustDetails {
    let keyID: String
    let ownerTrust: TrustLevel
    let calculatedTrust: TrustLevel
    let signatureCount: Int
    
    /// Whether the key is considered trusted for encryption
    var isTrusted: Bool {
        calculatedTrust == .full || calculatedTrust == .ultimate
    }
    
    /// Whether the key has been signed by others
    var hasSignatures: Bool {
        signatureCount > 0
    }
}

/// Key type enum
enum KeyType: String, CaseIterable, Identifiable {
    case rsa4096 = "RSA-4096"
    case rsa2048 = "RSA-2048"
    case ecc = "ECC"
    
    var id: String { rawValue }
    
    var gpgKeyType: String {
        switch self {
        case .rsa4096, .rsa2048: return "RSA"
        case .ecc: return "EDDSA"
        }
    }
    
    var gpgSubkeyType: String {
        switch self {
        case .rsa4096, .rsa2048: return "RSA"
        case .ecc: return "ECDH"
        }
    }
    
    var keyLength: Int {
        switch self {
        case .rsa4096: return 4096
        case .rsa2048: return 2048
        case .ecc: return 0 // Curve25519 doesn't use length
        }
    }
    
    var subkeyLength: Int {
        switch self {
        case .rsa4096: return 4096
        case .rsa2048: return 2048
        case .ecc: return 0 // Curve25519 doesn't use length
        }
    }
    
    var curve: String? {
        switch self {
        case .ecc: return "cv25519"
        default: return nil
        }
    }
}

/// Helper class for building GPGKey
private class GPGKeyBuilder {
    var keyID: String = ""
    var fingerprint: String = ""
    var name: String = ""
    var email: String = ""
    var algorithm: String = ""
    var keyLength: Int = 0
    var isSecret: Bool = false
    var createdAt: Date?
    var expiresAt: Date?
    var trustLevel: TrustLevel = .unknown
    
    func build() -> GPGKey? {
        guard !fingerprint.isEmpty else { return nil }
        return GPGKey(
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
}
