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
    
    @State private var importedFileURL: URL?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importResult: KeyImportResult?
    @State private var showingSuccess = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.moiayAccent)
                
                Text("action_import_key")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("import_key_description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // File selection
            VStack(spacing: 16) {
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
            }
            
            // Error message
            if let error = importError {
                ErrorBanner(message: error)
            }
            
            // Success message
            if let result = importResult {
                SuccessBanner(
                    message: String(localized: "import_success_message"),
                    details: String(localized: "import_success_details \(result.imported) \(result.unchanged)")
                )
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("action_import_key") {
                    importKey()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(importedFileURL == nil || isImporting)
            }
        }
        .padding(32)
        .frame(width: 500)
    }
    
    private func importKey() {
        guard let fileURL = importedFileURL else { return }
        
        isImporting = true
        importError = nil
        importResult = nil
        
        Task {
            do {
                let result = try await viewModel.importKey(from: fileURL)
                await MainActor.run {
                    importResult = result
                    isImporting = false
                    
                    // Auto dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    isImporting = false
                }
            }
        }
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
                .foregroundStyle(isTargeted ? Color.moiayAccent : .secondary)
            
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
        .background(isTargeted ? Color.moiayAccent.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.moiayAccent : Color.secondary.opacity(0.3), lineWidth: 2, antialiased: true)
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
                .foregroundStyle(Color.moiayAccent)
            
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
