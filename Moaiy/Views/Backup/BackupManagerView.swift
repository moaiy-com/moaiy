//
//  BackupManagerView.swift
//  Moaiy
//
//  Backup and restore management interface
//

import SwiftUI
import CryptoKit
import Darwin

struct BackupManagerView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingBackup = false
    @State private var isRestoring = false
    @State private var promptAlert: PromptAlertContent?
    @State private var pendingBackupURL: URL?
    @State private var showingSecretKeyPassphraseSheet = false
    @State private var includeSecretKeys = true
    @State private var lastBackupDate: Date?
    @State private var backupHistory: [BackupRecord] = []

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("backup_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text("backup_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            ScrollView {
                VStack(spacing: 24) {
                    // Backup status card
                    BackupStatusCard(
                        lastBackupDate: lastBackupDate,
                        totalKeys: viewModel.keys.count,
                        secretKeys: viewModel.secretKeys.count
                    )

                    // Create backup section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("backup_create_section")
                            .font(.headline)

                        // Options
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("backup_include_secret", isOn: $includeSecretKeys)
                                .font(.subheadline)

                            if includeSecretKeys {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.moaiyWarning)
                                    Text("backup_secret_warning")
                                        .font(.caption)
                                        .foregroundStyle(Color.moaiyTextSecondary)
                                }
                                .padding(MoaiyUI.Spacing.sm)
                                .moaiyBannerStyle(tint: Color.moaiyWarning, cornerRadius: MoaiyUI.Radius.sm)
                            }
                        }

                        Button(action: createBackup) {
                            if isCreatingBackup {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("backup_create_button", systemImage: "icloud.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.moaiyAccentV2)
                        .controlSize(.large)
                        .disabled(isCreatingBackup || viewModel.keys.isEmpty)
                    }
                    .padding(MoaiyUI.Spacing.lg)
                    .moaiyCardStyle()

                    // Restore from backup
                    VStack(alignment: .leading, spacing: 12) {
                        Text("backup_restore_section")
                            .font(.headline)

                        Text("backup_restore_description")
                            .font(.subheadline)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Button(action: restoreFromBackup) {
                            if isRestoring {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("backup_restore_button", systemImage: "icloud.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isRestoring)
                    }
                    .padding(MoaiyUI.Spacing.lg)
                    .moaiyCardStyle()

                    // Backup history
                    if !backupHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("backup_history_section")
                                    .font(.headline)

                                Spacer()

                                Button("action_clear_all") {
                                    backupHistory.removeAll()
                                    saveBackupHistory()
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(Color.moaiyError)
                            }

                            ForEach(backupHistory) { record in
                                BackupHistoryRow(record: record) {
                                    // Delete this record
                                    backupHistory.removeAll { $0.id == record.id }
                                    saveBackupHistory()
                                }
                            }
                        }
                        .padding(MoaiyUI.Spacing.lg)
                        .moaiyCardStyle()
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("backup_info_1", systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Label("backup_info_2", systemImage: "lock.shield.fill")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Label("backup_info_3", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                    .padding(MoaiyUI.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .moaiyBannerStyle(tint: Color.moaiyInfo)
                }
                .padding(24)
            }
        }
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 540, idealWidth: 640, maxWidth: 780, minHeight: 560, idealHeight: 720, maxHeight: 920)
        .onAppear {
            SecureTempStorage.cleanupStaleDirectories()
            loadBackupHistory()
        }
        .sheet(isPresented: $showingSecretKeyPassphraseSheet) {
            PassphraseSheet(
                keyName: nil,
                allowsEmptyPassphrase: true,
                onConfirm: { passphrase in
                    showingSecretKeyPassphraseSheet = false
                    guard let destinationURL = pendingBackupURL else { return }
                    createBackup(at: destinationURL, secretKeyPassphrase: passphrase)
                },
                onCancel: {
                    showingSecretKeyPassphraseSheet = false
                    pendingBackupURL = nil
                }
            )
        }
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    // MARK: - Backup Operations

    private func createBackup() {
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = String(localized: "backup_create_section")
        savePanel.nameFieldStringValue = "Moaiy_Backup_\(Date().formatted(date: .abbreviated, time: .omitted)).zip"
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return
        }

        if includeSecretKeys && !viewModel.secretKeys.isEmpty {
            pendingBackupURL = url
            showingSecretKeyPassphraseSheet = true
            return
        }

        createBackup(at: url, secretKeyPassphrase: nil)
    }

    private func createBackup(at url: URL, secretKeyPassphrase: String?) {
        isCreatingBackup = true

        Task {
            do {
                // Create backup
                let summary = try await createBackupArchive(
                    at: url,
                    secretKeyPassphrase: secretKeyPassphrase
                )

                // Record backup
                let record = BackupRecord(
                    date: Date(),
                    backupFileName: url.lastPathComponent,
                    keyCount: viewModel.keys.count,
                    includeSecretKeys: includeSecretKeys,
                    exportedPublicKeyCount: summary.exportedPublicKeyCount,
                    exportedSecretKeyCount: summary.exportedSecretKeyCount,
                    failedSecretKeyCount: summary.failedSecretKeyCount
                )
                backupHistory.insert(record, at: 0)
                lastBackupDate = Date()
                saveBackupHistory()

                promptAlert = PromptAlertContent.success(
                    message: String(localized: "backup_success_message")
                )
            } catch {
                promptAlert = PromptAlertContent.failure(
                    context: .backup,
                    error: error
                )
            }
            isCreatingBackup = false
            pendingBackupURL = nil
        }
    }

    private func createBackupArchive(at url: URL, secretKeyPassphrase: String?) async throws -> BackupExportSummary {
        // Create temporary directory for backup contents
        let tempDir = try SecureTempStorage.makeOperationDirectory(prefix: "backup")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        var exportedPublicKeyCount = 0
        var exportedSecretKeyCount = 0
        var failedSecretKeyFingerprints: [String] = []
        var firstSecretKeyExportError: String?
        var manifestFiles: [BackupManifestFileEntry] = []

        // Export all public keys
        for key in viewModel.keys {
            let publicData = try await viewModel.exportPublicKey(key)
            let publicFile = tempDir.appendingPathComponent("\(key.fingerprint)_public.asc")
            try writeBackupPayload(publicData, to: publicFile)
            manifestFiles.append(
                BackupManifestFileEntry(
                    fileName: publicFile.lastPathComponent,
                    sha256: BackupIntegrityVerifier.sha256Hex(for: publicData),
                    kind: .publicKey
                )
            )
            exportedPublicKeyCount += 1

            // Export secret keys if included
            if includeSecretKeys && key.isSecret {
                do {
                    let secretData = try await viewModel.exportSecretKey(
                        key,
                        passphrase: secretKeyPassphrase ?? ""
                    )
                    let secretFile = tempDir.appendingPathComponent("\(key.fingerprint)_secret.asc")
                    try writeBackupPayload(secretData, to: secretFile)
                    manifestFiles.append(
                        BackupManifestFileEntry(
                            fileName: secretFile.lastPathComponent,
                            sha256: BackupIntegrityVerifier.sha256Hex(for: secretData),
                            kind: .secretKey
                        )
                    )
                    exportedSecretKeyCount += 1
                } catch {
                    failedSecretKeyFingerprints.append(key.fingerprint)
                    if firstSecretKeyExportError == nil {
                        firstSecretKeyExportError = UserFacingErrorMapper.message(for: error, context: .exportKey)
                    }
                }
            }
        }

        let summary = BackupExportSummary(
            exportedPublicKeyCount: exportedPublicKeyCount,
            requestedSecretKeyCount: includeSecretKeys ? viewModel.secretKeys.count : 0,
            exportedSecretKeyCount: exportedSecretKeyCount,
            failedSecretKeyFingerprints: failedSecretKeyFingerprints,
            firstSecretKeyExportError: firstSecretKeyExportError
        )

        if includeSecretKeys, summary.hasSecretExportFailures {
            throw BackupError.secretKeyExportIncomplete(summary)
        }

        // Create manifest
        let manifest = BackupManifest(
            version: Constants.Backup.currentVersion,
            created: Date(),
            keyCount: viewModel.keys.count,
            includeSecretKeys: includeSecretKeys,
            exportedPublicKeyCount: summary.exportedPublicKeyCount,
            exportedSecretKeyCount: summary.exportedSecretKeyCount,
            failedSecretKeyCount: summary.failedSecretKeyCount,
            keys: viewModel.keys.map {
                BackupKeyInfo(
                    fingerprint: $0.fingerprint,
                    name: $0.name,
                    email: $0.email,
                    isSecret: $0.isSecret
                )
            },
            files: manifestFiles,
            totalFiles: manifestFiles.count
        )

        let manifestData = try JSONEncoder().encode(manifest)
        let manifestFile = tempDir.appendingPathComponent(Constants.Backup.manifestFileName)
        try writeBackupPayload(manifestData, to: manifestFile)

        // Create actual ZIP archive using system ditto command
        try await runDitto(
            arguments: [
                "-c",
                "-k",
                "--sequesterRsrc",
                "--keepParent",
                "--",
                tempDir.path,
                url.path
            ]
        )

        return summary
    }

    private func restoreFromBackup() {
        isRestoring = true

        Task {
            do {
                // Create open panel
                let openPanel = NSOpenPanel()
                openPanel.title = String(localized: "backup_restore_section")
                openPanel.allowedContentTypes = [.folder, .zip]
                openPanel.canChooseDirectories = true
                openPanel.canChooseFiles = true

                guard openPanel.runModal() == .OK, let url = openPanel.url else {
                    isRestoring = false
                    return
                }

                // Restore from backup
                let summary = try await restoreFromBackupArchive(at: url)

                if summary.failedFiles.isEmpty {
                    let restoreSuccessMessage = summary.usedLegacyRestrictedPath
                        ? String(localized: "restore_success_message_legacy_restricted")
                        : String(localized: "restore_success_message")
                    promptAlert = PromptAlertContent.success(
                        message: restoreSuccessMessage
                    )
                } else {
                    let failed = summary.failedFiles.joined(separator: ", ")
                    throw GPGError.importFailed("\(summary.successfulFiles)/\(summary.totalFiles) - \(failed)")
                }
            } catch {
                promptAlert = PromptAlertContent.failure(
                    context: .backup,
                    error: error
                )
            }
            isRestoring = false
        }
    }

    private func restoreFromBackupArchive(at url: URL) async throws -> RestoreSummary {
        // Create temporary directory for extraction
        let tempDir = try SecureTempStorage.makeOperationDirectory(prefix: "restore")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Determine backup type and extract if needed
        var backupDir: URL

        if url.pathExtension.lowercased() == "zip" {
            // Extract ZIP archive using system ditto command
            try await runDitto(
                arguments: [
                    "-x",
                    "-k",
                    "--",
                    url.path,
                    tempDir.path
                ]
            )

            // ditto extracts to a subdirectory with the archive name
            // Find the extracted directory
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            if let extractedDir = contents.first(where: { $0.hasDirectoryPath }) {
                backupDir = extractedDir
            } else {
                backupDir = tempDir
            }
        } else {
            // It's already a directory
            backupDir = url
        }

        // Read manifest
        let manifestFile = backupDir.appendingPathComponent(Constants.Backup.manifestFileName)
        guard FileManager.default.fileExists(atPath: manifestFile.path) else {
            throw BackupError.manifestNotFound
        }

        let manifestData = try Data(contentsOf: manifestFile)
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData)
        let validationResult: BackupValidationResult
        do {
            validationResult = try BackupIntegrityVerifier.validateImportableFiles(
                in: backupDir,
                manifest: manifest,
                maxFileSizeBytes: Constants.Backup.maxImportFileSizeBytes
            )
        } catch {
            throw BackupError.invalidBackupFormat
        }

        // Import all keys with a single keyring refresh.
        let keyFiles = validationResult.files
        let importSummary = await viewModel.importKeys(from: keyFiles)

        return RestoreSummary(
            totalFiles: importSummary.totalFiles,
            successfulFiles: importSummary.successfulFiles,
            failedFiles: importSummary.failedFiles,
            usedLegacyRestrictedPath: validationResult.usedLegacyRestrictedPath
        )
    }

    private func writeBackupPayload(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func runDitto(arguments: [String], timeout: TimeInterval = Constants.GPG.defaultTimeout) async throws {
        let result = try await runExternalProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: arguments,
            timeout: timeout
        )

        guard result.exitCode == 0 else {
            throw BackupError.invalidBackupFormat
        }
    }

    private func runExternalProcess(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> ExternalProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withTaskCancellationHandler {
            try process.run()

            let deadline = Date().addingTimeInterval(timeout)
            do {
                while process.isRunning && Date() < deadline {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
            } catch is CancellationError {
                Self.forceStopProcess(process)
                throw GPGError.operationCancelled
            }

            if process.isRunning {
                Self.forceStopProcess(process)
                throw BackupError.invalidBackupFormat
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: stdoutData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let stderr = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return ExternalProcessResult(
                exitCode: Int(process.terminationStatus),
                stdout: stdout,
                stderr: stderr
            )
        } onCancel: {
            Self.forceStopProcess(process)
        }
    }

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

    // MARK: - Persistence

    private func loadBackupHistory() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: Constants.StorageKeys.backupHistory),
           let records = try? JSONDecoder().decode([BackupRecord].self, from: data) {
            backupHistory = records
        }

        if let date = UserDefaults.standard.object(forKey: Constants.StorageKeys.lastBackupDate) as? Date {
            lastBackupDate = date
        }
    }

    private func saveBackupHistory() {
        if let data = try? JSONEncoder().encode(backupHistory) {
            UserDefaults.standard.set(data, forKey: Constants.StorageKeys.backupHistory)
        }

        UserDefaults.standard.set(lastBackupDate, forKey: Constants.StorageKeys.lastBackupDate)
    }
}

