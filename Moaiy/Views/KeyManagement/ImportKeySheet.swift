//
//  ImportKeySheet.swift
//  Moaiy
//
//  Import key sheet for importing GPG keys
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel

    private enum ImportMode: String, CaseIterable, Identifiable {
        case file
        case keyserver
        case system

        var id: String { rawValue }
    }

    @State private var importMode: ImportMode = .file
    @State private var importedFileURL: URL?
    @State private var keyserverQuery = ""
    @State private var selectedKeyserver = Constants.GPG.defaultKeyserver
    @State private var systemKeyringURL: URL?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importResult: KeyImportResult?
    @State private var migrationResult: KeyMigrationResult?

    private let keyservers = Constants.GPG.supportedKeyservers

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xxl) {
            // Header
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    Image(systemName: headerIconName)
                        .font(.system(size: 48))
                        .foregroundStyle(Color.moaiyAccentV2)

                    Text("action_import_key")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    Text("import_key_description")
                        .font(.body)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $importMode) {
                Text("action_select_files").tag(ImportMode.file)
                Text("import_from_keyserver").tag(ImportMode.keyserver)
                Text("migration_system_keyring_title").tag(ImportMode.system)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MoaiyUI.Spacing.xs)
            .onChange(of: importMode) { _, _ in
                importError = nil
                importResult = nil
                migrationResult = nil
            }

            // Import source
            VStack(spacing: 16) {
                if importMode == .file {
                    if let fileURL = importedFileURL {
                        FilePreviewCard(url: fileURL) {
                            importedFileURL = nil
                            importError = nil
                            importResult = nil
                        }
                    } else {
                        DropZoneView { url in
                            importedFileURL = url
                            importError = nil
                            importResult = nil
                        }
                    }
                } else if importMode == .keyserver {
                    KeyserverImportCard(
                        query: $keyserverQuery,
                        selectedKeyserver: $selectedKeyserver,
                        keyservers: keyservers
                    )
                    .onChange(of: keyserverQuery) { _, _ in
                        importError = nil
                        importResult = nil
                    }
                } else {
                    SystemKeyringImportCard(
                        selectedURL: systemKeyringURL,
                        isImporting: isImporting,
                        onSelectFolder: chooseSystemKeyringFolder
                    )

                    if let migrationResult {
                        MigrationResultCard(
                            result: migrationResult,
                            onRetry: migrationResult.sourceSecretKeyCount > 0 && !migrationResult.secretKeysMigrated
                                ? { importFromSystemKeyring() }
                                : nil
                        )
                    }
                }
            }

            // Error message
            if let error = importError {
                ErrorBanner(message: error)
            }

            // Success message
            if let result = importResult, importMode != .system {
                SuccessBanner(
                    message: String(localized: "import_success_message"),
                    details: String(
                        format: String(localized: "import_success_details"),
                        locale: Locale.current,
                        Int64(result.imported),
                        Int64(result.unchanged)
                    )
                )
            }

            // Actions
            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: {
                    runImport()
                }) {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("action_import_key")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .controlSize(.large)
                .disabled(!canImport || isImporting)
            }
        }
        .padding(MoaiyUI.Spacing.xxxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 420, idealWidth: 540, maxWidth: 720)
    }

    private var canImport: Bool {
        if importMode == .file {
            return importedFileURL != nil
        }
        if importMode == .keyserver {
            return !keyserverQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return systemKeyringURL != nil
    }

    private var headerIconName: String {
        switch importMode {
        case .file:
            return "square.and.arrow.down"
        case .keyserver:
            return "globe"
        case .system:
            return "internaldrive"
        }
    }

    private func runImport() {
        if importMode == .file {
            importFromFile()
        } else if importMode == .keyserver {
            importFromKeyserver()
        } else {
            importFromSystemKeyring()
        }
    }

    private func importFromFile() {
        guard let fileURL = importedFileURL else { return }

        isImporting = true
        importError = nil
        importResult = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.importKey(from: fileURL)
                importResult = result
                isImporting = false

                // Auto dismiss after success
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            } catch {
                importError = UserFacingErrorMapper.message(for: error, context: .importKey)
                isImporting = false
            }
        }
    }

    private func importFromKeyserver() {
        let query = keyserverQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isImporting = true
        importError = nil
        importResult = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.importKeyFromKeyserver(
                    query: query,
                    keyserver: selectedKeyserver
                )
                importResult = result
                isImporting = false

                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            } catch {
                importError = UserFacingErrorMapper.message(for: error, context: .importKey)
                isImporting = false
            }
        }
    }

    private func chooseSystemKeyringFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = GPGService.shared.systemGPGHomeURL.deletingLastPathComponent()
        panel.message = String(localized: "migration_keyring_picker_message")
        panel.prompt = String(localized: "action_select_external_keyring")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        systemKeyringURL = url
        importError = nil
        migrationResult = nil
    }

    private func importFromSystemKeyring() {
        guard let sourceURL = systemKeyringURL else { return }

        isImporting = true
        importError = nil
        importResult = nil
        migrationResult = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.migrateKeysFromExternalKeyring(at: sourceURL)
                migrationResult = result
                isImporting = false
            } catch {
                importError = UserFacingErrorMapper.message(for: error, context: .importKey)
                isImporting = false
            }
        }
    }
}

