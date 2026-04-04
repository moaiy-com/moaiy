//
//  GPGService.swift
//  Moaiy
//
//  Core GPG service for encryption, decryption, and key management
//

import Foundation
import os.log

private final class PipeAccumulator {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        buffer.append(data)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}

// MARK: - GPG Process Actor

/// Actor for executing GPG commands off the main thread
actor GPGProcessExecutor {

    /// Execute a GPG command
    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        gpgHome: URL?,
        input: String?,
        timeout: TimeInterval = Constants.GPG.defaultTimeout
    ) async throws -> GPGExecutionResult {
        
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        
        // Set environment
        var env = ProcessInfo.processInfo.environment
        if let gpgHome = gpgHome {
            env["GNUPGHOME"] = gpgHome.path
        }
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
        
        let stdoutAccumulator = PipeAccumulator()
        let stderrAccumulator = PipeAccumulator()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stdoutAccumulator.append(chunk)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stderrAccumulator.append(chunk)
        }

        // Execute with timeout
        try process.run()
        
        // Write input if provided
        if let input = input, let stdinPipe = stdinPipe {
            let inputData = input.data(using: .utf8) ?? Data()
            stdinPipe.fileHandleForWriting.write(inputData)
            try? stdinPipe.fileHandleForWriting.close()
        }
        
        // Wait for completion with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if process.isRunning {
            process.terminate()

            let terminateDeadline = Date().addingTimeInterval(1.0)
            while process.isRunning && Date() < terminateDeadline {
                try await Task.sleep(nanoseconds: 50_000_000)
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            let timeoutStderr = String(data: stderrAccumulator.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let timeoutStdout = String(data: stdoutAccumulator.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let timeoutMessage: String?
            if let timeoutStderr, !timeoutStderr.isEmpty {
                timeoutMessage = timeoutStderr
            } else if let timeoutStdout, !timeoutStdout.isEmpty {
                timeoutMessage = timeoutStdout
            } else {
                timeoutMessage = nil
            }
            let fallbackMessage = "Operation timed out after \(Int(timeout)) seconds"
            throw GPGError.executionFailed(timeoutMessage?.isEmpty == false ? timeoutMessage! : fallbackMessage)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        // Capture any trailing bytes after readability handlers are removed.
        let stdoutTail = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrTail = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutAccumulator.append(stdoutTail)
        stderrAccumulator.append(stderrTail)

        let stdoutData = stdoutAccumulator.data
        let stderrData = stderrAccumulator.data
        
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return GPGExecutionResult(
            exitCode: Int(process.terminationStatus),
            stdout: stdout?.isEmpty == false ? stdout : nil,
            stderr: stderr?.isEmpty == false ? stderr : nil,
            data: stdoutData.isEmpty ? nil : stdoutData
        )
    }
}

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
    private(set) var isUsingExternalGPGHome = false
    
    // MARK: - Private Properties
    
    private var gpgURL: URL?
    private var gpgHome: URL?
    private var scopedExternalGPGHomeURL: URL?
    private var gpgAgentURL: URL?
    private var gpgConnectAgentURL: URL?

    private let defaults = UserDefaults.standard
    private let useExternalGPGHomeKey = Constants.StorageKeys.useExternalGPGHome
    private let externalGPGHomeBookmarkKey = Constants.StorageKeys.externalGPGHomeBookmark
    
    private var gpgPath: String {
        gpgURL?.path ?? ""
    }

    var activeGPGHomePath: String {
        gpgHome?.path ?? ""
    }

    var systemGPGHomeURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".gnupg")
    }
    
    /// Actor for executing GPG commands off the main thread
    private let processExecutor = GPGProcessExecutor()
    
    // MARK: - Constants
    
    private let gpgBundleName = Constants.GPG.bundleName
    private let gpgExecutableName = Constants.GPG.executableName
    
    /// Default timeout for GPG operations (in seconds)
    static let defaultTimeout = Constants.GPG.defaultTimeout

    static let isDebugBuild: Bool = {
#if DEBUG
        true
#else
        false
#endif
    }()

    static func allowsExternalGPGFallback(isDebugBuild: Bool) -> Bool {
        isDebugBuild
    }

    static func allowsSystemGPGHomeOverride(isDebugBuild: Bool, environment: [String: String]) -> Bool {
        guard isDebugBuild else {
            return false
        }
        return environment["MOAIY_USE_SYSTEM_GNUPG"] == "1"
    }
    
    // MARK: - Initialization
    
    private init() {
        setupGPG()
    }
    
    // MARK: - Setup
    
    /// Setup GPG executable and environment
    private func setupGPG() {
        Task {
            do {
                SecureTempStorage.cleanupStaleDirectories()
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
                configureAgentTools(for: executableURL.deletingLastPathComponent())
                logger.info("Using bundled GPG: \(executableURL.path)")
                return
            }
        } else {
            logger.debug("No gpg.bundle found in app bundle")
        }

        let allowsExternalFallback = Self.allowsExternalGPGFallback(isDebugBuild: Self.isDebugBuild)
        guard allowsExternalFallback else {
            logger.error("Bundled GPG missing in non-debug build; refusing external fallback")
            throw GPGError.gpgNotFound
        }
        
        // Fallback to system GPG (for development)
        let systemPath = "/usr/local/bin/gpg"
        logger.debug("Checking system path: \(systemPath), exists: \(FileManager.default.fileExists(atPath: systemPath))")
        if FileManager.default.fileExists(atPath: systemPath) {
            gpgURL = URL(fileURLWithPath: systemPath)
            configureAgentTools(for: URL(fileURLWithPath: systemPath).deletingLastPathComponent())
            logger.info("Using system GPG: \(systemPath)")
            return
        }
        
        // Try Homebrew path
        let homebrewPath = "/opt/homebrew/bin/gpg"
        logger.debug("Checking homebrew path: \(homebrewPath), exists: \(FileManager.default.fileExists(atPath: homebrewPath))")
        if FileManager.default.fileExists(atPath: homebrewPath) {
            gpgURL = URL(fileURLWithPath: homebrewPath)
            configureAgentTools(for: URL(fileURLWithPath: homebrewPath).deletingLastPathComponent())
            logger.info("Using Homebrew GPG: \(homebrewPath)")
            return
        }
        
        throw GPGError.gpgNotFound
    }

    private func configureAgentTools(for binDirectory: URL) {
        let agent = binDirectory.appendingPathComponent("gpg-agent")
        if FileManager.default.fileExists(atPath: agent.path) {
            gpgAgentURL = agent
        } else {
            gpgAgentURL = nil
        }

        let connectAgent = binDirectory.appendingPathComponent("gpg-connect-agent")
        if FileManager.default.fileExists(atPath: connectAgent.path) {
            gpgConnectAgentURL = connectAgent
        } else {
            gpgConnectAgentURL = nil
        }
    }
    
    /// Setup GPG home directory in app container
    private func setupGPGHome() throws {
        // Keep GNUPGHOME in app-controlled storage by default.
        // Developers can explicitly opt in to system ~/.gnupg during local debugging.
        let systemGPGHome = systemGPGHomeURL
        let useSystemHome = Self.allowsSystemGPGHomeOverride(
            isDebugBuild: Self.isDebugBuild,
            environment: ProcessInfo.processInfo.environment
        )
        if useSystemHome, FileManager.default.fileExists(atPath: systemGPGHome.path) {
            stopScopedExternalGPGHomeAccess()
            gpgHome = systemGPGHome
            isUsingExternalGPGHome = true
            logger.warning("Using system GPG home due to MOAIY_USE_SYSTEM_GNUPG override")
            return
        }

        if defaults.bool(forKey: useExternalGPGHomeKey),
           let externalHome = try resolveExternalGPGHomeFromBookmark() {
            gpgHome = externalHome
            isUsingExternalGPGHome = true
            logger.info("Using external GPG home from bookmark: \(externalHome.path)")
            return
        }

        stopScopedExternalGPGHomeAccess()
        gpgHome = try appManagedGPGHomeURL()
        isUsingExternalGPGHome = false
    }

    func systemGPGHomeLikelyExists() -> Bool {
        FileManager.default.fileExists(atPath: systemGPGHomeURL.path)
    }

    func configureExternalGPGHome(_ url: URL) throws {
        try ensureGPGHomeDirectoryExists(at: url)

        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        defaults.set(bookmarkData, forKey: externalGPGHomeBookmarkKey)
        defaults.set(true, forKey: useExternalGPGHomeKey)

        let accessGranted = url.startAccessingSecurityScopedResource()
        guard accessGranted else {
            defaults.set(false, forKey: useExternalGPGHomeKey)
            defaults.removeObject(forKey: externalGPGHomeBookmarkKey)
            throw GPGError.fileAccessDenied(url.path)
        }

        stopScopedExternalGPGHomeAccess()
        scopedExternalGPGHomeURL = url

        gpgHome = url
        isUsingExternalGPGHome = true
    }

    func useAppManagedGPGHome() throws {
        defaults.set(false, forKey: useExternalGPGHomeKey)
        defaults.removeObject(forKey: externalGPGHomeBookmarkKey)
        stopScopedExternalGPGHomeAccess()
        gpgHome = try appManagedGPGHomeURL()
        isUsingExternalGPGHome = false
    }
    
    /// Verify GPG is working
    private func verifyGPG() async throws {
        let result = try await executeGPG(arguments: ["--version"])
        
        if let output = result.stdout {
            let version = output.components(separatedBy: "\n").first ?? "Unknown"
            self.gpgVersion = version
        }
    }

    private func ensureGPGAgentRunningIfNeeded() async throws {
        guard gpgHome != nil else { return }
        guard gpgAgentURL != nil, gpgConnectAgentURL != nil else { return }

        if await canConnectToGPGAgent() {
            return
        }

        guard let gpgAgentURL else { return }
        let launchResult = try await processExecutor.execute(
            executableURL: gpgAgentURL,
            arguments: ["--daemon"],
            environment: [:],
            gpgHome: gpgHome,
            input: nil,
            timeout: 10
        )

        if launchResult.exitCode != 0 {
            let message = launchResult.stderr ?? "Failed to launch gpg-agent (exit code: \(launchResult.exitCode))"
            throw GPGError.executionFailed(message)
        }

        try await Task.sleep(nanoseconds: 250_000_000)

        guard await canConnectToGPGAgent() else {
            throw GPGError.executionFailed("gpg-agent is not reachable after launch")
        }
    }

    private func canConnectToGPGAgent() async -> Bool {
        guard let gpgConnectAgentURL else { return false }

        do {
            let result = try await processExecutor.execute(
                executableURL: gpgConnectAgentURL,
                arguments: ["/bye"],
                environment: [:],
                gpgHome: gpgHome,
                input: nil,
                timeout: 5
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    private func appManagedGPGHomeURL() throws -> URL {
        let preferredHome = try preferredAppManagedGPGHomeURL()
        let legacyHome = try legacyAppManagedGPGHomeURL()
        let fileManager = FileManager.default

        if preferredHome.path != legacyHome.path,
           !fileManager.fileExists(atPath: preferredHome.path),
           fileManager.fileExists(atPath: legacyHome.path) {
            do {
                try fileManager.moveItem(at: legacyHome, to: preferredHome)
                logger.notice("Migrated app-managed GPG home to shorter path")
            } catch {
                logger.error("Failed to migrate GPG home: \(error.localizedDescription)")
                do {
                    try fileManager.copyItem(at: legacyHome, to: preferredHome)
                    logger.notice("Copied app-managed GPG home to shorter path after move failure")
                } catch {
                    logger.error("Failed to copy GPG home: \(error.localizedDescription)")
                }
            }
        }

        try ensureGPGHomeDirectoryExists(at: preferredHome)
        return preferredHome
    }

    private func preferredAppManagedGPGHomeURL() throws -> URL {
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw GPGError.fileAccessDenied("Library directory")
        }
        return libraryURL.appendingPathComponent("gnupg", isDirectory: true)
    }

    private func legacyAppManagedGPGHomeURL() throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw GPGError.fileAccessDenied("Application Support directory")
        }
        return applicationSupportURL.appendingPathComponent("gnupg", isDirectory: true)
    }

    private func ensureGPGHomeDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
    }

    private func resolveExternalGPGHomeFromBookmark() throws -> URL? {
        guard let bookmarkData = defaults.data(forKey: externalGPGHomeBookmarkKey) else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            let refreshedBookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(refreshedBookmark, forKey: externalGPGHomeBookmarkKey)
        }

        let accessGranted = url.startAccessingSecurityScopedResource()
        guard accessGranted else {
            logger.warning("External GPG home security-scope access denied, falling back to app-managed keyring")
            defaults.set(false, forKey: useExternalGPGHomeKey)
            defaults.removeObject(forKey: externalGPGHomeBookmarkKey)
            stopScopedExternalGPGHomeAccess()
            return nil
        }

        stopScopedExternalGPGHomeAccess()
        scopedExternalGPGHomeURL = url

        try ensureGPGHomeDirectoryExists(at: url)
        return url
    }

    private func stopScopedExternalGPGHomeAccess() {
        scopedExternalGPGHomeURL?.stopAccessingSecurityScopedResource()
        scopedExternalGPGHomeURL = nil
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
            // Empty keyring is a valid state for first launch in release builds.
            if result.exitCode == 0 {
                return []
            }
            let message = result.stderr ?? "No output from key list (exit code: \(result.exitCode))"
            throw GPGError.executionFailed(message)
        }
        
        return parseKeyList(output, secretOnly: secretOnly)
    }

    func inspectKeyring(at homeURL: URL) async throws -> KeyringSnapshot {
        let publicKeys = try await listKeys(at: homeURL, secretOnly: false)
        let secretKeys = try await listKeys(at: homeURL, secretOnly: true)

        return KeyringSnapshot(
            homePath: homeURL.path,
            publicKeyCount: publicKeys.count,
            secretKeyCount: secretKeys.count
        )
    }

    func migrateKeys(fromExternalGPGHome sourceHomeURL: URL) async throws -> KeyMigrationResult {
        let snapshot = try await inspectKeyring(at: sourceHomeURL)

        guard snapshot.totalKeyCount > 0 else {
            return KeyMigrationResult(
                imported: 0,
                unchanged: 0,
                sourcePublicKeyCount: 0,
                sourceSecretKeyCount: 0,
                secretKeysMigrated: false
            )
        }

        var importedTotal = 0
        var unchangedTotal = 0
        var secretKeysMigrated = false

        let publicExport = try await executeGPG(
            arguments: ["--armor", "--export"],
            environment: ["GNUPGHOME": sourceHomeURL.path]
        )
        guard publicExport.exitCode == 0 else {
            throw GPGError.exportFailed(publicExport.stderr ?? "Failed to export public keys")
        }
        if let publicData = publicExport.data, !publicData.isEmpty {
            let importResult = try await importArmorData(publicData, fileName: "migration-public.asc")
            importedTotal += importResult.imported
            unchangedTotal += importResult.unchanged
        }

        let secretExport = try await executeGPG(
            arguments: ["--armor", "--export-secret-keys"],
            environment: ["GNUPGHOME": sourceHomeURL.path]
        )
        if secretExport.exitCode == 0,
           let secretData = secretExport.data,
           !secretData.isEmpty {
            let importResult = try await importArmorData(secretData, fileName: "migration-secret.asc")
            importedTotal += importResult.imported
            unchangedTotal += importResult.unchanged
            secretKeysMigrated = true
        } else if snapshot.secretKeyCount > 0 {
            logger.warning("Secret key migration skipped: \(secretExport.stderr ?? "no export output")")
        }

        return KeyMigrationResult(
            imported: importedTotal,
            unchanged: unchangedTotal,
            sourcePublicKeyCount: snapshot.publicKeyCount,
            sourceSecretKeyCount: snapshot.secretKeyCount,
            secretKeysMigrated: secretKeysMigrated
        )
    }
    
    /// Generate a new key pair
    /// - Parameters:
    ///   - name: User's name
    ///   - email: User's email
    ///   - keyType: Key type (RSA-4096, RSA-2048, ECC)
    ///   - passphrase: Optional passphrase for the key
    /// - Returns: Fingerprint of the generated key
    func generateKey(name: String, email: String, keyType: KeyType, passphrase: String? = nil) async throws -> String {
        try await ensureGPGAgentRunningIfNeeded()

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

        // Check for errors
        if result.exitCode != 0 {
            throw GPGError.keyGenerationFailed(result.stderr ?? "Unknown error (exit code: \(result.exitCode))")
        }

        // Extract fingerprint from output
        guard let output = result.stdout else {
            throw GPGError.keyGenerationFailed("No output from GPG")
        }

        // Try to find KEY_CREATED pattern: [GNUPG:] KEY_CREATED <type> <fingerprint>
        // Example: [GNUPG:] KEY_CREATED P 1A2B3C4D5E6F7A8B9C0D1E2F3A4B5C6D7E8F9A0B
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("KEY_CREATED") {
                let parts = line.components(separatedBy: " ")
                // KEY_CREATED has format: [GNUPG:] KEY_CREATED <type> <fingerprint>
                if parts.count >= 4 {
                    let fingerprint = parts[3].trimmingCharacters(in: .whitespaces)
                    if fingerprint.count == 40 {
                        logger.info("Generated key with fingerprint: \(fingerprint)")
                        return fingerprint
                    }
                }
            }
        }

        // If we get here, the key might have been created but output format is different
        // Try to list the keys to find the new one
        logger.warning("Could not find KEY_CREATED pattern, trying to find key by email")
        let keys = try await listKeys(secretOnly: false)
        if let newKey = keys.first(where: { $0.email == email }) {
            logger.info("Found newly created key: \(newKey.fingerprint)")
            return newKey.fingerprint
        }

        logger.error("Could not find KEY_CREATED pattern in GPG output")
        throw GPGError.keyGenerationFailed("Failed to get key fingerprint")
    }
    
    /// Import a key from file
    /// - Parameter fileURL: URL of the key file
    /// - Returns: Import results
    func importKey(from fileURL: URL) async throws -> KeyImportResult {
        try await ensureGPGAgentRunningIfNeeded()

        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase", "",
                "--import",
                "--status-fd", "1",
                fileURL.path
            ]
        )
        try ensureSuccess(result, as: GPGError.importFailed)
        
        guard let output = result.stdout else {
            throw GPGError.importFailed("No output from import")
        }
        
        return parseImportResult(output)
    }

    /// Import key material from keyserver using a URL, key ID, fingerprint, or email query.
    /// - Parameters:
    ///   - query: Key URL, fingerprint, key ID, or email
    ///   - keyserver: Keyserver URL
    /// - Returns: Import summary
    func importFromKeyserver(query: String, keyserver: String = "keys.openpgp.org") async throws -> KeyImportResult {
        let queryKind = try parseKeyserverImportQuery(query)
        let beforeFingerprints = Set(try await listKeys(secretOnly: false).map(\.fingerprint))
        let resolvedKeyserver = normalizedGPGKeyserver(keyserver)

        let arguments: [String]
        switch queryKind {
        case .keyReference(let value):
            arguments = [
                "--batch",
                "--yes",
                "--keyserver", resolvedKeyserver,
                "--status-fd", "1",
                "--recv-keys",
                value
            ]
        case .email(let value):
            arguments = [
                "--batch",
                "--yes",
                "--status-fd", "1",
                "--keyserver", resolvedKeyserver,
                "--auto-key-locate", "keyserver",
                "--locate-keys",
                value
            ]
        }

        let result = try await executeGPG(arguments: arguments, timeout: 60.0)

        if result.exitCode != 0 {
            let combinedError = "\(result.stderr ?? "")\n\(result.stdout ?? "")".lowercased()
            if combinedError.contains("not found") || combinedError.contains("no data") || combinedError.contains("not changed") {
                throw GPGError.keyNotFound(query)
            }
            throw GPGError.importFailed(result.stderr ?? "Failed to import key from keyserver")
        }

        let afterKeys = try await listKeys(secretOnly: false)
        let newKeys = afterKeys
            .filter { !beforeFingerprints.contains($0.fingerprint) }
            .map(\.fingerprint)

        if !newKeys.isEmpty {
            return KeyImportResult(
                imported: newKeys.count,
                unchanged: 0,
                newKeyIDs: newKeys
            )
        }

        if let output = result.stdout {
            let parsed = parseImportResult(output)
            if parsed.imported > 0 || parsed.unchanged > 0 || !parsed.newKeyIDs.isEmpty {
                return parsed
            }
        }

        return KeyImportResult(imported: 0, unchanged: 1, newKeyIDs: [])
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
        try ensureSuccess(result, as: GPGError.exportFailed)

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
        try await ensureGPGAgentRunningIfNeeded()

        var arguments = [
            "--batch",
            "--yes",
            "--pinentry-mode", "loopback",
            "--passphrase-fd", "0",
            "--export-secret-key",
            keyID
        ]
        if armor {
            arguments.insert("--armor", at: 0)
        }

        let result = try await executeGPG(
            arguments: arguments,
            input: passphrase + "\n"
        )
        try ensureSuccess(result, as: GPGError.exportFailed)

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
        
        let result = try await executeGPG(arguments: arguments)
        try ensureSuccess(result, as: GPGError.executionFailed)
    }

    /// Update key expiration
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - expiresAt: New expiration date. Pass nil for no expiration.
    ///   - passphrase: Optional key passphrase for loopback mode
    func updateKeyExpiration(keyID: String, expiresAt: Date?, passphrase: String? = nil) async throws {
        try await ensureGPGAgentRunningIfNeeded()

        let expiration = formatExpirationDate(expiresAt)
        let arguments = [
            "--batch",
            "--yes",
            "--no-tty",
            "--pinentry-mode", "loopback",
            "--passphrase-fd", "0",
            "--quick-set-expire",
            keyID,
            expiration
        ]
        let input = (passphrase ?? "") + "\n"

        let result = try await executeGPG(arguments: arguments, input: input)
        if result.exitCode != 0 {
            if isBadPassphrase(result) {
                throw GPGError.invalidPassphrase
            }
            throw GPGError.executionFailed(result.stderr ?? "Exit code \(result.exitCode)")
        }
    }

    /// Add a new user ID to an existing key
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - name: New user name
    ///   - email: New user email
    ///   - passphrase: Optional key passphrase for loopback mode
    func addUserID(keyID: String, name: String, email: String, passphrase: String? = nil) async throws {
        try await ensureGPGAgentRunningIfNeeded()

        let sanitizedName = name
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedEmail = email
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let userID = "\(sanitizedName) <\(sanitizedEmail)>"

        let arguments = [
            "--batch",
            "--yes",
            "--no-tty",
            "--pinentry-mode", "loopback",
            "--passphrase-fd", "0",
            "--quick-add-uid",
            keyID,
            userID
        ]
        let input = (passphrase ?? "") + "\n"

        let result = try await executeGPG(arguments: arguments, input: input)
        if result.exitCode != 0 {
            if isBadPassphrase(result) {
                throw GPGError.invalidPassphrase
            }
            throw GPGError.executionFailed(result.stderr ?? "Exit code \(result.exitCode)")
        }
    }

    /// Change key passphrase
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - oldPassphrase: Current passphrase
    ///   - newPassphrase: New passphrase
    func changePassphrase(keyID: String, oldPassphrase: String, newPassphrase: String) async throws {
        try await ensureGPGAgentRunningIfNeeded()

        let input = "\(oldPassphrase)\n\(newPassphrase)\n\(newPassphrase)\n"
        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--command-fd", "0",
                "--status-fd", "1",
                "--change-passphrase",
                keyID
            ],
            input: input
        )

        if result.exitCode != 0 {
            if isBadPassphrase(result) {
                throw GPGError.invalidPassphrase
            }
            throw GPGError.executionFailed(result.stderr ?? "Exit code \(result.exitCode)")
        }
    }
    
    // MARK: - Keyserver Operations
    
    /// Upload a public key to a keyserver
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint to ///   - keyserver: Keyserver URL (default: keys.openpgp.org)
    /// - Throws: GPGError if upload fails
    func uploadToKeyserver(keyID: String, keyserver: String = "keys.openpgp.org") async throws {
        let normalizedKeyID = normalizeKeyReference(keyID) ??
            keyID.replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedKeyserver = normalizedGPGKeyserver(keyserver)
        let arguments = [
            "--send-keys",
            "--keyserver", resolvedKeyserver,
            "--batch",
            "--yes",
            normalizedKeyID
        ]
        
        let result = try await executeGPG(
            arguments: arguments,
            timeout: 60.0  // 60 second timeout for network operations
        )

        if result.exitCode == 0 {
            return
        }

        let gpgErrorMessage = result.stderr ?? result.stdout ?? "Upload failed with exit code \(result.exitCode)"

        // Fallback path for bundled builds where keyserver helpers (like dirmngr) are unavailable.
        do {
            let armoredKeyData = try await exportPublicKey(keyID: normalizedKeyID, armor: true)
            guard let armoredKey = String(data: armoredKeyData, encoding: .utf8), !armoredKey.isEmpty else {
                throw GPGError.exportFailed("No key data exported")
            }

            try await uploadPublicKeyDirectly(armoredKey: armoredKey, keyserver: keyserver)
            return
        } catch {
            let fallbackMessage = error.localizedDescription
            throw GPGError.keyserverUploadFailed("\(gpgErrorMessage)\n\(fallbackMessage)")
        }
    }
    
    /// Search for a key on a keyserver
    /// - Parameters:
    ///   - keyID: Key ID or email to search for
    ///   - keyserver: Keyserver URL (default: keys.openpgp.org)
    /// - Returns: True if key was found
    func searchKeyserver(keyID: String, keyserver: String = "keys.openpgp.org") async throws -> Bool {
        let resolvedKeyserver = normalizedGPGKeyserver(keyserver)
        let arguments = [
            "--search-keys",
            "--keyserver", resolvedKeyserver,
            keyID
        ]
        
        let result = try await executeGPG(
            arguments: arguments,
            timeout: 30.0
        )
        
        // GPG returns exit code 0 if found, 1 if not found
        // But we we2 can also mean "not found" which which is fine for our use case
        return result.exitCode == 0
    }
    
    // MARK: - Encryption & Decryption
    
    // MARK: - Encryption & Decryption
    
    /// Encrypt text
    /// - Parameters:
    ///   - text: Text to encrypt
    ///   - recipients: Array of key IDs to encrypt for
    ///   - sign: If true, also sign the message
    ///   - signingKey: Key ID to sign with (required if sign is true)
    /// - Returns: Encrypted text
    func encrypt(text: String, recipients: [String], sign: Bool = false, signingKey: String? = nil) async throws -> String {
        var arguments = [
            "--encrypt",
            "--armor",
            "--batch",
            "--trust-model", "always",
            "--cipher-algo", Constants.GPG.defaultCipherAlgorithm
        ]
        
        // Add recipients
        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }
        
        // Add signing if requested
        if sign, let signingKey = signingKey {
            arguments.append(contentsOf: ["--sign", "--local-user", signingKey])
        }
        
        let result = try await executeGPG(arguments: arguments, input: text)
        
        // Check for GPG errors first
        if result.exitCode != 0 {
            let errorMsg = result.stderr ?? "Unknown GPG error (exit code: \(result.exitCode))"
            throw GPGError.encryptionFailed(errorMsg)
        }
        
        guard let output = result.stdout, !output.isEmpty else {
            // Include stderr in error message for debugging
            let errorMsg = result.stderr ?? "No output generated"
            throw GPGError.encryptionFailed(errorMsg)
        }
        
        return output
    }
    
    /// Decrypt text
    /// - Parameters:
    ///   - text: Text to decrypt
    ///   - passphrase: Passphrase for the private key
    /// - Returns: Decrypted text
    func decrypt(text: String, passphrase: String) async throws -> String {
        try await ensureGPGAgentRunningIfNeeded()

        let result = try await executeGPG(
            arguments: ["--decrypt", "--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0"],
            input: passphrase + "\n" + text
        )
        
        // Check for GPG errors first
        if result.exitCode != 0 {
            let errorMsg = result.stderr ?? "Unknown GPG error (exit code: \(result.exitCode))"
            throw GPGError.decryptionFailed(errorMsg)
        }
        
        guard let output = result.stdout, !output.isEmpty else {
            let errorMsg = result.stderr ?? "No output generated"
            throw GPGError.decryptionFailed(errorMsg)
        }
        
        return output
    }
    
    /// Encrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - recipients: Array of key IDs to encrypt for
    ///   - armor: If true, output ASCII armor format
    func encryptFile(sourceURL: URL, destinationURL: URL, recipients: [String], armor: Bool = false) async throws -> URL {
        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "file-op")
        let stagedSourceURL = stagingDirectory.appendingPathComponent("input")
        let stagedOutputURL = stagingDirectory.appendingPathComponent("output")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        try fileManager.copyItem(at: sourceURL, to: stagedSourceURL)

        var arguments = [
            "--encrypt",
            "--batch",
            "--yes",
            "--trust-model", "always",
            "--cipher-algo", Constants.GPG.defaultCipherAlgorithm
        ]
        
        // Add recipients
        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }
        
        // Add armor flag
        if armor {
            arguments.append("--armor")
        }
        
        // Add input/output
        arguments.append(contentsOf: ["--output", stagedOutputURL.path, stagedSourceURL.path])
        
        let result = try await executeGPG(arguments: arguments)
        try ensureSuccess(result, as: GPGError.encryptionFailed)

        guard fileManager.fileExists(atPath: stagedOutputURL.path) else {
            throw GPGError.encryptionFailed("No output generated")
        }

        let resolvedDestinationURL = makeNonConflictingDestinationURL(for: destinationURL)
        try fileManager.copyItem(at: stagedOutputURL, to: resolvedDestinationURL)
        return resolvedDestinationURL
    }
    
    /// Decrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - passphrase: Passphrase for the private key
    func decryptFile(sourceURL: URL, destinationURL: URL, passphrase: String) async throws -> URL {
        try await ensureGPGAgentRunningIfNeeded()

        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "file-op")
        let stagedSourceURL = stagingDirectory.appendingPathComponent("input")
        let stagedOutputURL = stagingDirectory.appendingPathComponent("output")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        try fileManager.copyItem(at: sourceURL, to: stagedSourceURL)

        let result = try await executeGPG(
            arguments: [
                "--decrypt",
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--output", stagedOutputURL.path,
                stagedSourceURL.path
            ],
            input: passphrase + "\n"
        )

        if result.exitCode != 0 {
            throw GPGError.decryptionFailed(result.stderr ?? "Unknown error")
        }

        guard fileManager.fileExists(atPath: stagedOutputURL.path) else {
            throw GPGError.decryptionFailed("No output generated")
        }

        let resolvedDestinationURL = makeNonConflictingDestinationURL(for: destinationURL)
        try fileManager.copyItem(at: stagedOutputURL, to: resolvedDestinationURL)
        return resolvedDestinationURL
    }

    /// Create a detached signature for a file.
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination signature URL
    ///   - keyID: Signing key fingerprint or key ID
    ///   - passphrase: Passphrase for the signing key
    /// - Returns: Final signature URL
    func signFileDetached(
        sourceURL: URL,
        destinationURL: URL,
        keyID: String,
        passphrase: String
    ) async throws -> URL {
        try await ensureGPGAgentRunningIfNeeded()

        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "file-sign")
        let stagedSourceURL = stagingDirectory.appendingPathComponent("input")
        let stagedOutputURL = stagingDirectory.appendingPathComponent("output.sig")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        try fileManager.copyItem(at: sourceURL, to: stagedSourceURL)

        let result = try await executeGPG(
            arguments: [
                "--detach-sign",
                "--batch",
                "--yes",
                "--no-tty",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--local-user", keyID,
                "--output", stagedOutputURL.path,
                stagedSourceURL.path
            ],
            input: passphrase + "\n"
        )

        if result.exitCode != 0 {
            throw GPGError.executionFailed(result.stderr ?? "Detached signing failed")
        }

        guard fileManager.fileExists(atPath: stagedOutputURL.path) else {
            throw GPGError.executionFailed("No detached signature generated")
        }

        let resolvedDestinationURL = makeNonConflictingDestinationURL(for: destinationURL)
        try fileManager.copyItem(at: stagedOutputURL, to: resolvedDestinationURL)
        return resolvedDestinationURL
    }

    /// Verify if a file is a valid GPG file
    /// Uses --list-packets for fast validation without processing
    /// - Parameter fileURL: File URL to verify
    /// - Returns: True if file is a valid GPG file
    func verifyGPGFile(at fileURL: URL) async -> Bool {
        let fileManager = FileManager.default
        let stagedInputURL: URL
        let stagingDirectory: URL

        do {
            stagingDirectory = try secureOperationDirectory(prefix: "verify")
            stagedInputURL = stagingDirectory.appendingPathComponent("input")
        } catch {
            logger.debug("verifyGPGFile cannot create secure temp dir: \(error.localizedDescription, privacy: .public)")
            return false
        }

        let accessGranted = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                fileURL.stopAccessingSecurityScopedResource()
            }
            try? fileManager.removeItem(at: stagingDirectory)
        }

        do {
            try fileManager.copyItem(at: fileURL, to: stagedInputURL)

            let result = try await executeGPG(
                arguments: ["--list-packets", "--dry-run", stagedInputURL.path]
            )
            return result.exitCode == 0
        } catch {
            logger.debug("verifyGPGFile failed for \(fileURL.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return false
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
        try await ensureGPGAgentRunningIfNeeded()

        var arguments = ["--batch", "--pinentry-mode", "loopback", "--passphrase-fd", "0", "--local-user", keyID]
        
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

    /// Verify a signed file or detached signature.
    /// For detached signatures, this method auto-resolves the counterpart file:
    /// - selecting `file` tries `file.sig` then `file.asc`
    /// - selecting `file.sig` / `file.asc` tries `file`
    /// - Parameter fileURL: Signed file URL or detached signature URL
    /// - Returns: Verification result
    func verifySignatureFile(at fileURL: URL) async throws -> VerificationResult {
        let fileManager = FileManager.default
        let fileExtension = fileURL.pathExtension.lowercased()

        // Case 1: user selected a detached signature file (*.sig / *.asc)
        if fileExtension == "sig" || fileExtension == "asc" {
            let signedFileURL = fileURL.deletingPathExtension()
            guard fileManager.fileExists(atPath: signedFileURL.path) else {
                throw GPGError.executionFailed(String(localized: "verify_signature_error_missing_original"))
            }
            return try await verifyDetachedSignatureFile(
                signatureURL: fileURL,
                signedFileURL: signedFileURL
            )
        }

        // Case 2: user selected the original file, and a sibling detached signature exists.
        for signatureExtension in ["sig", "asc"] {
            let siblingSignatureURL = fileURL.appendingPathExtension(signatureExtension)
            if fileManager.fileExists(atPath: siblingSignatureURL.path) {
                return try await verifyDetachedSignatureFile(
                    signatureURL: siblingSignatureURL,
                    signedFileURL: fileURL
                )
            }
        }

        // Case 3: inline/clearsigned content.
        return try await verifyInlineSignedFile(fileURL: fileURL)
    }

    private func verifyInlineSignedFile(fileURL: URL) async throws -> VerificationResult {
        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "verify-inline")
        let stagedInputURL = stagingDirectory.appendingPathComponent("input")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        let accessGranted = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.copyItem(at: fileURL, to: stagedInputURL)

        let result = try await executeGPG(
            arguments: ["--verify", "--status-fd", "1", stagedInputURL.path]
        )

        let statusOutput = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
        let verificationResult = parseVerificationResult(statusOutput)

        guard result.exitCode == 0, verificationResult.isValid else {
            let stderr = result.stderr?.trimmingCharacters(in: .whitespacesAndNewlines)
            let failureMessage = friendlyVerificationFailureMessage(
                statusOutput: statusOutput,
                stderr: stderr
            )
            throw GPGError.executionFailed(failureMessage)
        }

        return verificationResult
    }

    private func verifyDetachedSignatureFile(
        signatureURL: URL,
        signedFileURL: URL
    ) async throws -> VerificationResult {
        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "verify-detached")
        let stagedSignatureURL = stagingDirectory.appendingPathComponent("signature.sig")
        let stagedSignedFileURL = stagingDirectory.appendingPathComponent("signed")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        let signatureAccessGranted = signatureURL.startAccessingSecurityScopedResource()
        let signedFileAccessGranted = signedFileURL.startAccessingSecurityScopedResource()
        defer {
            if signatureAccessGranted {
                signatureURL.stopAccessingSecurityScopedResource()
            }
            if signedFileAccessGranted {
                signedFileURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.copyItem(at: signatureURL, to: stagedSignatureURL)
        try fileManager.copyItem(at: signedFileURL, to: stagedSignedFileURL)

        let result = try await executeGPG(
            arguments: [
                "--verify",
                "--status-fd", "1",
                stagedSignatureURL.path,
                stagedSignedFileURL.path
            ]
        )

        let statusOutput = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
        let verificationResult = parseVerificationResult(statusOutput)

        guard result.exitCode == 0, verificationResult.isValid else {
            let stderr = result.stderr?.trimmingCharacters(in: .whitespacesAndNewlines)
            let failureMessage = friendlyVerificationFailureMessage(
                statusOutput: statusOutput,
                stderr: stderr
            )
            throw GPGError.executionFailed(failureMessage)
        }

        return verificationResult
    }

    private func friendlyVerificationFailureMessage(statusOutput: String, stderr: String?) -> String {
        let combinedOutput = [statusOutput, stderr ?? ""]
            .joined(separator: "\n")
            .lowercased()

        if combinedOutput.contains("badsig")
            || combinedOutput.contains("errsig")
            || combinedOutput.contains("bad signature") {
            return String(localized: "verify_signature_error_bad_signature")
        }
        if combinedOutput.contains("we couldn't verify this signature")
            || combinedOutput.contains("please check the selected files and try again") {
            return String(localized: "verify_signature_error_bad_signature")
        }
        if combinedOutput.contains("no_pubkey") || combinedOutput.contains("no public key") {
            return String(localized: "verify_signature_error_missing_public_key")
        }
        if combinedOutput.contains("nodata")
            || combinedOutput.contains("no signature found")
            || combinedOutput.contains("no valid openpgp data found") {
            return String(localized: "verify_signature_error_no_signature")
        }
        if combinedOutput.contains("can't open signed data")
            || combinedOutput.contains("no such file or directory")
            || combinedOutput.contains("should be the first file") {
            return String(localized: "verify_signature_error_missing_original")
        }
        return String(localized: "verify_signature_error_bad_signature")
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
            // Missing stdout with success means no matching key records.
            if result.exitCode == 0 {
                return .unknown
            }
            let message = result.stderr ?? "No output from key list (exit code: \(result.exitCode))"
            throw GPGError.executionFailed(message)
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
        // Use non-interactive ownertrust update to avoid /dev/tty dependency.
        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--no-tty",
                "--quick-set-ownertrust",
                keyID,
                trustLevel.quickSetOwnerTrustValue
            ]
        )
        
        if result.exitCode != 0 {
            throw GPGError.trustUpdateFailed(result.stderr ?? "Unknown error")
        }

        let trustDBResult = try await executeGPG(
            arguments: ["--batch", "--yes", "--no-tty", "--update-trustdb"]
        )

        if trustDBResult.exitCode != 0 {
            throw GPGError.trustUpdateFailed(trustDBResult.stderr ?? "Failed to update trust database")
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
        try await ensureGPGAgentRunningIfNeeded()

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
            // Missing stdout with success means no matching key records.
            if result.exitCode == 0 {
                return KeyTrustDetails(
                    keyID: keyID,
                    ownerTrust: .unknown,
                    calculatedTrust: .unknown,
                    signatureCount: 0
                )
            }
            let message = result.stderr ?? "No output from key list (exit code: \(result.exitCode))"
            throw GPGError.executionFailed(message)
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
    
    /// Execute GPG command using the process executor actor
    private func executeGPG(
        arguments: [String],
        input: String? = nil,
        environment: [String: String] = [:],
        timeout: TimeInterval = Constants.GPG.defaultTimeout
    ) async throws -> GPGExecutionResult {
        guard let gpgURL = gpgURL else {
            throw GPGError.gpgNotFound
        }
        
        return try await processExecutor.execute(
            executableURL: gpgURL,
            arguments: arguments,
            environment: environment,
            gpgHome: gpgHome,
            input: input,
            timeout: timeout
        )
    }

    private func ensureSuccess(
        _ result: GPGExecutionResult,
        as errorBuilder: (String) -> GPGError
    ) throws {
        guard result.exitCode == 0 else {
            throw errorBuilder(result.stderr ?? "Exit code \(result.exitCode)")
        }
    }

    private func secureOperationDirectory(prefix: String) throws -> URL {
        SecureTempStorage.cleanupStaleDirectories()
        return try SecureTempStorage.makeOperationDirectory(prefix: prefix)
    }

    private func makeNonConflictingDestinationURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return url }

        let ext = url.pathExtension
        let baseName = ext.isEmpty
            ? url.lastPathComponent
            : String(url.lastPathComponent.dropLast(ext.count + 1))
        let directory = url.deletingLastPathComponent()

        var index = 1
        while true {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(baseName) (\(index))"
            } else {
                candidateName = "\(baseName) (\(index)).\(ext)"
            }
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            index += 1
        }
    }

    private func listKeys(at homeURL: URL, secretOnly: Bool) async throws -> [GPGKey] {
        let arguments = secretOnly
            ? ["--list-secret-keys", "--with-colons", "--fixed-list-mode"]
            : ["--list-keys", "--with-colons", "--fixed-list-mode"]

        let result = try await executeGPG(
            arguments: arguments,
            environment: ["GNUPGHOME": homeURL.path]
        )

        guard result.exitCode == 0 else {
            let message = result.stderr ?? "Failed to list keys from \(homeURL.path)"
            throw GPGError.executionFailed(message)
        }

        guard let output = result.stdout else {
            return []
        }

        return parseKeyList(output, secretOnly: secretOnly)
    }

    private func importArmorData(_ data: Data, fileName: String) async throws -> KeyImportResult {
        let tempRoot = try secureOperationDirectory(prefix: "migration")
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let armorFileURL = tempRoot.appendingPathComponent(fileName)
        try data.write(to: armorFileURL, options: .atomic)

        try await ensureGPGAgentRunningIfNeeded()

        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase", "",
                "--import",
                "--status-fd", "1",
                armorFileURL.path
            ]
        )
        try ensureSuccess(result, as: GPGError.importFailed)

        guard let output = result.stdout else {
            return KeyImportResult(imported: 0, unchanged: 0, newKeyIDs: [])
        }
        return parseImportResult(output)
    }

    private func formatExpirationDate(_ date: Date?) -> String {
        guard let date else { return "0" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func isBadPassphrase(_ result: GPGExecutionResult) -> Bool {
        let stderr = result.stderr ?? ""
        let stdout = result.stdout ?? ""
        let combined = "\(stderr)\n\(stdout)".lowercased()
        return combined.contains("bad passphrase")
            || combined.contains("bad_passphrase")
            || combined.contains("invalid passphrase")
            || combined.contains("wrong passphrase")
            || combined.contains("no passphrase given")
    }

    private enum KeyserverImportQueryKind {
        case keyReference(String)
        case email(String)
    }

    private func parseKeyserverImportQuery(_ query: String) throws -> KeyserverImportQueryKind {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GPGError.importFailed(String(localized: "import_keyserver_empty_query"))
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            if let keyFromURL = extractKeyReference(from: url) {
                return keyFromURL
            }
            throw GPGError.importFailed(String(localized: "import_keyserver_invalid_query"))
        }

        if trimmed.contains("@") {
            return .email(trimmed)
        }

        if let normalized = normalizeKeyReference(trimmed) {
            return .keyReference(normalized)
        }

        throw GPGError.importFailed(String(localized: "import_keyserver_invalid_query"))
    }

    private func extractKeyReference(from url: URL) -> KeyserverImportQueryKind? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let candidates = (components.queryItems ?? []).compactMap { item -> String? in
                let lowerName = item.name.lowercased()
                guard ["search", "fpr", "fingerprint", "keyid", "id", "key"].contains(lowerName) else {
                    return nil
                }
                return item.value
            }

            for candidate in candidates {
                if let normalized = normalizeKeyReference(candidate) {
                    return .keyReference(normalized)
                }
                if candidate.contains("@") {
                    return .email(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            if let fragment = components.fragment, let normalized = normalizeKeyReference(fragment) {
                return .keyReference(normalized)
            }
        }

        let lastPath = url.lastPathComponent
        if let normalized = normalizeKeyReference(lastPath) {
            return .keyReference(normalized)
        }

        if lastPath.contains("@") {
            return .email(lastPath)
        }

        return nil
    }

    private func normalizeKeyReference(_ value: String) -> String? {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if normalized.lowercased().hasPrefix("0x") {
            normalized.removeFirst(2)
        }
        normalized = normalized.replacingOccurrences(of: " ", with: "")

        let hexPattern = "^[A-Fa-f0-9]{8,40}$"
        if normalized.range(of: hexPattern, options: .regularExpression) != nil {
            return normalized.uppercased()
        }

        return nil
    }

    private func normalizedGPGKeyserver(_ keyserver: String) -> String {
        let trimmed = keyserver.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "hkps://keys.openpgp.org"
        }
        if trimmed.contains("://") {
            return trimmed
        }
        guard let host = normalizedKeyserverHost(trimmed) else {
            return trimmed
        }
        if host == "pgp.mit.edu" {
            return "hkp://\(host)"
        }
        return "hkps://\(host)"
    }

    private func normalizedKeyserverHost(_ keyserver: String) -> String? {
        let trimmed = keyserver.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let host = url.host {
            return host.lowercased()
        }

        let withoutScheme = trimmed.replacingOccurrences(
            of: #"^[a-zA-Z][a-zA-Z0-9+\-.]*://"#,
            with: "",
            options: .regularExpression
        )
        guard let hostPart = withoutScheme.split(separator: "/").first else {
            return nil
        }
        return hostPart.split(separator: ":").first.map { String($0).lowercased() }
    }

    private func uploadPublicKeyDirectly(armoredKey: String, keyserver: String) async throws {
        guard let host = normalizedKeyserverHost(keyserver) else {
            throw GPGError.keyserverUploadFailed("Invalid keyserver")
        }

        if host == "keys.openpgp.org" {
            try await uploadToOpenPGPServer(armoredKey: armoredKey)
            return
        }

        var lastError: String?
        for endpoint in hkpUploadEndpoints(forHost: host) {
            do {
                try await uploadToHKPEndpoint(armoredKey: armoredKey, endpoint: endpoint)
                return
            } catch {
                lastError = error.localizedDescription
            }
        }

        throw GPGError.keyserverUploadFailed(lastError ?? "Direct keyserver upload failed")
    }

    private func uploadToOpenPGPServer(armoredKey: String) async throws {
        guard let url = URL(string: "https://keys.openpgp.org/vks/v1/upload") else {
            throw GPGError.keyserverUploadFailed("Invalid OpenPGP server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/pgp-keys", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(armoredKey.utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GPGError.keyserverUploadFailed("OpenPGP server rejected upload (\(statusCode))")
        }
    }

    private func hkpUploadEndpoints(forHost host: String) -> [URL] {
        let candidates = [
            "https://\(host)/pks/add",
            "http://\(host)/pks/add",
            "http://\(host):11371/pks/add"
        ]
        return candidates.compactMap(URL.init(string:))
    }

    private func uploadToHKPEndpoint(armoredKey: String, endpoint: URL) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("keytext=\(formURLEncode(armoredKey))".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyPreview = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(160) ?? ""
            throw GPGError.keyserverUploadFailed("HKP upload failed (\(statusCode)): \(bodyPreview)")
        }
    }

    private func formURLEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._* ")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)?
            .replacingOccurrences(of: " ", with: "+") ?? value
    }
    
    /// Parse key list output
    private func parseKeyList(_ output: String, secretOnly: Bool) -> [GPGKey] {
        var keys: [GPGKey] = []
        var currentKey: GPGKeyBuilder?
        var isAwaitingPrimaryFingerprint = false
        
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
                currentKey?.isSecret = (recordType == "sec") || secretOnly
                isAwaitingPrimaryFingerprint = true
                if fields.count >= 10 {
                    currentKey?.keyID = fields[4]
                    currentKey?.createdAt = parseTimestamp(fields[5])
                    currentKey?.expiresAt = parseTimestamp(fields[6])
                    currentKey?.algorithm = fields[3]
                    currentKey?.keyLength = Int(fields[2]) ?? 0
                    // Fallback to key ID if no primary `fpr` record is present.
                    currentKey?.fingerprint = fields[4]
                    // Field 8 is ownertrust for pub records
                    if fields.count >= 9 {
                        currentKey?.trustLevel = TrustLevel(gpgCode: fields[8]) ?? .unknown
                    }
                }
                
            case "fpr":
                if isAwaitingPrimaryFingerprint, fields.count >= 10 {
                    currentKey?.fingerprint = fields[9]
                    isAwaitingPrimaryFingerprint = false
                }
            case "sub", "ssb":
                // Ignore subkey fingerprints for key-level operations (edit uid/expiry).
                isAwaitingPrimaryFingerprint = false
                
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

    /// Remove control/newline characters before embedding user input in GPG batch payloads.
    private func sanitizeBatchField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Build key generation parameters
    private func buildKeyGenerationParams(
        name: String,
        email: String,
        keyType: KeyType,
        passphrase: String?
    ) -> String {
        let sanitizedName = sanitizeBatchField(name)
        let sanitizedEmail = sanitizeBatchField(email)

        // GPG batch mode handles spaces in Name-Real correctly when passed via stdin
        // No need to escape the name
        var params: String

        switch keyType {
        case .rsa4096, .rsa2048:
            // RSA keys use Key-Length
            params = """
            %echo Generating key
            Key-Type: RSA
            Key-Length: \(keyType.keyLength)
            Key-Usage: sign,encrypt
            Subkey-Type: RSA
            Subkey-Length: \(keyType.subkeyLength)
            Subkey-Usage: encrypt
            Name-Real: \(sanitizedName)
            Name-Email: \(sanitizedEmail)
            Expire-Date: 0

            """

        case .ecc:
            // ECC uses Key-Curve, primary key only signs (encryption done by subkey)
            params = """
            %echo Generating key
            Key-Type: eddsa
            Key-Curve: ed25519
            Key-Usage: sign
            Subkey-Type: ecdh
            Subkey-Curve: cv25519
            Subkey-Usage: encrypt
            Name-Real: \(sanitizedName)
            Name-Email: \(sanitizedEmail)
            Expire-Date: 0

            """
        }

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
                if parts.count >= 7 {
                    // GnuPG status format:
                    // [GNUPG:] IMPORT_RES <count> <no_user_id> <imported> <imported_rsa> <unchanged> ...
                    imported = Int(parts[4]) ?? 0
                    unchanged = Int(parts[6]) ?? 0
                } else if parts.count >= 4 {
                    // Fallback for shortened/stubbed test-like output.
                    imported = Int(parts[2]) ?? 0
                    unchanged = Int(parts[3]) ?? 0
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

    /// Non-interactive ownertrust value for `gpg --quick-set-ownertrust`.
    var quickSetOwnerTrustValue: String {
        switch self {
        case .unknown: return "unknown"
        case .none: return "none"
        case .marginal: return "marginal"
        case .full: return "full"
        case .ultimate: return "ultimate"
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

struct KeyringSnapshot {
    let homePath: String
    let publicKeyCount: Int
    let secretKeyCount: Int

    var totalKeyCount: Int {
        publicKeyCount + secretKeyCount
    }
}

struct KeyMigrationResult {
    let imported: Int
    let unchanged: Int
    let sourcePublicKeyCount: Int
    let sourceSecretKeyCount: Int
    let secretKeysMigrated: Bool
}

/// Key import result
struct KeyImportResult: Codable {
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
