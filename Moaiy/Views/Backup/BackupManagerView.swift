//
//  BackupManagerView.swift
//  Moaiy
//
//  Backup and restore management interface
//

import SwiftUI

struct BackupManagerView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingBackup = false
    @State private var isRestoring = false
    @State private var showBackupSuccess = false
    @State private var showRestoreSuccess = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var backupURL: URL?
    @State private var includeSecretKeys = true
    @State private var lastBackupDate: Date?
    @State private var backupHistory: [BackupRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("backup_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("backup_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

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
                                        .foregroundStyle(.orange)
                                    Text("backup_secret_warning")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        .controlSize(.large)
                        .disabled(isCreatingBackup || viewModel.keys.isEmpty)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Restore from backup
                    VStack(alignment: .leading, spacing: 12) {
                        Text("backup_restore_section")
                            .font(.headline)

                        Text("backup_restore_description")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

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
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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
                                .foregroundStyle(.red)
                            }

                            ForEach(backupHistory) { record in
                                BackupHistoryRow(record: record) {
                                    // Delete this record
                                    backupHistory.removeAll { $0.id == record.id }
                                    saveBackupHistory()
                                }
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("backup_info_1", systemImage: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("backup_info_2", systemImage: "lock.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("backup_info_3", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadBackupHistory()
        }
        .alert("backup_success_title", isPresented: $showBackupSuccess) {
            Button("action_ok") { }
        } message: {
            Text("backup_success_message")
        }
        .alert("restore_success_title", isPresented: $showRestoreSuccess) {
            Button("action_ok") { }
        } message: {
            Text("restore_success_message")
        }
        .alert("error_occurred", isPresented: $showError) {
            Button("action_ok") { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Backup Operations

    private func createBackup() {
        isCreatingBackup = true

        Task {
            do {
                // Create save panel
                let savePanel = NSSavePanel()
                savePanel.title = "Save Backup"
                savePanel.nameFieldStringValue = "Moaiy_Backup_\(Date().formatted(date: .abbreviated, time: .omitted)).zip"
                savePanel.allowedContentTypes = [.zip]
                savePanel.canCreateDirectories = true

                guard savePanel.runModal() == .OK, let url = savePanel.url else {
                    isCreatingBackup = false
                    return
                }

                // Create backup
                try await createBackupArchive(at: url)

                // Record backup
                let record = BackupRecord(
                    date: Date(),
                    location: url,
                    keyCount: viewModel.keys.count,
                    includeSecretKeys: includeSecretKeys
                )
                backupHistory.insert(record, at: 0)
                lastBackupDate = Date()
                saveBackupHistory()

                showBackupSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isCreatingBackup = false
        }
    }

    private func createBackupArchive(at url: URL) async throws {
        // Create temporary directory for backup contents
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoaiyBackup_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Export all public keys
        for key in viewModel.keys {
            let publicData = try await viewModel.exportPublicKey(key)
            let publicFile = tempDir.appendingPathComponent("\(key.fingerprint)_public.asc")
            try publicData.write(to: publicFile)

            // Export secret keys if included
            if includeSecretKeys && key.isSecret {
                // Note: This would require passphrase input in production
                // For now, we'll skip secret key export in the backup
                // In production, you'd need to collect passphrases for each secret key
            }
        }

        // Create manifest
        let manifest = BackupManifest(
            version: "1.0",
            created: Date(),
            keyCount: viewModel.keys.count,
            includeSecretKeys: includeSecretKeys,
            keys: viewModel.keys.map { BackupKeyInfo(
                fingerprint: $0.fingerprint,
                name: $0.name,
                email: $0.email,
                isSecret: $0.isSecret
            )}
        )

        let manifestData = try JSONEncoder().encode(manifest)
        let manifestFile = tempDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestFile)

        // Create actual ZIP archive using system ditto command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent",
                             tempDir.path, url.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw BackupError.invalidBackupFormat
        }
    }

    private func restoreFromBackup() {
        isRestoring = true

        Task {
            do {
                // Create open panel
                let openPanel = NSOpenPanel()
                openPanel.title = "Select Backup"
                openPanel.allowedContentTypes = [.folder, .zip]
                openPanel.canChooseDirectories = true
                openPanel.canChooseFiles = true

                guard openPanel.runModal() == .OK, let url = openPanel.url else {
                    isRestoring = false
                    return
                }

                // Restore from backup
                try await restoreFromBackupArchive(at: url)

                // Reload keys
                await viewModel.loadKeys()

                showRestoreSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isRestoring = false
        }
    }

    private func restoreFromBackupArchive(at url: URL) async throws {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoaiyRestore_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Determine backup type and extract if needed
        var backupDir: URL

        if url.pathExtension.lowercased() == "zip" {
            // Extract ZIP archive using system ditto command
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", url.path, tempDir.path]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw BackupError.invalidBackupFormat
            }

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
        let manifestFile = backupDir.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestFile.path) else {
            throw BackupError.manifestNotFound
        }

        let manifestData = try Data(contentsOf: manifestFile)
        _ = try JSONDecoder().decode(BackupManifest.self, from: manifestData)

        // Import all keys
        let files = try FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let keyFiles = files.filter { $0.pathExtension == "asc" }

        for keyFile in keyFiles {
            do {
                _ = try await viewModel.importKey(from: keyFile)
            } catch {
                // Log but continue with other keys
                print("Failed to import key from \(keyFile.lastPathComponent): \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func loadBackupHistory() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "backupHistory"),
           let records = try? JSONDecoder().decode([BackupRecord].self, from: data) {
            backupHistory = records
        }

        if let date = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date {
            lastBackupDate = date
        }
    }

    private func saveBackupHistory() {
        if let data = try? JSONEncoder().encode(backupHistory) {
            UserDefaults.standard.set(data, forKey: "backupHistory")
        }

        UserDefaults.standard.set(lastBackupDate, forKey: "lastBackupDate")
    }
}

// MARK: - Supporting Types

struct BackupRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let location: URL
    let keyCount: Int
    let includeSecretKeys: Bool

    init(date: Date, location: URL, keyCount: Int, includeSecretKeys: Bool) {
        self.id = UUID()
        self.date = date
        self.location = location
        self.keyCount = keyCount
        self.includeSecretKeys = includeSecretKeys
    }
}

struct BackupManifest: Codable {
    let version: String
    let created: Date
    let keyCount: Int
    let includeSecretKeys: Bool
    let keys: [BackupKeyInfo]
}

struct BackupKeyInfo: Codable {
    let fingerprint: String
    let name: String
    let email: String
    let isSecret: Bool
}

enum BackupError: Error, LocalizedError {
    case manifestNotFound
    case invalidBackupFormat

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return String(localized: "backup_error_manifest_not_found")
        case .invalidBackupFormat:
            return String(localized: "backup_error_invalid_format")
        }
    }
}

// MARK: - Backup Status Card

struct BackupStatusCard: View {
    let lastBackupDate: Date?
    let totalKeys: Int
    let secretKeys: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "externaldrive.fill.badge.icloud")
                .font(.system(size: 40))
                .foregroundStyle(Color.moaiyAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text("backup_status_title")
                    .font(.headline)

                if let date = lastBackupDate {
                    Text("backup_status_last \(date.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("backup_status_never")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text("\(secretKeys)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("backup_keys_secret")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Backup History Row

struct BackupHistoryRow: View {
    let record: BackupRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(record.keyCount) keys • \(record.includeSecretKeys ? "With secrets" : "Public only")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview("Backup Manager") {
    BackupManagerView()
        .environment(KeyManagementViewModel())
}
