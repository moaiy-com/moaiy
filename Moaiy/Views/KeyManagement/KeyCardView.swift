//
//  KeyCardView.swift
//  Moaiy
//
//  Simplified key card view with drop zone for drag-and-drop
//

import SwiftUI

struct KeyCardView: View {
    let key: GPGKey
    var onDelete: (() -> Void)?
    
    @State private var isProcessing = false
    @State private var operationResults: [OperationResult] = []
    @State private var showingResultOverlay = false
    @State private var showingPasswordSheet = false
    @State private var pendingDecryptRequests: [DecryptRequest] = []
    
    private let detector = GPGFileTypeDetector()

    private struct DecryptRequest {
        let sourceURL: URL
        let outputURL: URL
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            keyInfoSection
            
            KeyDropZoneView(onDrop: { urls in
                handleDroppedFiles(urls: urls)
            })
            .frame(height: 50)
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .sheet(isPresented: $showingResultOverlay) {
            OperationResultOverlay(
                results: operationResults,
                onDismiss: {
                    showingResultOverlay = false
                    operationResults = []
                },
                onOpenInFinder: { url in
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
            )
        }
        .sheet(isPresented: $showingPasswordSheet) {
            if let request = pendingDecryptRequests.first {
                PasswordInputSheet(
                    fileName: request.sourceURL.lastPathComponent,
                    onConfirm: { password in
                        showingPasswordSheet = false
                        Task {
                            await performQueuedDecryptions(password: password)
                        }
                    },
                    onCancel: {
                        showingPasswordSheet = false
                        pendingDecryptRequests = []
                        if !operationResults.isEmpty {
                            showingResultOverlay = true
                        }
                    }
                )
            }
        }
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(key.fingerprint, forType: .string)
            }) {
                Label("action_copy_fingerprint", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: {
                onDelete?()
            }) {
                Label("action_delete_key", systemImage: "trash.fill")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var keyInfoSection: some View {
        HStack(spacing: 16) {
            Image(systemName: key.isSecret ? "key.fill" : "key")
                .font(.title2)
                .foregroundStyle(keyIconColor)
                .frame(width: 40, height: 40)
                .background(keyIconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(key.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(key.isSecret ? "key_type_private" : "key_type_public")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(keyTypeBadgeColor.opacity(0.2))
                        .foregroundStyle(keyTypeBadgeColor)
                        .clipShape(Capsule())
                    
                    Text(key.trustLevel.localizedName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trustLevelColor.opacity(0.2))
                        .foregroundStyle(trustLevelColor)
                        .clipShape(Capsule())
                    
                    if key.isExpired {
                        Text("status_expired")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                
                Text(key.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label(key.displayKeyType, systemImage: "number")
                    if let createdAt = key.createdAt {
                        Text("•")
                        Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("action_encrypt", action: encryptFromPicker)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                KeyActionMenu(key: key, onDelete: onDelete)
            }
        }
    }
    
    // MARK: - Color Computed Properties
    
    private var keyIconColor: Color {
        key.isSecret ? Color.moaiyAccent : .secondary
    }
    
    private var keyTypeBadgeColor: Color {
        key.isSecret ? Color.moaiyAccent : .blue
    }
    
    private var trustLevelColor: Color {
        switch key.trustLevel {
        case .ultimate:
            return .green
        case .full:
            return .blue
        case .marginal:
            return .orange
        case .none:
            return .red
        case .unknown:
            return .secondary
        }
    }
    
    // MARK: - File Handling

    private func encryptFromPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "drop_zone_hint")

        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }

        Task {
            await encryptFiles(selectedURLs)
        }
    }

    @MainActor
    private func encryptFiles(_ urls: [URL]) async {
        isProcessing = true
        operationResults = []

        for url in urls {
            do {
                let defaultOutputURL = KeyActionFilePlanner.encryptedOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    continue
                }

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = outputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        outputURL.stopAccessingSecurityScopedResource()
                    }
                }

                try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: outputURL,
                    recipients: [key.fingerprint]
                )
                operationResults.append(
                    OperationResult.successEncrypt(fileURL: url, outputURL: outputURL)
                )
            } catch {
                operationResults.append(
                    OperationResult.failure(
                        fileURL: url,
                        operation: .encrypt,
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }

        isProcessing = false
        if !operationResults.isEmpty {
            showingResultOverlay = true
        }
    }
    
    private func handleDroppedFiles(urls: [URL]) {
        Task { @MainActor in
            isProcessing = true
            operationResults = []
            pendingDecryptRequests = []
            
            for url in urls {
                let fileType = await detector.detectFileType(at: url)
                await processFile(url: url, type: fileType)
            }
            
            isProcessing = false
            if !pendingDecryptRequests.isEmpty {
                showingPasswordSheet = true
                return
            }
            if !operationResults.isEmpty {
                showingResultOverlay = true
            }
        }
    }
    
    @MainActor
    private func processFile(url: URL, type: GPGFileType) async {
        do {
            switch type {
            case .encrypted:
                guard key.isSecret else {
                    operationResults.append(
                        OperationResult.failure(
                            fileURL: url,
                            operation: .decrypt,
                            errorMessage: String(localized: "error_decryption_requires_private_key")
                        )
                    )
                    return
                }

                let defaultOutputURL = KeyActionFilePlanner.decryptedOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    return
                }

                pendingDecryptRequests.append(
                    DecryptRequest(
                        sourceURL: url,
                        outputURL: outputURL
                    )
                )
                return
                
            case .notGPG:
                let defaultOutputURL = KeyActionFilePlanner.encryptedOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    return
                }

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = outputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        outputURL.stopAccessingSecurityScopedResource()
                    }
                }

                try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: outputURL,
                    recipients: [key.fingerprint]
                )
                operationResults.append(
                    OperationResult.successEncrypt(fileURL: url, outputURL: outputURL)
                )
                