private struct RestoreSummary {
    let totalFiles: Int
    let successfulFiles: Int
    let failedFiles: [String]
    let usedLegacyRestrictedPath: Bool
}

private struct ExternalProcessResult {
    let exitCode: Int
    let stdout: String?
    let stderr: String?
}

struct BackupExportSummary {
    let exportedPublicKeyCount: Int
    let requestedSecretKeyCount: Int
    let exportedSecretKeyCount: Int
    let failedSecretKeyFingerprints: [String]
    let firstSecretKeyExportError: String?

    var failedSecretKeyCount: Int {
        failedSecretKeyFingerprints.count
    }

    var hasSecretExportFailures: Bool {
        failedSecretKeyCount > 0
    }

    var isSecretExportComplete: Bool {
        failedSecretKeyCount == 0 && requestedSecretKeyCount == exportedSecretKeyCount
    }
}

// MARK: - Supporting Types

struct BackupRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let backupFileName: String?
    let keyCount: Int
    let includeSecretKeys: Bool
    let exportedPublicKeyCount: Int?
    let exportedSecretKeyCount: Int?
    let failedSecretKeyCount: Int?

    init(
        date: Date,
        backupFileName: String?,
        keyCount: Int,
        includeSecretKeys: Bool,
        exportedPublicKeyCount: Int? = nil,
        exportedSecretKeyCount: Int? = nil,
        failedSecretKeyCount: Int? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.backupFileName = backupFileName
        self.keyCount = keyCount
        self.includeSecretKeys = includeSecretKeys
        self.exportedPublicKeyCount = exportedPublicKeyCount
        self.exportedSecretKeyCount = exportedSecretKeyCount
        self.failedSecretKeyCount = failedSecretKeyCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case backupFileName
        case location
        case keyCount
        case includeSecretKeys
        case exportedPublicKeyCount
        case exportedSecretKeyCount
        case failedSecretKeyCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        if let fileName = try container.decodeIfPresent(String.self, forKey: .backupFileName) {
            backupFileName = fileName
        } else if let legacyLocation = try container.decodeIfPresent(URL.self, forKey: .location) {
            backupFileName = legacyLocation.lastPathComponent
        } else {
            backupFileName = nil
        }
        keyCount = try container.decode(Int.self, forKey: .keyCount)
        includeSecretKeys = try container.decode(Bool.self, forKey: .includeSecretKeys)
        exportedPublicKeyCount = try container.decodeIfPresent(Int.self, forKey: .exportedPublicKeyCount)
        exportedSecretKeyCount = try container.decodeIfPresent(Int.self, forKey: .exportedSecretKeyCount)
        failedSecretKeyCount = try container.decodeIfPresent(Int.self, forKey: .failedSecretKeyCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(backupFileName, forKey: .backupFileName)
        try container.encode(keyCount, forKey: .keyCount)
        try container.encode(includeSecretKeys, forKey: .includeSecretKeys)
        try container.encodeIfPresent(exportedPublicKeyCount, forKey: .exportedPublicKeyCount)
        try container.encodeIfPresent(exportedSecretKeyCount, forKey: .exportedSecretKeyCount)
        try container.encodeIfPresent(failedSecretKeyCount, forKey: .failedSecretKeyCount)
    }
}

