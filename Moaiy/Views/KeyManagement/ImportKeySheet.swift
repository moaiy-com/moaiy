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

        var id: String { rawValue }
    }

    @State private var importMode: ImportMode = .file
    @State private var importedFileURL: URL?
    @State private var keyserverQuery = ""
    @State private var selectedKeyserver = "keys.openpgp.org"
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importResult: KeyImportResult?

    private let keyservers = [
        "keys.openpgp.org",
        "keyserver.ubuntu.com",
        "pgp.mit.edu"
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    Image(systemName: importMode == .file ? "square.and.arrow.down" : "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.moaiyAccent)

                    Text("action_import_key")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("import_key_description")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $importMode) {
                Text("action_select_files").tag(ImportMode.file)
                Text("import_from_keyserver").tag(ImportMode.keyserver)
            }
            .pickerStyle(.segmented)
            .onChange(of: importMode) { _, _ in
                importError = nil
                importResult = nil
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
                } else {
                    KeyserverImportCard(
                        query: $keyserverQuery,
                        selectedKeyserver: $selectedKeyserver,
                        keyservers: keyservers
                    )
                    .onChange(of: keyserverQuery) { _, _ in
                        importError = nil
                        importResult = nil
                    }
                }
            }

            // Error message
            if let error = importError {
                ErrorBanner(message: error)
            }

            // Success message
            if let result = importResult {
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
                .controlSize(.large)
                .disabled(!canImport || isImporting)
            }
        }
        .padding(32)
        .frame(width: 500)
    }

    private var canImport: Bool {
        if importMode == .file {
            return importedFileURL != nil
        }
        return !keyserverQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func runImport() {
        if importMode == .file {
            importFromFile()
        } else {
            importFromKeyserver()
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
                importError = error.localizedDescription
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
                importError = error.localizedDescription
                isImporting = false
            }
        }
    }
}

struct KeyserverImportCard: View {
    @Binding var query: String
    @Binding var selectedKeyserver: String
    let keyservers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("keyserver_label")
                .font(.headline)

            TextField("import_keyserver_query_placeholder", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Text("import_keyserver_query_hint")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("keyserver_label", selection: $selectedKeyserver) {
                ForEach(keyservers, id: \.self) { keyserver in
                    Text(keyserver).tag(keyserver)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    let onFileSelected: (URL) -> Void
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isTargeted ? "doc.badge.plus" : "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Color.moaiyAccent : .secondary)
            
            Text("drop_zone_title")
                .font(.headline)
            
            Text("drop_zone_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("action_select_files") {
                selectFile()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(isTargeted ? Color.moaiyAccent.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.moaiyAccent : Color.secondary.opacity(0.3), lineWidth: 2, antialiased: true)
        )
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
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title)
                .foregroundStyle(Color.moaiyAccent)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Success Banner

struct SuccessBanner: View {
    let message: String
    let details: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    ImportKeySheet()
        .environment(KeyManagementViewModel())
}
