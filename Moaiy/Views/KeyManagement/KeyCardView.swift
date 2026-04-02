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
    @State private var passwordSheetFileName = ""
    @State private var pendingDecryptRequests: [DecryptRequest] = []
    
    private let detector = GPGFileTypeDetector()

    private struct DecryptRequest {
        let sourceURL: URL
        let outputURL: URL
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            keyInfoSection
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 0.5)
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
            PasswordInputSheet(
                fileName: passwordSheetFileName,
                onConfirm: { password in
                    showingPasswordSheet = false
                    passwordSheetFileName = ""
                    Task {
                        await performQueuedDecryptions(password: password)
                    }
                },
                onCancel: {
                    showingPasswordSheet = false
                    passwordSheetFileName = ""
                    pendingDecryptRequests = []
                    if !operationResults.isEmpty {
                        showingResultOverlay = true
                    }
                }
            )
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
        HStack(alignment: .center, spacing: 12) {
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
                        .lineLimit(1)
                        .truncationMode(.tail)

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
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 12) {
                        Label(key.displayKeyType, systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label(keyDateRangeDisplayText, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(key.isExpired ? Color.red : .secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 800, alignment: .leading)
            .layoutPriority(1)

            KeyDropZoneView(
                hintTextKey: key.isSecret ? "drop_zone_hint" : "drop_zone_encrypt_title",
                onDrop: { urls in
                    handleDroppedFiles(urls: urls)
                },
                onTap: {
                    selectFilesAndProcess()
                }
            )
            .frame(minWidth: 80, idealWidth: 520, maxWidth: .infinity, alignment: .trailing)
            .frame(height: 52)
            .layoutPriority(3)

            KeyActionMenu(key: key, onDelete: onDelete)
                .frame(width: 36, alignment: .trailing)
                .fixedSize()
                .layoutPriority(3)
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

    private var keyDateRangeDisplayText: String {
        let createdText = key.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "-"
        let expirationText: String
        if let expiresAt = key.expiresAt {
            expirationText = expiresAt.formatted(date: .abbreviated, time: .omitted)
        } else {
            expirationText = String(localized: "statistics_no_expiration")
        }

        return "\(createdText) - \(expirationText)"
    }
    
    // MARK: - File Handling

    private func handleDroppedFiles(urls: [URL]) {
        Task { @MainActor in
            isProcessing = true
            operationResults = []
            pendingDecryptRequests = []
            passwordSheetFileName = ""
            
            for url in urls {
                let hasScopedAccess = url.startAccessingSecurityScopedResource()
                let fileType = await detector.detectFileType(at: url)
                if hasScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                await processFile(url: url, type: fileType)
            }
            
            isProcessing = false
            if !pendingDecryptRequests.isEmpty {
                passwordSheetFileName = pendingDecryptRequests.first?.sourceURL.lastPathComponent ?? ""
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
                let plannedOutputURL = KeyActionFilePlanner.nonConflictingURL(for: outputURL)

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = plannedOutputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        plannedOutputURL.stopAccessingSecurityScopedResource()
                    }
                }

                let finalOutputURL = try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: plannedOutputURL,
                    recipients: [key.fingerprint]
                )
                operationResults.append(
                    OperationResult.successEncrypt(fileURL: url, outputURL: finalOutputURL)
                )

            case .publicKey, .privateKey, .signature, .unknown:
                let defaultOutputURL = KeyActionFilePlanner.encryptedOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    return
                }
                let plannedOutputURL = KeyActionFilePlanner.nonConflictingURL(for: outputURL)

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = plannedOutputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        plannedOutputURL.stopAccessingSecurityScopedResource()
                    }
                }

                let finalOutputURL = try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: plannedOutputURL,
                    recipients: [key.fingerprint]
                )
                operationResults.append(
                    OperationResult.successEncrypt(fileURL: url, outputURL: finalOutputURL)
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
                let plannedOutputURL = KeyActionFilePlanner.nonConflictingURL(for: request.outputURL)
                let hasSourceAccess = request.sourceURL.startAccessingSecurityScopedResource()
                let hasOutputAccess = plannedOutputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        request.sourceURL.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        plannedOutputURL.stopAccessingSecurityScopedResource()
                    }
                }

                let finalOutputURL = try await GPGService.shared.decryptFile(
                    sourceURL: request.sourceURL,
                    destinationURL: plannedOutputURL,
                    passphrase: password
                )
                operationResults.append(
                    OperationResult.successDecrypt(fileURL: request.sourceURL, outputURL: finalOutputURL)
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

    private func selectFilesAndProcess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.message = String(localized: "action_select_files")
        panel.prompt = String(localized: "action_select_files")

        guard panel.runModal() == .OK else { return }
        handleDroppedFiles(urls: panel.urls)
    }
}