struct BackupManifest: Codable {
    let version: String
    let created: Date
    let keyCount: Int
    let includeSecretKeys: Bool
    let exportedPublicKeyCount: Int?
    let exportedSecretKeyCount: Int?
    let failedSecretKeyCount: Int?
    let keys: [BackupKeyInfo]
    let files: [BackupManifestFileEntry]?
    let totalFiles: Int?
}

struct BackupKeyInfo: Codable {
    let fingerprint: String
    let name: String
    let email: String
    let isSecret: Bool
}

enum BackupManifestFileKind: String, Codable {
    case publicKey
    case secretKey
}

struct BackupManifestFileEntry: Codable, Hashable {
    let fileName: String
    let sha256: String
    let kind: BackupManifestFileKind
}

struct BackupValidationResult {
    let files: [URL]
    let usedLegacyRestrictedPath: Bool
}

enum BackupIntegrityError: Error, LocalizedError {
    case invalidManifest
    case fileSetMismatch
    case fileHashMismatch
    case unsafeFile

    var errorDescription: String? {
        switch self {
        case .invalidManifest, .fileSetMismatch, .fileHashMismatch, .unsafeFile:
            return String(localized: "backup_error_invalid_format")
        }
    }
}

enum BackupIntegrityVerifier {
    static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    static func validateImportableFiles(
        in backupDir: URL,
        manifest: BackupManifest,
        maxFileSizeBytes: Int
    ) throws -> BackupValidationResult {
        let fileManager = FileManager.default
        let allFiles = try fileManager.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        let ascFiles = allFiles.filter { $0.pathExtension.lowercased() == "asc" }

        if manifest.version == "1.1", let entries = manifest.files {
            guard let totalFiles = manifest.totalFiles, totalFiles == entries.count else {
                throw BackupIntegrityError.invalidManifest
            }
            guard Set(entries.map(\.fileName)).count == entries.count else {
                throw BackupIntegrityError.invalidManifest
            }

            let allowedNames = Set(entries.map(\.fileName))
            let discoveredNames = Set(ascFiles.map(\.lastPathComponent))
            guard discoveredNames == allowedNames else {
                throw BackupIntegrityError.fileSetMismatch
            }

            var orderedFiles: [URL] = []
            for entry in entries {
                guard isSafeFileName(entry.fileName),
                      isWhitelistedManifestFileName(entry.fileName, kind: entry.kind) else {
                    throw BackupIntegrityError.invalidManifest
                }

                let fileURL = backupDir.appendingPathComponent(entry.fileName)
                try validateSafeRegularFile(fileURL, maxFileSizeBytes: maxFileSizeBytes)
                let fileData = try Data(contentsOf: fileURL)
                let digest = sha256Hex(for: fileData)
                guard digest.caseInsensitiveCompare(entry.sha256) == .orderedSame else {
                    throw BackupIntegrityError.fileHashMismatch
                }
                orderedFiles.append(fileURL)
            }

            return BackupValidationResult(
                files: orderedFiles,
                usedLegacyRestrictedPath: false
            )
        }

        if manifest.version == "1.0" {
            let allowedLegacyNames = Set(
                manifest.keys.compactMap { key in
                    normalizedFingerprintForFileName(key.fingerprint)
                }.flatMap { fingerprint in
                    [
                        "\(fingerprint)_public.asc",
                        "\(fingerprint)_secret.asc"
                    ]
                }.map { $0.lowercased() }
            )

            guard !allowedLegacyNames.isEmpty else {
                throw BackupIntegrityError.invalidManifest
            }

            let discoveredNames = Set(ascFiles.map { $0.lastPathComponent.lowercased() })
            guard discoveredNames.isSubset(of: allowedLegacyNames) else {
                throw BackupIntegrityError.fileSetMismatch
            }

            let restrictedFiles = ascFiles
                .filter { allowedLegacyNames.contains($0.lastPathComponent.lowercased()) }
                .sorted { lhs, rhs in
                    lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
                }
            guard !restrictedFiles.isEmpty else {
                throw BackupIntegrityError.fileSetMismatch
            }

            for fileURL in restrictedFiles {
                try validateSafeRegularFile(fileURL, maxFileSizeBytes: maxFileSizeBytes)
            }

            return BackupValidationResult(
                files: restrictedFiles,
                usedLegacyRestrictedPath: true
            )
        }

        throw BackupIntegrityError.invalidManifest
    }