struct SystemKeyringImportCard: View {
    let selectedURL: URL?
    let isImporting: Bool
    let onSelectFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("migration_system_keyring_message")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)

            if let selectedURL {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.moaiyAccentV2)
                    Text(selectedURL.path)
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(MoaiyUI.Spacing.sm)
                .moaiyBannerStyle(tint: Color.moaiyInfo)
            }

            Button(action: onSelectFolder) {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("action_select_external_keyring", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
        }
        .moaiyModalCard()
    }
}

struct MigrationResultCard: View {
    let result: KeyMigrationResult
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
            Text("import_success_message")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            Text(
                String(
                    format: String(localized: "import_success_details"),
                    locale: Locale.current,
                    Int64(result.imported),
                    Int64(result.unchanged)
                )
            )
            .font(.caption)
            .foregroundStyle(Color.moaiyTextSecondary)

            Text(
                "\(result.sourcePublicKeyCount) \(String(localized: "key_type_public")) • \(result.sourceSecretKeyCount) \(String(localized: "backup_keys_secret"))"
            )
            .font(.caption)
            .foregroundStyle(Color.moaiyTextSecondary)

            if result.sourceSecretKeyCount > 0 && !result.secretKeysMigrated {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                    Text("migration_secret_keys_incomplete_warning")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyWarning)

                    if let onRetry {
                        Button("action_retry") {
                            onRetry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: Color.moaiySuccess)
    }
}

struct KeyserverImportCard: View {
    @Binding var query: String
    @Binding var selectedKeyserver: String
    let keyservers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("keyserver_label")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            TextField("import_keyserver_query_placeholder", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Text("import_keyserver_query_hint")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)

            Picker("keyserver_label", selection: $selectedKeyserver) {
                ForEach(keyservers, id: \.self) { keyserver in
                    Text(keyserver).tag(keyserver)
                }
            }
            .pickerStyle(.menu)
        }
        .moaiyModalCard()
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    let onFileSelected: (URL) -> Void
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.lg) {
            Image(systemName: isTargeted ? "doc.badge.plus" : "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Color.moaiyAccentV2 : Color.moaiyTextSecondary)
            
            Text("drop_zone_title")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)
            
            Text("drop_zone_subtitle")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)
            
            Button("action_select_files") {
                selectFile()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(isTargeted ? Color.moaiyAccentV2.opacity(0.08) : Color.moaiySurfaceSecondary.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: MoaiyUI.Radius.lg, style: .continuous)
                .stroke(
                    isTargeted ? Color.moaiyFocusRing : Color.moaiyBorderPrimary.opacity(0.85),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: MoaiyUI.Radius.lg, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "asc") ?? .item,
            .init(filenameExtension: "gpg") ?? .item,
            .init(filenameExtension: "pgp") ?? .item
        ]
        panel.message = String(localized: "import_file_picker_message")
        
        if panel.runModal() == .OK, let url = panel.url {
            onFileSelected(url)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    onFileSelected(url)
                }
            }
        }
        
        return true
    }
}

// MARK: - File Preview Card

struct FilePreviewCard: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: MoaiyUI.Spacing.md) {
            Image(systemName: "doc.text.fill")
                .font(.title)
                .foregroundStyle(Color.moaiyAccentV2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .foregroundStyle(Color.moaiyTextPrimary)
                    .lineLimit(1)
                
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.moaiyTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.md)
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: MoaiyUI.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.moaiyError)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextPrimary)
            
            Spacer()
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: Color.moaiyError)
    }
}

// MARK: - Success Banner

struct SuccessBanner: View {
    let message: String
    let details: String
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.sm) {
            HStack(spacing: MoaiyUI.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.moaiySuccess)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.moaiyTextPrimary)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                Text(details)
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: Color.moaiySuccess)
    }
}

// MARK: - Preview

#Preview {
    ImportKeySheet()
        .environment(KeyManagementViewModel())
}