            case .publicKey, .privateKey:
                operationResults.append(
                    OperationResult.failure(
                        fileURL: url,
                        operation: .import,
                        errorMessage: String(localized: "info_use_import_menu")
                    )
                )
                
            case .signature:
                operationResults.append(
                    OperationResult.failure(
                        fileURL: url,
                        operation: .verify,
                        errorMessage: String(localized: "error_signature_not_implemented")
                    )
                )
                
            case .unknown:
                operationResults.append(
                    OperationResult.failure(
                        fileURL: url,
                        operation: .encrypt,
                        errorMessage: String(localized: "error_unknown_file_type")
                    )
                )
            }
        } catch {
            operationResults.append(
                OperationResult.failure(
                    fileURL: url,
                    operation: .encrypt,
                    errorMessage: error.localizedDescription
                )
            )
        }
    }
    
    @MainActor
    private func performQueuedDecryptions(password: String) async {
        guard !pendingDecryptRequests.isEmpty else {
            return
        }
        
        isProcessing = true

        for request in pendingDecryptRequests {
            do {
                let hasSourceAccess = request.sourceURL.startAccessingSecurityScopedResource()
                let hasOutputAccess = request.outputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        request.sourceURL.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        request.outputURL.stopAccessingSecurityScopedResource()
                    }
                }

                try await GPGService.shared.decryptFile(
                    sourceURL: request.sourceURL,
                    destinationURL: request.outputURL,
                    passphrase: password
                )
                operationResults.append(
                    OperationResult.successDecrypt(fileURL: request.sourceURL, outputURL: request.outputURL)
                )
            } catch {
                operationResults.append(
                    OperationResult.failure(
                        fileURL: request.sourceURL,
                        operation: .decrypt,
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }
        
        pendingDecryptRequests = []
        isProcessing = false
        if !operationResults.isEmpty {
            showingResultOverlay = true
        }
    }

    private func presentFileOperationSavePanel(defaultFileName: String, preferredDirectory: URL) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName
        panel.directoryURL = preferredDirectory
        return panel.runModal() == .OK ? panel.url : nil
    }
}