    private static func validateSafeRegularFile(_ url: URL, maxFileSizeBytes: Int) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true else {
            throw BackupIntegrityError.unsafeFile
        }
        guard values.isSymbolicLink != true else {
            throw BackupIntegrityError.unsafeFile
        }
        if let fileSize = values.fileSize, fileSize > maxFileSizeBytes {
            throw BackupIntegrityError.unsafeFile
        }
    }

    private static func isSafeFileName(_ fileName: String) -> Bool {
        guard !fileName.isEmpty else { return false }
        return fileName == URL(fileURLWithPath: fileName).lastPathComponent
    }

    private static func isWhitelistedManifestFileName(_ fileName: String, kind: BackupManifestFileKind) -> Bool {
        let suffix: String
        switch kind {
        case .publicKey:
            suffix = "_public.asc"
        case .secretKey:
            suffix = "_secret.asc"
        }

        guard fileName.hasSuffix(suffix) else {
            return false
        }

        let fingerprint = String(fileName.dropLast(suffix.count))
        return normalizedFingerprintForFileName(fingerprint) != nil
    }

    private static func normalizedFingerprintForFileName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (16...64).contains(trimmed.count) else {
            return nil
        }
        guard trimmed.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        return trimmed.uppercased()
    }
}

private enum BackupError: Error, LocalizedError {
    case manifestNotFound
    case invalidBackupFormat
    case secretKeyExportIncomplete(BackupExportSummary)

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return String(localized: "backup_error_manifest_not_found")
        case .invalidBackupFormat:
            return String(localized: "backup_error_invalid_format")
        case .secretKeyExportIncomplete(let summary):
            let firstError = summary.firstSecretKeyExportError ?? String(localized: "error_export_failed")
            return "\(firstError) (\(summary.exportedSecretKeyCount)/\(summary.requestedSecretKeyCount))"
        }
    }
}

