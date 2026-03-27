//
//  KeyCardView.swift
//  Moaiy
//
//  Simplified key card view with drop zone for drag-and-drop
//

import SwiftUI

import os.log

struct KeyCardView: View {
    let key: GPGKey
    var onDelete: (() -> Void)?
    @Environment(\.controlActiveState) private var controlActiveState
    
    @State private var isProcessing = false
    @State private var operationResults: [OperationResult] = []
    @State private var showingResultOverlay = false
    @State private var showingPasswordSheet = false
    @State private var pendingDecryptURL: URL?
    @State private var pendingDecryptOutputURL: URL?
    
    private let detector = GPGFileTypeDetector()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            keyInfoSection
            
            DropZoneView(onDrop: { urls in
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
            if let url = pendingDecryptURL, let outputURL = pendingDecryptOutputURL {
                PasswordInputSheet(
                    fileName: url.lastPathComponent,
                    onConfirm: { password in
                        showingPasswordSheet = false
                        Task {
                            await performDecryption(
                                sourceURL: url,
                                outputURL: outputURL,
                                password: password
                            )
                        }
                    },
                    onCancel: {
                        showingPasswordSheet = false
                        pendingDecryptURL = nil
                        pendingDecryptOutputURL = nil
                    }
                )
            }
        }
        .contextMenu {
            Button(action: { }) {
                Label("action_encrypt", systemImage: "lock.fill")
            }
            Button(action: { }) {
                Label("action_decrypt", systemImage: "lock.open.fill")
            }
            Divider()
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(key.fingerprint, forType: .string)
            }) {
                Label("action_copy_fingerprint", systemImage: "doc.on.doc")
            }
            Button(action: { }) {
                Label("action_export_public_key", systemImage: "square.and.arrow.up")
            }
            if key.isSecret {
                Button(action: { }) {
                    Label("action_export_private_key", systemImage: "key.fill")
                }
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
                Button("action_encrypt") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Menu {
                    Button("action_export_public_key") { }
                    Button("action_copy_fingerprint") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(key.fingerprint, forType: .string)
                    }
                    Button("action_delete_key", role: .destructive) { }
                }
            }
        }
    }
    
    // MARK: - Color Computed Properties
    
    private var keyIconColor: Color {
        key.isSecret ? Color.moaiyAccent : .secondary
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
    
    @MainActor
    private func handleDroppedFiles(urls: [URL]) {
        isProcessing = true
        operationResults = []
        
        for url in urls {
            let fileType = await detector.detectFileType(at: url)
            await processFile(url: url, type: fileType)
        }
        
        isProcessing = false
        showingResultOverlay = true
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
                pendingDecryptURL = url
                pendingDecryptOutputURL = url.deletingPathExtension()
                showingPasswordSheet = true
                return
                
            case .notGPG:
                let outputURL = url.appendingPathExtension("gpg")
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
    private func performDecryption(password: String) async {
        guard let url = pendingDecryptURL,
              let outputURL = pendingDecryptOutputURL else {
            return
        }
        
        isProcessing = true
        
        do {
            try await GPGService.shared.decryptFile(
                sourceURL: url,
                destinationURL: outputURL,
                passphrase: password
            )
            operationResults.append(
                OperationResult.successDecrypt(fileURL: url, outputURL: outputURL)
            )
        } catch {
            operationResults.append(
                OperationResult.failure(
                    fileURL: url,
                    operation: .decrypt,
                    errorMessage: error.localizedDescription
                )
            )
        }
        
        pendingDecryptURL = nil
        pendingDecryptOutputURL = nil
        isProcessing = false
        showingResultOverlay = true
    }
}