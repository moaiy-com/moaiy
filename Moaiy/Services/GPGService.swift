//
//  GPGService.swift
//  Moaiy
//
//  Core GPG service for encryption, decryption, and key management
//

import Foundation
import os.log
import Darwin

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

protocol SubkeyManaging {
    func listSubkeys(primaryKeyID: String) async throws -> [GPGSubkey]
    func addSubkey(
        primaryKeyID: String,
        usage: SubkeyUsage,
        expiresAt: Date?,
        passphrase: String?
    ) async throws
    func updateSubkeyExpiration(
        primaryKeyID: String,
        subkeyFingerprint: String,
        expiresAt: Date?,
        passphrase: String?
    ) async throws
}

// MARK: - GPG Process Actor

/// Actor for executing GPG commands off the main thread
actor GPGProcessExecutor {

    nonisolated private static func forceStopProcess(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()

        if process.isRunning {
            let pid = process.processIdentifier
            if pid > 0 {
                kill(pid, SIGKILL)
            }
        }
    }

    /// Execute a GPG command
    func execute(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        gpgHome: URL?,
        input: String?,
        timeout: TimeInterval = Constants.GPG.defaultTimeout,
        onLaunch: (@Sendable (Int32) -> Void)? = nil
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
        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        return try await withTaskCancellationHandler {
            // Execute with timeout
            try process.run()
            onLaunch?(process.processIdentifier)

            // Write input if provided
            if let input = input, let stdinPipe = stdinPipe {
                let inputData = input.data(using: .utf8) ?? Data()
                stdinPipe.fileHandleForWriting.write(inputData)
                try? stdinPipe.fileHandleForWriting.close()
            }

            // Wait for completion with timeout
            let deadline = Date().addingTimeInterval(timeout)
            do {
                while process.isRunning && Date() < deadline {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            } catch is CancellationError {
                Self.forceStopProcess(process)
                throw GPGError.operationCancelled
            }

            if process.isRunning {
                process.terminate()

                let terminateDeadline = Date().addingTimeInterval(1.0)
                while process.isRunning && Date() < terminateDeadline {
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                if process.isRunning {
                    Self.forceStopProcess(process)
                }

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
                let fallbackMessage = AppLocalization.string("error_operation_failed_generic")
                throw GPGError.executionFailed(timeoutMessage?.isEmpty == false ? timeoutMessage! : fallbackMessage)
            }

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
        } onCancel: {
            Self.forceStopProcess(process)
        }
    }
}

/// Service class for GPG operations
@MainActor
@Observable
final class GPGService: SubkeyManaging {
    
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

        let operationStartedAt = Date()
        let beforeFingerprints = Set(try await listKeys(secretOnly: false).map(\.fingerprint))

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
        // Try to identify new key by fingerprint delta and creation window.
        logger.warning("Could not find KEY_CREATED pattern, trying fallback key lookup")
        let keys = try await listKeys(secretOnly: false)
        let windowStart = operationStartedAt.addingTimeInterval(-120)
        let newlyAddedKeys = keys.filter { !beforeFingerprints.contains($0.fingerprint) }
        if let newKey = newestRecentlyCreatedKey(from: newlyAddedKeys, notBefore: windowStart) {
            logger.info("Found newly created key: \(newKey.fingerprint)")
            return newKey.fingerprint
        }
        if let emailFallback = newestEmailMatchedKey(from: keys, email: email, notBefore: windowStart) {
            logger.info("Found key by creation window fallback: \(emailFallback.fingerprint)")
            return emailFallback.fingerprint
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
                "--",
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
                "--",
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
            if let directImportResult = try await importPublicKeyDirectlyFromKeyserverIfNeeded(
                queryKind: queryKind,
                keyserver: resolvedKeyserver,
                beforeFingerprints: beforeFingerprints
            ) {
                return directImportResult
            }

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

    private func importPublicKeyDirectlyFromKeyserverIfNeeded(
        queryKind: KeyserverImportQueryKind,
        keyserver: String,
        beforeFingerprints: Set<String>
    ) async throws -> KeyImportResult? {
        guard let host = normalizedKeyserverHost(keyserver), host == "keys.openpgp.org" else {
            return nil
        }

        let armoredKey = try await fetchPublicKeyFromOpenPGPServer(queryKind: queryKind, host: host)
        guard let armoredData = armoredKey.data(using: .utf8), !armoredData.isEmpty else {
            throw GPGError.importFailed("Fetched key data is empty")
        }

        let imported = try await importArmorData(armoredData, fileName: "openpgp-keyserver-import.asc")
        if imported.imported > 0 || imported.unchanged > 0 || !imported.newKeyIDs.isEmpty {
            return imported
        }

        let afterFingerprints = Set(try await listKeys(secretOnly: false).map(\.fingerprint))
        let newKeys = afterFingerprints.subtracting(beforeFingerprints)
        if !newKeys.isEmpty {
            return KeyImportResult(
                imported: newKeys.count,
                unchanged: 0,
                newKeyIDs: Array(newKeys)
            )
        }

        return KeyImportResult(imported: 0, unchanged: 1, newKeyIDs: [])
    }

    private func fetchPublicKeyFromOpenPGPServer(
        queryKind: KeyserverImportQueryKind,
        host: String
    ) async throws -> String {
        var sawNotFound = false
        var networkErrorMessage: String?
        var serviceErrorMessage: String?

        for endpoint in openPGPPublicKeyFetchEndpoints(queryKind: queryKind, host: host) {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 30.0
            request.setValue("application/pgp-keys, text/plain;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    serviceErrorMessage = "Invalid keyserver response"
                    continue
                }

                switch httpResponse.statusCode {
                case 200:
                    guard let armoredKey = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                        !armoredKey.isEmpty else {
                        serviceErrorMessage = "Keyserver returned empty key data"
                        continue
                    }
                    return armoredKey

                case 404:
                    sawNotFound = true

                default:
                    let bodyPreview = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .prefix(200) ?? ""
                    serviceErrorMessage = "OpenPGP keyserver request failed (\(httpResponse.statusCode)): \(bodyPreview)"
                }
            } catch {
                if isNetworkUnavailable(error) {
                    networkErrorMessage = error.localizedDescription
                } else {
                    serviceErrorMessage = error.localizedDescription
                }
            }
        }

        if let networkErrorMessage {
            throw GPGError.importFailed(networkErrorMessage)
        }
        if let serviceErrorMessage {
            throw GPGError.importFailed(serviceErrorMessage)
        }
        if sawNotFound {
            throw GPGError.keyNotFound(keyserverImportQueryValue(queryKind))
        }
        throw GPGError.importFailed("Failed to fetch key from keys.openpgp.org")
    }

    private func openPGPPublicKeyFetchEndpoints(
        queryKind: KeyserverImportQueryKind,
        host: String
    ) -> [URL] {
        let base = "https://\(host)/vks/v1"

        switch queryKind {
        case .keyReference(let value):
            var candidates: [String] = []
            if value.count >= 40 {
                candidates.append("\(base)/by-fingerprint/\(value)")
            }
            candidates.append("\(base)/by-keyid/\(value)")
            if value.count > 16 {
                candidates.append("\(base)/by-keyid/\(String(value.suffix(16)))")
            }
            var uniqueURLs: [URL] = []
            var seen: Set<String> = []
            for candidate in candidates {
                guard let url = URL(string: candidate) else {
                    continue
                }
                if seen.insert(url.absoluteString).inserted {
                    uniqueURLs.append(url)
                }
            }
            return uniqueURLs

        case .email(let value):
            var allowed = CharacterSet.urlPathAllowed
            allowed.remove(charactersIn: "/")
            let encodedEmail = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return [URL(string: "\(base)/by-email/\(encodedEmail)")].compactMap { $0 }
        }
    }

    private func keyserverImportQueryValue(_ queryKind: KeyserverImportQueryKind) -> String {
        switch queryKind {
        case .keyReference(let value):
            return value
        case .email(let value):
            return value
        }
    }
    
    /// Export a public key
    /// - Parameters:
    ///   - keyID: Key ID or fingerprint
    ///   - armor: If true, export in ASCII armor format
    /// - Returns: Exported key data
    func exportPublicKey(keyID: String, armor: Bool = true) async throws -> Data {
        var arguments = ["--export", "--", keyID]
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
            "--",
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
        var arguments = ["--batch", "--yes", "--delete-keys", "--", keyID]
        if secret {
            arguments = ["--batch", "--yes", "--delete-secret-keys", "--", keyID]
        }

        let result = try await executeGPG(arguments: arguments)
        guard result.exitCode == 0 else {
            let output = [result.stderr, result.stdout]
                .compactMap { $0 }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if isMissingKeyDeletionOutput(output, deletingSecret: secret) {
                throw GPGError.keyNotFound(keyID)
            }
            throw GPGError.executionFailed(output.isEmpty ? "Exit code \(result.exitCode)" : output)
        }
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
            "--",
            keyID,
            expiration
        ]
        let input = (passphrase ?? "") + "\n"

        let result = try await executeGPG(arguments: arguments, input: input)
        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
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
            "--",
            keyID,
            userID
        ]
        let input = (passphrase ?? "") + "\n"

        let result = try await executeGPG(arguments: arguments, input: input)
        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
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

        let sanitizedOldPassphrase = sanitizeBatchPassphrase(oldPassphrase)
        let sanitizedNewPassphrase = sanitizeBatchPassphrase(newPassphrase)

        let unprotectedInput = "\(sanitizedNewPassphrase)\n\(sanitizedNewPassphrase)\n"

        if sanitizedOldPassphrase.isEmpty {
            let result = try await executeChangePassphrase(keyID: keyID, input: unprotectedInput)
            if result.exitCode == 0 {
                return
            }
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
            }
            throw GPGError.executionFailed(result.stderr ?? "Exit code \(result.exitCode)")
        }

        // For user-entered old passphrase, first probe unprotected flow.
        // This prevents accidental "old passphrase" text from being written as the new passphrase.
        let unprotectedResult = try await executeChangePassphrase(keyID: keyID, input: unprotectedInput)
        if unprotectedResult.exitCode == 0 {
            return
        }
        if credentialFailureError(from: unprotectedResult) == nil {
            throw GPGError.executionFailed(unprotectedResult.stderr ?? "Exit code \(unprotectedResult.exitCode)")
        }

        let protectedInput = "\(sanitizedOldPassphrase)\n\(sanitizedNewPassphrase)\n\(sanitizedNewPassphrase)\n"
        let protectedResult = try await executeChangePassphrase(keyID: keyID, input: protectedInput)
        if protectedResult.exitCode == 0 {
            return
        }
        if let credentialError = credentialFailureError(from: protectedResult) {
            throw credentialError
        }
        throw GPGError.executionFailed(protectedResult.stderr ?? "Exit code \(protectedResult.exitCode)")
    }

    // MARK: - Subkey Management

    func listSubkeys(primaryKeyID: String) async throws -> [GPGSubkey] {
        let normalizedPrimaryKeyID = normalizeKeyReference(primaryKeyID) ?? primaryKeyID
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try await executeGPG(
            arguments: [
                "--list-secret-keys",
                "--with-colons",
                "--with-fingerprint",
                "--fixed-list-mode",
                "--",
                normalizedPrimaryKeyID
            ]
        )

        guard result.exitCode == 0 else {
            throw GPGError.executionFailed(result.stderr ?? "Exit code \(result.exitCode)")
        }

        guard let output = result.stdout else {
            return []
        }

        return parseSubkeyList(output)
    }

    func addSubkey(
        primaryKeyID: String,
        usage: SubkeyUsage,
        expiresAt: Date?,
        passphrase: String?
    ) async throws {
        try await ensureGPGAgentRunningIfNeeded()

        let normalizedPrimaryKeyID = normalizeKeyReference(primaryKeyID) ?? primaryKeyID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrimaryKey = try await resolveSecretPrimaryKey(for: normalizedPrimaryKeyID)

        let algorithm = Self.subkeyAlgorithmToken(
            primaryAlgorithm: resolvedPrimaryKey?.algorithm ?? "",
            primaryKeyLength: resolvedPrimaryKey?.keyLength ?? 3072,
            usage: usage
        )
        let expiration = formatExpirationDate(expiresAt)
        let input = (passphrase ?? "") + "\n"

        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--no-tty",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--quick-add-key",
                "--",
                normalizedPrimaryKeyID,
                algorithm,
                usage.quickAddUsageArgument,
                expiration
            ],
            input: input
        )

        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
            }
            throw GPGError.executionFailed(result.stderr ?? "Exit code \(result.exitCode)")
        }
    }

    func updateSubkeyExpiration(
        primaryKeyID: String,
        subkeyFingerprint: String,
        expiresAt: Date?,
        passphrase: String?
    ) async throws {
        try await ensureGPGAgentRunningIfNeeded()

        let normalizedPrimaryKeyID = normalizeKeyReference(primaryKeyID) ?? primaryKeyID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSubkeyFingerprint = normalizeKeyReference(subkeyFingerprint) ?? subkeyFingerprint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let expiration = formatExpirationDate(expiresAt)
        let input = (passphrase ?? "") + "\n"

        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--no-tty",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--quick-set-expire",
                "--",
                normalizedPrimaryKeyID,
                expiration,
                normalizedSubkeyFingerprint
            ],
            input: input
        )

        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
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
            "--",
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
            "--",
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
    func encrypt(
        text: String,
        recipients: [String],
        sign: Bool = false,
        signingKey: String? = nil,
        allowUntrustedRecipients: Bool = false
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
    func encryptFile(
        sourceURL: URL,
        destinationURL: URL,
        recipients: [String],
        armor: Bool = false,
        allowUntrustedRecipients: Bool = false
    ) async throws -> URL {
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
            "--cipher-algo", Constants.GPG.defaultCipherAlgorithm
        ]

        if allowUntrustedRecipients {
            arguments.append(contentsOf: ["--trust-model", "always"])
        }

        // Add recipients
        for recipient in recipients {
            arguments.append(contentsOf: ["--recipient", recipient])
        }
        
        // Add armor flag
        if armor {
            arguments.append("--armor")
        }
        
        // Add input/output
        arguments.append(contentsOf: ["--output", stagedOutputURL.path, "--", stagedSourceURL.path])
        
        let result = try await executeGPG(arguments: arguments)
        try ensureSuccess(result, as: GPGError.encryptionFailed)

        guard fileManager.fileExists(atPath: stagedOutputURL.path) else {
            throw GPGError.encryptionFailed("No output generated")
        }

        return try writeStagedOutput(from: stagedOutputURL, to: destinationURL)
    }
    
    /// Decrypt a file
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    ///   - passphrase: Passphrase for the private key
    ///   - preferredSecretKey: Preferred secret key fingerprint/keyID for decryption context
    func decryptFile(
        sourceURL: URL,
        destinationURL: URL,
        passphrase: String,
        preferredSecretKey: String? = nil
    ) async throws -> URL {
        try await ensureGPGAgentRunningIfNeeded()

        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "file-op")
        let stagedSourceURL = stagingDirectory.appendingPathComponent("input")
        let stagedOutputURL = stagingDirectory.appendingPathComponent("output")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        try fileManager.copyItem(at: sourceURL, to: stagedSourceURL)

        var arguments = [
            "--decrypt",
            "--batch",
            "--yes",
            "--pinentry-mode", "loopback",
            "--passphrase-fd", "0",
            "--status-fd", "1"
        ]

        var normalizedPreferredSecretKey: String?
        if let preferredSecretKey,
           let normalized = normalizeKeyReference(preferredSecretKey) {
            normalizedPreferredSecretKey = normalized
            arguments.append(contentsOf: ["--try-secret-key", normalized])
        }

        arguments.append(contentsOf: ["--output", stagedOutputURL.path, "--", stagedSourceURL.path])

        let result = try await executeGPG(
            arguments: arguments,
            input: passphrase + "\n"
        )

        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
            }

            let combinedOutput = [result.stderr, result.stdout]
                .compactMap { $0 }
                .joined(separator: "\n")
            if containsNoSecretKeySignal(combinedOutput) {
                throw GPGError.keyNotFound(preferredSecretKey ?? "secret-key")
            }

            throw GPGError.decryptionFailed(result.stderr ?? result.stdout ?? "Unknown error")
        }

        let statusOutput = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
        guard statusOutput.contains("[GNUPG:] DECRYPTION_OKAY") else {
            if containsNoSecretKeySignal(statusOutput) {
                throw GPGError.keyNotFound(preferredSecretKey ?? "secret-key")
            }
            throw GPGError.decryptionFailed(result.stderr ?? "Decryption did not complete successfully")
        }

        if let normalizedPreferredSecretKey {
            try ensurePreferredDecryptionKey(
                normalizedPreferredSecretKey,
                statusOutput: statusOutput
            )
        }

        guard fileManager.fileExists(atPath: stagedOutputURL.path) else {
            throw GPGError.decryptionFailed("No output generated")
        }

        return try writeStagedOutput(from: stagedOutputURL, to: destinationURL)
    }

    /// Checks whether an encrypted file is addressed to the preferred secret key.
    /// - Parameters:
    ///   - sourceURL: Encrypted file URL
    ///   - preferredSecretKey: Preferred secret key fingerprint or key ID
    /// - Returns: Recipient metadata and whether preferred key is compatible
    func checkDecryptionRecipientMatch(
        sourceURL: URL,
        preferredSecretKey: String
    ) async throws -> DecryptionRecipientCheckResult {
        let recipientKeyIDs = try await listEncryptedRecipientKeyIDs(sourceURL: sourceURL)

        guard let normalizedPreferredKey = normalizeKeyReference(preferredSecretKey) else {
            return DecryptionRecipientCheckResult(
                matchesPreferredKey: true,
                recipientKeyIDs: recipientKeyIDs
            )
        }

        guard !recipientKeyIDs.isEmpty else {
            // Missing recipient metadata (e.g. hidden recipient mode): do not block.
            return DecryptionRecipientCheckResult(
                matchesPreferredKey: true,
                recipientKeyIDs: recipientKeyIDs
            )
        }

        let preferredKeyIDCandidates = try await listSecretKeyIDCandidates(keyReference: normalizedPreferredKey)
        let matchesPreferredKey: Bool
        if preferredKeyIDCandidates.isEmpty {
            let preferredTail16 = String(normalizedPreferredKey.suffix(16))
            matchesPreferredKey = recipientKeyIDs.contains(preferredTail16)
        } else {
            let recipientSet = Set(recipientKeyIDs)
            matchesPreferredKey = !preferredKeyIDCandidates.isDisjoint(with: recipientSet)
        }

        return DecryptionRecipientCheckResult(
            matchesPreferredKey: matchesPreferredKey,
            recipientKeyIDs: recipientKeyIDs
        )
    }

    /// Determines whether a secret key requires passphrase entry.
    /// Returns `true` when the key is passphrase-protected, `false` otherwise.
    /// Falls back to a conservative `true` when metadata cannot be resolved.
    func secretKeyRequiresPassphrase(keyID: String) async throws -> Bool {
        let normalizedKeyID = normalizeKeyReference(keyID) ?? keyID
        do {
            let keygrips = try await listSecretKeygrips(keyID: normalizedKeyID)
            if keygrips.isEmpty {
                return true
            }

            let keyInfoFlags = try await readAgentKeyInfoFlags()
            let anyResolved = keygrips.contains { keyInfoFlags[$0] != nil }
            let anyProtected = keygrips.contains { keyInfoFlags[$0]?.contains("P") == true }

            if anyResolved {
                return anyProtected
            }

            return try await probeSecretKeyPassphraseRequirement(keyID: normalizedKeyID)
        } catch {
            // Keep decrypt flow safe: if detection fails, we still require passphrase input.
            return true
        }
    }

    /// Checks whether a smart card (YubiKey/OpenPGP Card) is currently available.
    /// Uses scdaemon SERIALNO probing to avoid mutating card state.
    func checkSmartCardPresence() async throws -> SmartCardPresence {
        guard let gpgConnectAgentURL else {
            throw GPGError.smartCardUnavailable
        }

        let result = try await processExecutor.execute(
            executableURL: gpgConnectAgentURL,
            arguments: ["SCD SERIALNO", "/bye"],
            environment: [:],
            gpgHome: gpgHome,
            input: nil,
            timeout: 10
        )

        let output = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.exitCode == 0, let serial = parseSmartCardSerial(from: output) {
            return SmartCardPresence(serialNumber: serial)
        }

        if containsSmartCardNotPresentSignal(output) {
            throw GPGError.smartCardNotPresent
        }
        if containsSmartCardUnavailableSignal(output) {
            throw GPGError.smartCardUnavailable
        }

        throw GPGError.executionFailed(output.isEmpty ? "Failed to check smart card presence" : output)
    }

    /// Learns smart-card shadow key stubs and auto-completes public keys from card URL when available.
    func importSmartCardWithPublicKeyCompletion() async throws -> SmartCardLearnResult {
        let presence = try await checkSmartCardPresence()
        let beforeKeys = try await listKeys(secretOnly: true)

        guard let gpgConnectAgentURL else {
            throw GPGError.smartCardUnavailable
        }

        let learnResult = try await processExecutor.execute(
            executableURL: gpgConnectAgentURL,
            arguments: ["SCD LEARN --force", "/bye"],
            environment: [:],
            gpgHome: gpgHome,
            input: nil,
            timeout: 20
        )

        let learnOutput = [learnResult.stdout, learnResult.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if learnResult.exitCode != 0 {
            if containsSmartCardNotPresentSignal(learnOutput) {
                throw GPGError.smartCardNotPresent
            }
            if containsSmartCardUnavailableSignal(learnOutput) {
                throw GPGError.smartCardUnavailable
            }
            throw GPGError.executionFailed(learnOutput.isEmpty ? "Failed to learn smart card stubs" : learnOutput)
        }

        let learnMetadata = parseSmartCardLearnMetadata(from: learnOutput)
        let learnedFingerprints = Set(learnMetadata.learnedFingerprints)
        let beforePublicKeyFingerprints = try await listNormalizedPublicFingerprints()
        var urlFetchTried = false
        var urlFetchSucceeded = false
        var completionIssues: Set<SmartCardPublicKeyCompletionIssue> = []

        let publicKeyURL = try await resolveSmartCardPublicKeyURL(learnMetadata: learnMetadata)

        if let publicKeyURL {
            urlFetchTried = true
            do {
                try await fetchPublicKeys(from: publicKeyURL)
                urlFetchSucceeded = true
            } catch {
                completionIssues.insert(.urlFetchFailed)
            }
        } else {
            completionIssues.insert(.missingPublicKeyURL)
        }

        let afterKeys = try await listKeys(secretOnly: true)
        let beforeFingerprintPairs: [(String, GPGKey)] = beforeKeys.compactMap { key in
                guard let normalizedFingerprint = normalizeKeyReference(key.fingerprint) else {
                    return nil
                }
                return (normalizedFingerprint, key)
            }
        let beforeByFingerprint = Dictionary(uniqueKeysWithValues: beforeFingerprintPairs)
        let normalizedCardSerial = normalizeCardSerial(presence.serialNumber)

        let currentCardCandidates = uniqueKeysByNormalizedFingerprint(
            afterKeys.filter { key in
                let matchesCardSerial = normalizeCardSerial(key.cardSerialNumber) == normalizedCardSerial
                let matchesLearnedFingerprint: Bool
                if let normalizedFingerprint = normalizeKeyReference(key.fingerprint) {
                    matchesLearnedFingerprint = learnedFingerprints.contains(normalizedFingerprint)
                } else {
                    matchesLearnedFingerprint = false
                }
                return matchesCardSerial || matchesLearnedFingerprint
            }
        )

        let changedStubCandidates = currentCardCandidates.filter { afterKey in
            guard let normalizedFingerprint = normalizeKeyReference(afterKey.fingerprint),
                  let beforeKey = beforeByFingerprint[normalizedFingerprint] else {
                return true
            }
            if beforeKey.secretMaterial != afterKey.secretMaterial {
                return true
            }
            return normalizeCardSerial(beforeKey.cardSerialNumber) != normalizeCardSerial(afterKey.cardSerialNumber)
        }

        let changedStubs = changedStubCandidates
            .map { makeImportedStubDescriptor(from: $0, fallbackCardSerial: presence.serialNumber) }
            .sorted(by: sortImportedStubDescriptor)

        let currentCardStubs = currentCardCandidates
            .map { makeImportedStubDescriptor(from: $0, fallbackCardSerial: presence.serialNumber) }
            .sorted(by: sortImportedStubDescriptor)

        var displayedStubs = changedStubs
        var includesExistingStubs = false

        if displayedStubs.isEmpty, !currentCardStubs.isEmpty {
            displayedStubs = currentCardStubs
            includesExistingStubs = true
        }

        if displayedStubs.isEmpty, !learnedFingerprints.isEmpty {
            displayedStubs = learnedFingerprints
                .sorted()
                .map { makeFallbackStubDescriptor(from: $0, fallbackCardSerial: presence.serialNumber) }
        }

        let completionTargetFingerprints = completionTargetFingerprints(
            for: currentCardCandidates,
            fallback: learnedFingerprints
        )

        let publicKeyFingerprints = try await listNormalizedPublicFingerprints()
        let missingPublicKeyFingerprints = completionTargetFingerprints.subtracting(publicKeyFingerprints)
        let unresolvedUIDFingerprints: Set<String> = Set(
            currentCardCandidates.compactMap { key in
                let trimmedName = key.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = key.email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty || trimmedEmail.isEmpty else {
                    return nil
                }
                return normalizeKeyReference(key.fingerprint)
            }
        )
        let completionTargetWithUID = completionTargetFingerprints.union(unresolvedUIDFingerprints)
        let pendingPublicKeyFingerprints = missingPublicKeyFingerprints
            .union(unresolvedUIDFingerprints)
            .sorted()
        let pendingPublicKeyCount = pendingPublicKeyFingerprints.count
        let completedPublicKeyCount = max(completionTargetWithUID.count - pendingPublicKeyCount, 0)
        let completionLevel = Self.resolveSmartCardPublicKeyCompletionLevel(
            completedPublicKeyCount: completedPublicKeyCount,
            pendingPublicKeyCount: pendingPublicKeyCount
        )

        if completionLevel == .complete {
            completionIssues.removeAll()
        }

        return SmartCardLearnResult(
            cardSerialNumber: presence.serialNumber,
            learnedStubCount: changedStubs.count,
            importedStubs: displayedStubs,
            includesExistingStubs: includesExistingStubs,
            urlFetchTried: urlFetchTried,
            urlFetchSucceeded: urlFetchSucceeded,
            keyserverFetchTried: false,
            keyserverFetchSucceeded: false,
            publicKeyCompletionLevel: completionLevel,
            completedPublicKeyCount: completedPublicKeyCount,
            pendingPublicKeyCount: pendingPublicKeyCount,
            pendingPublicKeyFingerprints: pendingPublicKeyFingerprints,
            keyserverUsed: nil,
            completionIssues: completionIssues.sorted { $0.sortOrder < $1.sortOrder },
            publicKeyCountBeforeCompletion: beforePublicKeyFingerprints.count,
            publicKeyCountAfterCompletion: publicKeyFingerprints.count
        )
    }

    /// Backward-compatible wrapper for existing call sites.
    func learnSmartCardStubs() async throws -> SmartCardLearnResult {
        try await importSmartCardWithPublicKeyCompletion()
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
                "--",
                stagedSourceURL.path
            ],
            input: passphrase + "\n"
        )

        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
            }

            let combinedOutput = [result.stderr, result.stdout]
                .compactMap { $0 }
                .joined(separator: "\n")
            if containsNoSecretKeySignal(combinedOutput) {
                throw GPGError.keyNotFound(keyID)
            }

            throw GPGError.executionFailed(result.stderr ?? "Detached signing failed")
        }

        guard fileManager.fileExists(atPath: stagedOutputURL.path) else {
            throw GPGError.executionFailed("No detached signature generated")
        }

        return try writeStagedOutput(from: stagedOutputURL, to: destinationURL)
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
                arguments: ["--list-packets", "--dry-run", "--", stagedInputURL.path]
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
                throw GPGError.executionFailed(AppLocalization.string("verify_signature_error_missing_original"))
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
            arguments: ["--verify", "--status-fd", "1", "--", stagedInputURL.path]
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
                "--",
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
            return AppLocalization.string("verify_signature_error_bad_signature")
        }
        if combinedOutput.contains("we couldn't verify this signature")
            || combinedOutput.contains("please check the selected files and try again") {
            return AppLocalization.string("verify_signature_error_bad_signature")
        }
        if combinedOutput.contains("no_pubkey") || combinedOutput.contains("no public key") {
            return AppLocalization.string("verify_signature_error_missing_public_key")
        }
        if combinedOutput.contains("nodata")
            || combinedOutput.contains("no signature found")
            || combinedOutput.contains("no valid openpgp data found") {
            return AppLocalization.string("verify_signature_error_no_signature")
        }
        if combinedOutput.contains("can't open signed data")
            || combinedOutput.contains("no such file or directory")
            || combinedOutput.contains("should be the first file") {
            return AppLocalization.string("verify_signature_error_missing_original")
        }
        return AppLocalization.string("verify_signature_error_bad_signature")
    }
    
    // MARK: - Trust Management
    
    /// Check the trust level of a key
    /// - Parameter keyID: Key ID or fingerprint
    /// - Returns: Current trust level
    func checkTrust(keyID: String) async throws -> TrustLevel {
        let result = try await executeGPG(
            arguments: ["--list-keys", "--with-colons", "--fixed-list-mode", "--", keyID]
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
                "--",
                keyID,
                trustLevel.quickSetOwnerTrustValue
            ]
        )
        
        if result.exitCode != 0 {
            throw GPGError.trustUpdateFailed(result.stderr ?? "Unknown error")
        }

        let trustDBResult = try await executeGPG(
            arguments: GPGCommandBuilder.updateTrustDatabaseArguments()
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

    /// Export ownertrust records for backup or migration.
    func exportOwnerTrust() async throws -> Data {
        let result = try await executeGPG(arguments: GPGCommandBuilder.exportOwnerTrustArguments())
        guard result.exitCode == 0 else {
            throw GPGError.trustUpdateFailed(result.stderr ?? "Failed to export ownertrust")
        }

        if let data = result.data, !data.isEmpty {
            return data
        }
        if let stdout = result.stdout, let data = stdout.data(using: .utf8), !data.isEmpty {
            return data
        }

        throw GPGError.trustUpdateFailed("No ownertrust data exported")
    }

    /// Import ownertrust records and refresh trust database.
    func importOwnerTrust(from fileURL: URL) async throws {
        let result = try await executeGPG(
            arguments: GPGCommandBuilder.importOwnerTrustArguments(filePath: fileURL.path)
        )
        guard result.exitCode == 0 else {
            throw GPGError.trustUpdateFailed(result.stderr ?? "Failed to import ownertrust")
        }

        let trustDBResult = try await executeGPG(
            arguments: GPGCommandBuilder.updateTrustDatabaseArguments()
        )
        guard trustDBResult.exitCode == 0 else {
            throw GPGError.trustUpdateFailed(trustDBResult.stderr ?? "Failed to update trust database")
        }
    }

    /// Generate an ASCII-armored revocation certificate for a key.
    func generateRevocationCertificate(
        keyID: String,
        reason: RevocationReason,
        description: String,
        passphrase: String?
    ) async throws -> Data {
        try await ensureGPGAgentRunningIfNeeded()

        let stagingDirectory = try secureOperationDirectory(prefix: "revocation")
        defer {
            try? FileManager.default.removeItem(at: stagingDirectory)
        }

        let outputURL = stagingDirectory.appendingPathComponent("revocation.asc")
        let result = try await executeGPG(
            arguments: GPGCommandBuilder.generateRevocationArguments(
                keyID: keyID,
                outputPath: outputURL.path
            ),
            input: GPGCommandBuilder.revocationCommandInput(
                passphrase: passphrase ?? "",
                reason: reason,
                description: description
            ),
            timeout: 120
        )

        if result.exitCode != 0 {
            if let credentialError = credentialFailureError(from: result) {
                throw credentialError
            }
            throw GPGError.executionFailed(result.stderr ?? "Failed to generate revocation certificate")
        }

        let data = try Data(contentsOf: outputURL)
        guard !data.isEmpty else {
            throw GPGError.exportFailed("No revocation certificate generated")
        }
        return data
    }

    /// Import a revocation certificate and refresh trust database.
    func importRevocationCertificate(from fileURL: URL) async throws {
        let result = try await executeGPG(
            arguments: GPGCommandBuilder.importRevocationArguments(filePath: fileURL.path)
        )
        guard result.exitCode == 0 else {
            throw GPGError.importFailed(result.stderr ?? "Failed to import revocation certificate")
        }

        let trustDBResult = try await executeGPG(
            arguments: GPGCommandBuilder.updateTrustDatabaseArguments()
        )
        guard trustDBResult.exitCode == 0 else {
            throw GPGError.trustUpdateFailed(trustDBResult.stderr ?? "Failed to update trust database")
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
        
        arguments.append(contentsOf: ["--sign-key", "--", keyID])
        
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
            arguments: ["--list-keys", "--with-colons", "--fixed-list-mode", "--with-fingerprint", "--", keyID]
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

    private func executeChangePassphrase(keyID: String, input: String) async throws -> GPGExecutionResult {
        try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--command-fd", "0",
                "--status-fd", "1",
                "--change-passphrase",
                "--",
                keyID
            ],
            input: input
        )
    }

    private func secureOperationDirectory(prefix: String) throws -> URL {
        SecureTempStorage.cleanupStaleDirectories()
        return try SecureTempStorage.makeOperationDirectory(prefix: prefix)
    }

    /// Write staged output to the exact destination chosen by the user.
    /// For sandboxed save-panel flows, changing the destination path can invalidate
    /// the user-granted write scope, so we overwrite in place when needed.
    private func writeStagedOutput(from stagedURL: URL, to destinationURL: URL) throws -> URL {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: stagedURL, to: destinationURL)
        return destinationURL
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
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: armorFileURL.path)

        try await ensureGPGAgentRunningIfNeeded()

        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase", "",
                "--import",
                "--status-fd", "1",
                "--",
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

    private func resolveSecretPrimaryKey(for keyReference: String) async throws -> GPGKey? {
        let normalizedReference = normalizeKeyReference(keyReference)
        let secretKeys = try await listKeys(secretOnly: true)

        return secretKeys.first { key in
            guard let normalizedReference else {
                return keyReference.caseInsensitiveCompare(key.fingerprint) == .orderedSame
                    || keyReference.caseInsensitiveCompare(key.keyID) == .orderedSame
            }
            if let normalizedFingerprint = normalizeKeyReference(key.fingerprint),
               keyReferencesMatch(expected: normalizedReference, actual: normalizedFingerprint) {
                return true
            }
            if let normalizedKeyID = normalizeKeyReference(key.keyID),
               keyReferencesMatch(expected: normalizedReference, actual: normalizedKeyID) {
                return true
            }
            return false
        }
    }

    nonisolated static func subkeyAlgorithmToken(
        primaryAlgorithm: String,
        primaryKeyLength: Int,
        usage: SubkeyUsage
    ) -> String {
        let isECCPrimary = isECCAlgorithm(primaryAlgorithm)
        if isECCPrimary {
            switch usage {
            case .encrypt:
                return "cv25519"
            case .sign, .authenticate:
                return "ed25519"
            }
        }

        let resolvedLength = primaryKeyLength > 0 ? primaryKeyLength : 2048
        return "rsa\(resolvedLength)"
    }

    private nonisolated static func isECCAlgorithm(_ algorithm: String) -> Bool {
        let normalized = algorithm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        if let algorithmCode = Int(normalized) {
            return [18, 19, 22].contains(algorithmCode)
        }

        return normalized.contains("ed25519")
            || normalized.contains("cv25519")
            || normalized.contains("eddsa")
            || normalized.contains("ecdh")
            || normalized.contains("ecdsa")
    }

    private func credentialFailureError(from result: GPGExecutionResult) -> GPGError? {
        if isBadPIN(result) {
            return .smartCardPinInvalid
        }
        if isBadPassphrase(result) {
            return .invalidPassphrase
        }
        return nil
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

    private func isBadPIN(_ result: GPGExecutionResult) -> Bool {
        let stderr = result.stderr ?? ""
        let stdout = result.stdout ?? ""
        let combined = "\(stderr)\n\(stdout)".lowercased()
        return combined.contains("bad pin")
            || combined.contains("invalid pin")
            || combined.contains("wrong pin")
    }

    private func parseSmartCardSerial(from output: String) -> String? {
        for line in output.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("S SERIALNO ") {
                return String(trimmed.dropFirst("S SERIALNO ".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if trimmed.hasPrefix("SERIALNO ") {
                return String(trimmed.dropFirst("SERIALNO ".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func parseLearnedCardFingerprints(from output: String) -> [String] {
        var fingerprints: [String] = []

        for line in output.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("S KEY-FPR ") else { continue }

            let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let rawFingerprint = parts.last,
                  let normalizedFingerprint = normalizeKeyReference(rawFingerprint) else {
                continue
            }
            fingerprints.append(normalizedFingerprint)
        }

        return fingerprints
    }

    private func parseSmartCardLearnMetadata(from output: String) -> SmartCardLearnMetadata {
        let learnedFingerprints = parseLearnedCardFingerprints(from: output)
        let publicKeyURL = parseSmartCardPublicKeyURL(from: output)

        return SmartCardLearnMetadata(
            learnedFingerprints: learnedFingerprints,
            publicKeyURL: publicKeyURL
        )
    }

    private func resolveSmartCardPublicKeyURL(
        learnMetadata: SmartCardLearnMetadata
    ) async throws -> String? {
        if let learnedURL = learnMetadata.publicKeyURL {
            return learnedURL
        }

        do {
            if let urlFromGetAttr = try await readSmartCardPublicKeyURL() {
                return urlFromGetAttr
            }
            return try await readSmartCardPublicKeyURLFromCardStatus()
        } catch let error as GPGError {
            switch error {
            case .smartCardNotPresent, .smartCardUnavailable:
                throw error
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    private func readSmartCardPublicKeyURL() async throws -> String? {
        guard let gpgConnectAgentURL else {
            throw GPGError.smartCardUnavailable
        }

        let result = try await processExecutor.execute(
            executableURL: gpgConnectAgentURL,
            arguments: ["SCD GETATTR PUBKEY-URL", "/bye"],
            environment: [:],
            gpgHome: gpgHome,
            input: nil,
            timeout: 10
        )

        let output = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.exitCode != 0 {
            if containsSmartCardNotPresentSignal(output) {
                throw GPGError.smartCardNotPresent
            }
            if containsSmartCardUnavailableSignal(output) {
                throw GPGError.smartCardUnavailable
            }
            return nil
        }

        return parseSmartCardPublicKeyURL(from: output)
    }

    private func readSmartCardPublicKeyURLFromCardStatus() async throws -> String? {
        let result = try await executeGPG(
            arguments: ["--card-status"],
            environment: ["LC_ALL": "C"],
            timeout: 20
        )

        let output = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.exitCode != 0 {
            if containsSmartCardNotPresentSignal(output) {
                throw GPGError.smartCardNotPresent
            }
            if containsSmartCardUnavailableSignal(output) {
                throw GPGError.smartCardUnavailable
            }
            return nil
        }

        return parseSmartCardPublicKeyURL(from: output)
    }

    private func parseSmartCardPublicKeyURL(from output: String) -> String? {
        for line in output.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("S PUBKEY-URL") {
                let rawValue = String(trimmed.dropFirst("S PUBKEY-URL".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let normalizedURL = normalizedSmartCardPublicKeyURL(from: rawValue) {
                    return normalizedURL
                }
            }

            if trimmed.hasPrefix("S KEY-ATTR PUBKEY-URL") {
                let rawValue = String(trimmed.dropFirst("S KEY-ATTR PUBKEY-URL".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let normalizedURL = normalizedSmartCardPublicKeyURL(from: rawValue) {
                    return normalizedURL
                }
            }

            if trimmed.hasPrefix("D ") {
                let rawValue = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let normalizedURL = normalizedSmartCardPublicKeyURL(from: rawValue) {
                    return normalizedURL
                }
            }

            if trimmed.localizedCaseInsensitiveContains("URL of public key"),
               let separator = trimmed.firstIndex(of: ":") {
                let valueStart = trimmed.index(after: separator)
                let rawValue = String(trimmed[valueStart...])
                if let normalizedURL = normalizedSmartCardPublicKeyURL(from: rawValue) {
                    return normalizedURL
                }
            }
        }

        return nil
    }

    private func normalizedSmartCardPublicKeyURL(from rawValue: String) -> String? {
        let decodedValue = decodeAssuanPercentEscaped(rawValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        guard !decodedValue.isEmpty else {
            return nil
        }
        if isLikelySmartCardPublicKeyURL(decodedValue) {
            return decodedValue
        }
        return firstURLCandidate(in: decodedValue)
    }

    private func isLikelySmartCardPublicKeyURL(_ value: String) -> Bool {
        if value.contains("://") {
            return true
        }
        return value.range(
            of: #"^[A-Za-z][A-Za-z0-9+\.-]*:"#,
            options: .regularExpression
        ) != nil
    }

    private func firstURLCandidate(in value: String) -> String? {
        guard let range = value.range(
            of: #"[A-Za-z][A-Za-z0-9+\.-]*:[^\s]+"#,
            options: .regularExpression
        ) else {
            return nil
        }
        return String(value[range])
    }

    private func decodeAssuanPercentEscaped(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private func listNormalizedPublicFingerprints() async throws -> Set<String> {
        let publicKeys = try await listKeys(secretOnly: false)
        return Set(publicKeys.compactMap { normalizeKeyReference($0.fingerprint) })
    }

    private func fetchPublicKeys(from publicKeyURL: String) async throws {
        let trimmedPublicKeyURL = publicKeyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPublicKeyURL.isEmpty else {
            throw GPGError.importFailed("Empty smartcard public key URL")
        }

        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--yes",
                "--status-fd", "1",
                "--fetch-keys",
                "--",
                trimmedPublicKeyURL
            ],
            timeout: 60
        )

        guard result.exitCode == 0 else {
            let gpgMessage = [result.stderr, result.stdout]
                .compactMap { $0 }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                if try await importPublicKeyFromSmartCardURLViaKeyserver(trimmedPublicKeyURL) {
                    return
                }
            } catch {
                let fallbackMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = [gpgMessage, fallbackMessage]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                throw GPGError.importFailed(
                    combined.isEmpty ? "Failed to fetch keys from smartcard URL" : combined
                )
            }

            throw GPGError.importFailed(
                gpgMessage.isEmpty ? "Failed to fetch keys from smartcard URL" : gpgMessage
            )
        }
    }

    private func importPublicKeyFromSmartCardURLViaKeyserver(_ publicKeyURL: String) async throws -> Bool {
        guard let url = URL(string: publicKeyURL),
              let host = url.host,
              extractKeyReference(from: url) != nil else {
            return false
        }

        _ = try await importFromKeyserver(
            query: publicKeyURL,
            keyserver: host
        )
        return true
    }

    private func completionTargetFingerprints(
        for currentCardCandidates: [GPGKey],
        fallback learnedFingerprints: Set<String>
    ) -> Set<String> {
        let cardFingerprints = Set(currentCardCandidates.compactMap { normalizeKeyReference($0.fingerprint) })
        if !cardFingerprints.isEmpty {
            return cardFingerprints
        }
        return learnedFingerprints
    }

    private func isNetworkUnavailable(_ error: Error) -> Bool {
        let source: String
        if let gpgError = error as? GPGError {
            switch gpgError {
            case .executionFailed(let message),
                    .encryptionFailed(let message),
                    .decryptionFailed(let message),
                    .importFailed(let message),
                    .exportFailed(let message),
                    .keyGenerationFailed(let message),
                    .trustUpdateFailed(let message),
                    .keySigningFailed(let message),
                    .keyserverUploadFailed(let message):
                source = message
            case .keyNotFound,
                    .gpgNotFound,
                    .invalidOutput,
                    .invalidPassphrase,
                    .operationCancelled,
                    .fileAccessDenied,
                    .unsupportedKeyType,
                    .smartCardNotPresent,
                    .smartCardUnavailable,
                    .smartCardPinInvalid:
                source = error.localizedDescription
            }
        } else {
            source = error.localizedDescription
        }

        return containsNetworkUnavailableSignal(source)
    }

    private func containsNetworkUnavailableSignal(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        return lowercased.contains("network is unreachable")
            || lowercased.contains("no route to host")
            || lowercased.contains("connection timed out")
            || lowercased.contains("connection refused")
            || lowercased.contains("name or service not known")
            || lowercased.contains("temporary failure in name resolution")
            || lowercased.contains("could not resolve host")
            || lowercased.contains("no dirmngr")
            || lowercased.contains("keyserver receive failed")
    }

    private static func resolveSmartCardPublicKeyCompletionLevel(
        completedPublicKeyCount: Int,
        pendingPublicKeyCount: Int
    ) -> SmartCardPublicKeyCompletionLevel {
        if completedPublicKeyCount > 0 && pendingPublicKeyCount == 0 {
            return .complete
        }
        if completedPublicKeyCount > 0 {
            return .partial
        }
        return .stubOnly
    }

    private func normalizeCardSerial(_ serial: String?) -> String? {
        guard let serial else { return nil }
        let normalized = serial
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    private func makeImportedStubDescriptor(
        from key: GPGKey,
        fallbackCardSerial: String
    ) -> ImportedStubDescriptor {
        let trimmedName = key.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = key.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUIDResolved = !trimmedName.isEmpty && !trimmedEmail.isEmpty
        return ImportedStubDescriptor(
            fingerprint: key.fingerprint,
            keyID: key.keyID,
            name: trimmedName,
            email: trimmedEmail,
            cardSerialNumber: key.cardSerialNumber ?? fallbackCardSerial,
            isUIDResolved: isUIDResolved
        )
    }

    private func makeFallbackStubDescriptor(
        from normalizedFingerprint: String,
        fallbackCardSerial: String
    ) -> ImportedStubDescriptor {
        let keyID = String(normalizedFingerprint.suffix(16))
        return ImportedStubDescriptor(
            fingerprint: normalizedFingerprint,
            keyID: keyID,
            name: "",
            email: "",
            cardSerialNumber: fallbackCardSerial,
            isUIDResolved: false
        )
    }

    private func uniqueKeysByNormalizedFingerprint(_ keys: [GPGKey]) -> [GPGKey] {
        var seenFingerprints: Set<String> = []
        var uniqueKeys: [GPGKey] = []

        for key in keys {
            let normalizedFingerprint = normalizeKeyReference(key.fingerprint)
                ?? key.fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !seenFingerprints.contains(normalizedFingerprint) else {
                continue
            }
            seenFingerprints.insert(normalizedFingerprint)
            uniqueKeys.append(key)
        }

        return uniqueKeys
    }

    private func sortImportedStubDescriptor(_ lhs: ImportedStubDescriptor, _ rhs: ImportedStubDescriptor) -> Bool {
        let lhsName = lhs.name.isEmpty ? lhs.keyID : lhs.name
        let rhsName = rhs.name.isEmpty ? rhs.keyID : rhs.name
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
    }

    private func containsSmartCardNotPresentSignal(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        return lowercased.contains("card not present")
            || lowercased.contains("card removed")
            || lowercased.contains("no data <scd>")
    }

    private func containsSmartCardUnavailableSignal(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        return lowercased.contains("operation not supported by device")
            || lowercased.contains("openpgp card not available")
            || lowercased.contains("no smartcard daemon")
    }

    private func containsNoSecretKeySignal(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        return lowercased.contains("no_seckey")
            || lowercased.contains("no secret key")
            || lowercased.contains("secret key not available")
    }

    private func isMissingKeyDeletionOutput(_ output: String, deletingSecret: Bool) -> Bool {
        let lowercased = output.lowercased()
        if containsNoSecretKeySignal(output) {
            return true
        }
        if lowercased.contains("no public key")
            || lowercased.contains("public key not found")
            || lowercased.contains("no such key")
            || lowercased.contains("key not found")
            || lowercased.contains("not found") {
            return true
        }

        if deletingSecret {
            return lowercased.contains("not a secret key")
        }

        return false
    }

    private func ensurePreferredDecryptionKey(
        _ normalizedPreferredSecretKey: String,
        statusOutput: String
    ) throws {
        let decryptionPrimaryFingerprints = parseDecryptionPrimaryFingerprints(from: statusOutput)
        if !decryptionPrimaryFingerprints.isEmpty {
            let matched = decryptionPrimaryFingerprints.contains { parsedFingerprint in
                keyReferencesMatch(
                    expected: normalizedPreferredSecretKey,
                    actual: parsedFingerprint
                )
            }

            guard matched else {
                throw GPGError.keyNotFound(normalizedPreferredSecretKey)
            }
            return
        }

        let encryptedRecipientKeyIDs = parseEncryptedRecipientKeyIDs(from: statusOutput)
        guard encryptedRecipientKeyIDs.isEmpty == false else {
            return
        }

        let preferredTail16 = String(normalizedPreferredSecretKey.suffix(16))
        guard encryptedRecipientKeyIDs.contains(preferredTail16) else {
            throw GPGError.keyNotFound(normalizedPreferredSecretKey)
        }
    }

    private func listEncryptedRecipientKeyIDs(sourceURL: URL) async throws -> [String] {
        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "decrypt-recipient-check")
        let stagedSourceURL = stagingDirectory.appendingPathComponent("input")
        let stagedOutputURL = stagingDirectory.appendingPathComponent("output")
        let accessGranted = sourceURL.startAccessingSecurityScopedResource()

        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            try? fileManager.removeItem(at: stagingDirectory)
        }

        try fileManager.copyItem(at: sourceURL, to: stagedSourceURL)

        let result = try await executeGPG(
            arguments: [
                "--decrypt",
                "--batch",
                "--yes",
                "--no-tty",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--status-fd", "1",
                "--output", stagedOutputURL.path,
                "--",
                stagedSourceURL.path
            ],
            input: "\n",
            timeout: 30
        )

        let output = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")

        let recipientKeyIDsFromStatus = Array(parseEncryptedRecipientKeyIDs(from: output)).sorted()
        if !recipientKeyIDsFromStatus.isEmpty {
            return recipientKeyIDsFromStatus
        }

        let recipientKeyIDsFromOutput = parseRecipientKeyIDs(from: output)
        if !recipientKeyIDsFromOutput.isEmpty {
            return recipientKeyIDsFromOutput
        }

        return []
    }

    private func listSecretKeygrips(keyID: String) async throws -> Set<String> {
        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--with-colons",
                "--fixed-list-mode",
                "--with-keygrip",
                "--list-secret-keys",
                "--",
                keyID
            ]
        )

        guard result.exitCode == 0 else {
            if containsNoSecretKeySignal([result.stderr, result.stdout].compactMap { $0 }.joined(separator: "\n")) {
                throw GPGError.keyNotFound(keyID)
            }
            throw GPGError.executionFailed(result.stderr ?? "Failed to list secret key keygrips")
        }

        guard let output = result.stdout, !output.isEmpty else {
            return []
        }

        return Set(
            output
                .split(separator: "\n")
                .compactMap { line -> String? in
                    let fields = line.split(separator: ":", omittingEmptySubsequences: false)
                    guard fields.count > 9, fields[0] == "grp" else {
                        return nil
                    }
                    return normalizeKeygrip(String(fields[9]))
                }
        )
    }

    private func listSecretKeyIDCandidates(keyReference: String) async throws -> Set<String> {
        let result = try await executeGPG(
            arguments: [
                "--batch",
                "--with-colons",
                "--fixed-list-mode",
                "--list-secret-keys",
                "--",
                keyReference
            ]
        )

        guard result.exitCode == 0 else {
            return []
        }

        guard let output = result.stdout, !output.isEmpty else {
            return []
        }

        var candidates = Set<String>()
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard let recordType = fields.first else {
                continue
            }

            if (recordType == "sec" || recordType == "ssb"), fields.count > 4 {
                if let normalized = normalizeKeyReference(fields[4]) {
                    candidates.insert(String(normalized.suffix(16)))
                }
                continue
            }

            if recordType == "fpr", fields.count > 9 {
                if let normalized = normalizeKeyReference(fields[9]) {
                    candidates.insert(String(normalized.suffix(16)))
                }
            }
        }

        return candidates
    }

    private func readAgentKeyInfoFlags() async throws -> [String: Set<String>] {
        guard let gpgConnectAgentURL else {
            throw GPGError.executionFailed("gpg-connect-agent not available")
        }

        let result = try await processExecutor.execute(
            executableURL: gpgConnectAgentURL,
            arguments: ["keyinfo --list", "/bye"],
            environment: [:],
            gpgHome: gpgHome,
            input: nil,
            timeout: 10
        )

        guard result.exitCode == 0 else {
            throw GPGError.executionFailed(result.stderr ?? "Failed to query gpg-agent keyinfo")
        }

        let output = [result.stdout, result.stderr]
            .compactMap { $0 }
            .joined(separator: "\n")

        var flagsByKeygrip: [String: Set<String>] = [:]
        for line in output.split(separator: "\n") {
            let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 4, tokens[0] == "S", tokens[1] == "KEYINFO" else {
                continue
            }
            guard let keygrip = normalizeKeygrip(tokens[2]) else {
                continue
            }
            flagsByKeygrip[keygrip] = Set(tokens.dropFirst(3))
        }

        return flagsByKeygrip
    }

    private func probeSecretKeyPassphraseRequirement(keyID: String) async throws -> Bool {
        try await ensureGPGAgentRunningIfNeeded()

        let fileManager = FileManager.default
        let stagingDirectory = try secureOperationDirectory(prefix: "passphrase-probe")
        let sourceURL = stagingDirectory.appendingPathComponent("input.txt")
        let signatureURL = stagingDirectory.appendingPathComponent("probe.sig")
        defer {
            try? fileManager.removeItem(at: stagingDirectory)
        }

        try Data("moaiy-passphrase-probe".utf8).write(to: sourceURL, options: .atomic)

        let result = try await executeGPG(
            arguments: [
                "--detach-sign",
                "--batch",
                "--yes",
                "--pinentry-mode", "loopback",
                "--passphrase-fd", "0",
                "--local-user", keyID,
                "--output", signatureURL.path,
                "--",
                sourceURL.path
            ],
            input: "\n"
        )

        if result.exitCode == 0 {
            return false
        }

        if credentialFailureError(from: result) != nil {
            return true
        }

        let combinedOutput = [result.stderr, result.stdout]
            .compactMap { $0 }
            .joined(separator: "\n")
        if containsNoSecretKeySignal(combinedOutput) {
            throw GPGError.keyNotFound(keyID)
        }

        throw GPGError.executionFailed(result.stderr ?? result.stdout ?? "Failed to probe key passphrase requirement")
    }

    private func normalizeKeygrip(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.range(of: "^[A-F0-9]{40}$", options: .regularExpression) != nil else {
            return nil
        }
        return normalized
    }

    private func parseDecryptionPrimaryFingerprints(from statusOutput: String) -> [String] {
        parseGPGStatusFields(from: statusOutput).compactMap { fields in
            guard fields.count >= 3, fields[0] == "DECRYPTION_KEY" else {
                return nil
            }
            return normalizeKeyReference(fields[2])
        }
    }

    private func parseEncryptedRecipientKeyIDs(from statusOutput: String) -> Set<String> {
        Set(
            parseGPGStatusFields(from: statusOutput).compactMap { fields in
                guard fields.count >= 2, fields[0] == "ENC_TO" else {
                    return nil
                }
                guard let normalized = normalizeKeyReference(fields[1]) else {
                    return nil
                }
                return String(normalized.suffix(16))
            }
        )
    }

    private func parseRecipientKeyIDs(from output: String) -> [String] {
        var keyIDs: [String] = []
        var seen = Set<String>()

        for lineSubstring in output.split(separator: "\n") {
            let line = String(lineSubstring)
            let lowercased = line.lowercased().replacingOccurrences(of: "keyid", with: "id")
            guard let idRange = lowercased.range(of: "id ") else {
                continue
            }

            let suffix = line[idRange.upperBound...]
            for token in suffix.split(whereSeparator: { character in
                character.isWhitespace || character == "," || character == ":" || character == ")" || character == "("
            }) {
                guard let normalized = normalizeKeyReference(String(token)) else {
                    continue
                }
                let tail16 = String(normalized.suffix(16))
                if seen.insert(tail16).inserted {
                    keyIDs.append(tail16)
                }
            }
        }

        return keyIDs
    }

    private func parseGPGStatusFields(from output: String) -> [[String]] {
        output
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("[GNUPG:]") else {
                    return nil
                }
                let payload = trimmed.dropFirst("[GNUPG:]".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !payload.isEmpty else {
                    return nil
                }
                return payload.split(whereSeparator: \.isWhitespace).map(String.init)
            }
    }

    private func keyReferencesMatch(expected: String, actual: String) -> Bool {
        let normalizedExpected = expected.uppercased()
        let normalizedActual = actual.uppercased()

        if normalizedExpected == normalizedActual {
            return true
        }

        if normalizedExpected.count > normalizedActual.count {
            return normalizedExpected.hasSuffix(normalizedActual)
        }

        return normalizedActual.hasSuffix(normalizedExpected)
    }

    private enum KeyserverImportQueryKind {
        case keyReference(String)
        case email(String)
    }

    private func parseKeyserverImportQuery(_ query: String) throws -> KeyserverImportQueryKind {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GPGError.importFailed(AppLocalization.string("import_keyserver_empty_query"))
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            if let keyFromURL = extractKeyReference(from: url) {
                return keyFromURL
            }
            throw GPGError.importFailed(AppLocalization.string("import_keyserver_invalid_query"))
        }

        if trimmed.contains("@") {
            return .email(trimmed)
        }

        if let normalized = normalizeKeyReference(trimmed) {
            return .keyReference(normalized)
        }

        throw GPGError.importFailed(AppLocalization.string("import_keyserver_invalid_query"))
    }

    private func extractKeyReference(from url: URL) -> KeyserverImportQueryKind? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let candidates = (components.queryItems ?? []).compactMap { item -> String? in
                let lowerName = item.name.lowercased()
                guard ["search", "q", "fpr", "fingerprint", "keyid", "id", "key"].contains(lowerName) else {
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
                    // Field 1 contains key validity, which matches encryption trust checks.
                    if fields.count >= 2 {
                        currentKey?.trustLevel = TrustLevel(gpgCode: fields[1]) ?? .unknown
                    }
                }
                if (recordType == "sec") || secretOnly {
                    currentKey?.absorbSecretMaterialToken(fields.count > 14 ? fields[14] : nil)
                }
                
            case "fpr":
                if isAwaitingPrimaryFingerprint, fields.count >= 10 {
                    currentKey?.fingerprint = fields[9]
                    isAwaitingPrimaryFingerprint = false
                }
            case "sub", "ssb":
                // Ignore subkey fingerprints for key-level operations (edit uid/expiry).
                isAwaitingPrimaryFingerprint = false
                if recordType == "ssb" {
                    currentKey?.absorbSecretMaterialToken(fields.count > 14 ? fields[14] : nil)
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
                    // If primary validity is unknown, fall back to UID validity.
                    if fields.count >= 2, currentKey?.trustLevel == .unknown {
                        currentKey?.trustLevel = TrustLevel(gpgCode: fields[1]) ?? .unknown
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

    private func parseSubkeyList(_ output: String) -> [GPGSubkey] {
        var subkeys: [GPGSubkey] = []
        var currentSubkey: GPGSubkeyBuilder?
        var isAwaitingSubkeyFingerprint = false
        var isInsideSecretPrimary = false

        for line in output.components(separatedBy: "\n") {
            let fields = line.components(separatedBy: ":")
            guard let recordType = fields.first else { continue }

            switch recordType {
            case "sec":
                if let subkey = currentSubkey?.build() {
                    subkeys.append(subkey)
                }
                currentSubkey = nil
                isAwaitingSubkeyFingerprint = false
                isInsideSecretPrimary = true

            case "pub":
                if let subkey = currentSubkey?.build() {
                    subkeys.append(subkey)
                }
                currentSubkey = nil
                isAwaitingSubkeyFingerprint = false
                isInsideSecretPrimary = false

            case "ssb", "sub":
                if let subkey = currentSubkey?.build() {
                    subkeys.append(subkey)
                }

                guard isInsideSecretPrimary else {
                    currentSubkey = nil
                    isAwaitingSubkeyFingerprint = false
                    continue
                }

                var builder = GPGSubkeyBuilder()
                builder.keyID = fields.count > 4 ? fields[4] : ""
                builder.fingerprint = fields.count > 4 ? fields[4] : ""
                builder.algorithm = subkeyAlgorithmName(from: fields.count > 3 ? fields[3] : "")
                builder.keyLength = Int(fields.count > 2 ? fields[2] : "") ?? 0
                builder.createdAt = parseTimestamp(fields.count > 5 ? fields[5] : "")
                builder.expiresAt = parseTimestamp(fields.count > 6 ? fields[6] : "")
                builder.status = SubkeyStatus(gpgCode: fields.count > 1 ? fields[1] : "") ?? .unknown
                builder.usages = parseSubkeyUsages(from: fields)
                builder.isSecretMaterial = isSubkeySecretMaterial(recordType: recordType, fields: fields)

                currentSubkey = builder
                isAwaitingSubkeyFingerprint = true

            case "fpr":
                guard isAwaitingSubkeyFingerprint, fields.count >= 10 else { continue }
                currentSubkey?.fingerprint = fields[9]
                isAwaitingSubkeyFingerprint = false

            default:
                continue
            }
        }

        if let subkey = currentSubkey?.build() {
            subkeys.append(subkey)
        }

        return subkeys
    }

    private func parseSubkeyUsages(from fields: [String]) -> Set<SubkeyUsage> {
        let capabilityCandidates = [11, 12, 13]
        let capabilityString = capabilityCandidates
            .compactMap { index -> String? in
                guard fields.indices.contains(index) else { return nil }
                let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            .first ?? ""

        let normalized = capabilityString.lowercased()
        var usages: Set<SubkeyUsage> = []
        if normalized.contains("e") {
            usages.insert(.encrypt)
        }
        if normalized.contains("s") {
            usages.insert(.sign)
        }
        if normalized.contains("a") {
            usages.insert(.authenticate)
        }
        return usages
    }

    private func isSubkeySecretMaterial(recordType: String, fields: [String]) -> Bool {
        guard recordType == "ssb" else { return false }
        guard fields.indices.contains(14) else {
            return true
        }

        let token = fields[14].trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty || token == "+" {
            return true
        }
        if token == "#" {
            return false
        }
        // Serial-number token means smart-card resident material, not local secret material.
        return false
    }

    private func subkeyAlgorithmName(from code: String) -> String {
        switch code {
        case "1":
            return "RSA"
        case "17":
            return "DSA"
        case "18":
            return "ECDH"
        case "19":
            return "ECDSA"
        case "22":
            return "EdDSA"
        default:
            return code.isEmpty ? "Unknown" : code
        }
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

    /// Remove line breaks to avoid malformed `gpg --batch --gen-key` payloads.
    private func sanitizeBatchPassphrase(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
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
            let sanitizedPassphrase = sanitizeBatchPassphrase(passphrase)
            if sanitizedPassphrase.isEmpty {
                params += "%no-protection\n"
            } else {
                params += "Passphrase: \(sanitizedPassphrase)\n"
            }
        } else {
            params += "%no-protection\n"
        }

        params += "%commit\n%echo Key generation complete\n"

        return params
    }

    private func newestRecentlyCreatedKey(from keys: [GPGKey], notBefore date: Date) -> GPGKey? {
        keys
            .filter { ($0.createdAt ?? .distantPast) >= date }
            .sorted { lhs, rhs in
                (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
            }
            .first
    }

    private func newestEmailMatchedKey(from keys: [GPGKey], email: String, notBefore date: Date) -> GPGKey? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return keys
            .filter { key in
                key.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedEmail
                && (key.createdAt ?? .distantPast) >= date
            }
            .sorted { lhs, rhs in
                (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
            }
            .first
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

struct DecryptionRecipientCheckResult {
    let matchesPreferredKey: Bool
    let recipientKeyIDs: [String]
}

struct SmartCardPresence {
    let serialNumber: String
}

private struct SmartCardLearnMetadata {
    let learnedFingerprints: [String]
    let publicKeyURL: String?
}

enum SmartCardPublicKeyCompletionLevel: String, Codable {
    case complete
    case partial
    case stubOnly
}

enum SmartCardPublicKeyCompletionIssue: String, Codable, Hashable {
    case missingPublicKeyURL
    case urlFetchFailed
    case keyserverUnreachable
    case keyserverFetchFailed

    var sortOrder: Int {
        switch self {
        case .missingPublicKeyURL:
            return 0
        case .urlFetchFailed:
            return 1
        case .keyserverUnreachable:
            return 2
        case .keyserverFetchFailed:
            return 3
        }
    }
}

struct ImportedStubDescriptor: Equatable {
    let fingerprint: String
    let keyID: String
    let name: String
    let email: String
    let cardSerialNumber: String?
    let isUIDResolved: Bool
}

struct SmartCardLearnResult {
    let cardSerialNumber: String
    let learnedStubCount: Int
    let importedStubs: [ImportedStubDescriptor]
    let includesExistingStubs: Bool
    let urlFetchTried: Bool
    let urlFetchSucceeded: Bool
    let keyserverFetchTried: Bool
    let keyserverFetchSucceeded: Bool
    let publicKeyCompletionLevel: SmartCardPublicKeyCompletionLevel
    let completedPublicKeyCount: Int
    let pendingPublicKeyCount: Int
    let pendingPublicKeyFingerprints: [String]
    let keyserverUsed: String?
    let completionIssues: [SmartCardPublicKeyCompletionIssue]
    let publicKeyCountBeforeCompletion: Int
    let publicKeyCountAfterCompletion: Int
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
        case .none: return "never"
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
        case .unknown: return AppLocalization.string("trust_level_unknown")
        case .none: return AppLocalization.string("trust_level_none")
        case .marginal: return AppLocalization.string("trust_level_marginal")
        case .full: return AppLocalization.string("trust_level_full")
        case .ultimate: return AppLocalization.string("trust_level_ultimate")
    }
    }
    
    /// Localized description of trust level
    var localizedDescription: String {
        switch self {
        case .unknown: return AppLocalization.string("trust_desc_unknown")
        case .none: return AppLocalization.string("trust_desc_none")
        case .marginal: return AppLocalization.string("trust_desc_marginal")
        case .full: return AppLocalization.string("trust_desc_full")
        case .ultimate: return AppLocalization.string("trust_desc_ultimate")
        }
    }
}

enum RevocationReason: String, CaseIterable, Identifiable {
    case noLongerUsed
    case keyCompromised
    case keyReplaced
    case userIDInvalid

    var id: String { rawValue }

    /// GPG reason code for `--gen-revoke`.
    var gpgReasonCode: String {
        switch self {
        case .noLongerUsed:
            return "0"
        case .keyCompromised:
            return "1"
        case .keyReplaced:
            return "2"
        case .userIDInvalid:
            return "3"
        }
    }

    var localizedName: String {
        switch self {
        case .noLongerUsed:
            return AppLocalization.string("revocation_reason_no_longer_used")
        case .keyCompromised:
            return AppLocalization.string("revocation_reason_key_compromised")
        case .keyReplaced:
            return AppLocalization.string("revocation_reason_key_replaced")
        case .userIDInvalid:
            return AppLocalization.string("revocation_reason_user_id_invalid")
        }
    }
}

enum GPGCommandBuilder {
    static func exportOwnerTrustArguments() -> [String] {
        ["--export-ownertrust"]
    }

    static func importOwnerTrustArguments(filePath: String) -> [String] {
        ["--batch", "--yes", "--import-ownertrust", "--", filePath]
    }

    static func generateRevocationArguments(keyID: String, outputPath: String) -> [String] {
        [
            "--yes",
            "--no-tty",
            "--armor",
            "--pinentry-mode", "loopback",
            "--passphrase-fd", "0",
            "--command-fd", "0",
            "--status-fd", "1",
            "--output", outputPath,
            "--gen-revoke",
            "--",
            keyID
        ]
    }

    static func importRevocationArguments(filePath: String) -> [String] {
        ["--batch", "--yes", "--import", "--", filePath]
    }

    static func updateTrustDatabaseArguments() -> [String] {
        ["--batch", "--yes", "--no-tty", "--update-trustdb"]
    }

    static func revocationCommandInput(
        passphrase: String,
        reason: RevocationReason,
        description: String
    ) -> String {
        let sanitizedDescription = description
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return [
            passphrase,
            "y",
            reason.gpgReasonCode,
            sanitizedDescription,
            "",
            "y"
        ].joined(separator: "\n") + "\n"
    }
}

enum SecretKeyMaterial: String, Codable {
    case none
    case localSecret
    case smartCardStub

    static func defaultMaterial(for isSecret: Bool) -> SecretKeyMaterial {
        isSecret ? .localSecret : .none
    }
}

enum SubkeyUsage: String, CaseIterable, Identifiable, Sendable {
    case encrypt
    case sign
    case authenticate

    var id: String { rawValue }

    var quickAddUsageArgument: String {
        switch self {
        case .encrypt:
            return "encrypt"
        case .sign:
            return "sign"
        case .authenticate:
            return "auth"
        }
    }

    var localizedName: String {
        switch self {
        case .encrypt:
            return AppLocalization.string("subkey_usage_encrypt")
        case .sign:
            return AppLocalization.string("subkey_usage_sign")
        case .authenticate:
            return AppLocalization.string("subkey_usage_authenticate")
        }
    }
}

enum SubkeyExpirationPreset: String, CaseIterable, Identifiable {
    case never
    case oneYear
    case twoYears
    case fiveYears
    case custom

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .never:
            return "subkey_expiration_never"
        case .oneYear:
            return "subkey_expiration_one_year"
        case .twoYears:
            return "subkey_expiration_two_years"
        case .fiveYears:
            return "subkey_expiration_five_years"
        case .custom:
            return "subkey_expiration_custom_date"
        }
    }

    func resolveDate(customDate: Date) -> Date? {
        switch self {
        case .never:
            return nil
        case .oneYear:
            return Calendar.current.date(byAdding: .year, value: 1, to: Date())
        case .twoYears:
            return Calendar.current.date(byAdding: .year, value: 2, to: Date())
        case .fiveYears:
            return Calendar.current.date(byAdding: .year, value: 5, to: Date())
        case .custom:
            return customDate
        }
    }
}

enum SubkeyStatus: String, CaseIterable, Identifiable {
    case valid
    case revoked
    case expired
    case disabled
    case invalid
    case unknown

    var id: String { rawValue }

    init?(gpgCode: String) {
        switch gpgCode {
        case "r":
            self = .revoked
        case "e":
            self = .expired
        case "d":
            self = .disabled
        case "i":
            self = .invalid
        case "", "-", "q", "n":
            self = .unknown
        case "m", "f", "u", "o", "w", "s":
            self = .valid
        default:
            return nil
        }
    }

    var localizedName: String {
        switch self {
        case .valid:
            return AppLocalization.string("subkey_status_valid")
        case .revoked:
            return AppLocalization.string("subkey_status_revoked")
        case .expired:
            return AppLocalization.string("subkey_status_expired")
        case .disabled:
            return AppLocalization.string("subkey_status_disabled")
        case .invalid:
            return AppLocalization.string("subkey_status_invalid")
        case .unknown:
            return AppLocalization.string("subkey_status_unknown")
        }
    }
}

struct GPGSubkey: Identifiable, Hashable {
    let fingerprint: String
    let keyID: String
    let algorithm: String
    let keyLength: Int
    let usages: Set<SubkeyUsage>
    let createdAt: Date?
    let expiresAt: Date?
    let status: SubkeyStatus
    let isSecretMaterial: Bool

    var id: String { fingerprint }

    var isExpired: Bool {
        if status == .expired {
            return true
        }
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    var usageDisplayName: String {
        usages
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.localizedName)
            .joined(separator: " • ")
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
    let secretMaterial: SecretKeyMaterial
    let cardSerialNumber: String?

    init(
        id: String,
        keyID: String,
        fingerprint: String,
        name: String,
        email: String,
        algorithm: String,
        keyLength: Int,
        isSecret: Bool,
        createdAt: Date?,
        expiresAt: Date?,
        trustLevel: TrustLevel,
        secretMaterial: SecretKeyMaterial? = nil,
        cardSerialNumber: String? = nil
    ) {
        self.id = id
        self.keyID = keyID
        self.fingerprint = fingerprint
        self.name = name
        self.email = email
        self.algorithm = algorithm
        self.keyLength = keyLength
        self.isSecret = isSecret
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.trustLevel = trustLevel
        self.secretMaterial = secretMaterial ?? SecretKeyMaterial.defaultMaterial(for: isSecret)
        self.cardSerialNumber = cardSerialNumber
    }
    
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

    var isSmartCardStub: Bool {
        secretMaterial == .smartCardStub
    }

    var requiresHardwareTokenForPrivateOps: Bool {
        isSmartCardStub
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

private struct GPGSubkeyBuilder {
    var fingerprint: String = ""
    var keyID: String = ""
    var algorithm: String = ""
    var keyLength: Int = 0
    var usages: Set<SubkeyUsage> = []
    var createdAt: Date?
    var expiresAt: Date?
    var status: SubkeyStatus = .unknown
    var isSecretMaterial: Bool = false

    func build() -> GPGSubkey? {
        let normalizedFingerprint = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedFingerprint.isEmpty else {
            return nil
        }

        return GPGSubkey(
            fingerprint: normalizedFingerprint,
            keyID: keyID,
            algorithm: algorithm,
            keyLength: keyLength,
            usages: usages,
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: status,
            isSecretMaterial: isSecretMaterial
        )
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
    var secretMaterial: SecretKeyMaterial = .none
    var cardSerialNumber: String?

    func absorbSecretMaterialToken(_ rawValue: String?) {
        guard isSecret else { return }
        guard let rawValue else { return }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        if value == "+" {
            if secretMaterial != .smartCardStub {
                secretMaterial = .localSecret
            }
            return
        }

        if value == "#" {
            secretMaterial = .smartCardStub
            return
        }

        let normalizedSerial = value.replacingOccurrences(of: " ", with: "")
        guard !normalizedSerial.isEmpty else { return }
        secretMaterial = .smartCardStub
        if cardSerialNumber == nil {
            cardSerialNumber = normalizedSerial
        }
    }
    
    func build() -> GPGKey? {
        guard !fingerprint.isEmpty else { return nil }
        let resolvedSecretMaterial: SecretKeyMaterial
        if isSecret {
            resolvedSecretMaterial = secretMaterial == .none ? .localSecret : secretMaterial
        } else {
            resolvedSecretMaterial = .none
        }

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
            trustLevel: trustLevel,
            secretMaterial: resolvedSecretMaterial,
            cardSerialNumber: cardSerialNumber
        )
    }
}