// MARK: - Backup Status Card

struct BackupStatusCard: View {
    let lastBackupDate: Date?
    let totalKeys: Int
    let secretKeys: Int

    var body: some View {
        HStack(spacing: MoaiyUI.Spacing.lg) {
            Image(systemName: "externaldrive.fill.badge.icloud")
                .font(.system(size: 40))
                .foregroundStyle(Color.moaiyAccentV2)

            VStack(alignment: .leading, spacing: 4) {
                Text("backup_status_title")
                    .font(.headline)
                    .foregroundStyle(Color.moaiyTextPrimary)

                if let date = lastBackupDate {
                    Text(
                        String(
                            format: String(localized: "backup_status_last"),
                            locale: Locale.current,
                            date.formatted(date: .long, time: .shortened)
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                } else {
                    Text("backup_status_never")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyWarning)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(totalKeys)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("backup_keys_total")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                HStack(spacing: 4) {
                    Text("\(secretKeys)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("backup_keys_secret")
                        .font(.caption2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
            }
        }
        .padding(MoaiyUI.Spacing.lg)
        .moaiyCardStyle()
    }
}

// MARK: - Backup History Row

struct BackupHistoryRow: View {
    let record: BackupRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.moaiyInfo)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let backupFileName = record.backupFileName, !backupFileName.isEmpty {
                    Text(backupFileName)
                        .font(.caption2)
                        .foregroundStyle(Color.moaiyTextSecondary.opacity(0.8))
                        .lineLimit(1)
                }

                Text(backupDetailText)
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(Color.moaiyError)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, MoaiyUI.Spacing.sm)
    }

    private var backupDetailText: String {
        if
            let exportedPublicKeyCount = record.exportedPublicKeyCount,
            let exportedSecretKeyCount = record.exportedSecretKeyCount
        {
            if record.includeSecretKeys {
                return "\(exportedPublicKeyCount) \(String(localized: "key_type_public")) • \(exportedSecretKeyCount) \(String(localized: "backup_keys_secret"))"
            }
            return "\(exportedPublicKeyCount) \(String(localized: "key_type_public"))"
        }

        return "\(record.keyCount) \(String(localized: "backup_keys_total")) • \(record.includeSecretKeys ? String(localized: "backup_include_secret") : String(localized: "key_type_public"))"
    }
}

// MARK: - Preview

#Preview("Backup Manager") {
    BackupManagerView()
        .environment(KeyManagementViewModel())
}
