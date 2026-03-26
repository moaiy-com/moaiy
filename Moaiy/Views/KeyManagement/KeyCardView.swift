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
    @State private var processedFiles: [(url: URL, success: Bool, message: String)] = []
    @State private var showingResultOverlay = false
    
    private let detector = GPGFileTypeDetector()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            keyInfoSection
            
            DropZoneView(onDrop: { urls in
                handleDroppedFiles(urls: urls)
            })
            .frame(height: 50)
            
            if showingResultOverlay && !processedFiles.isEmpty {
                resultOverlayView
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
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
        processedFiles = []
        
        let detector = GPGFileTypeDetector()
        
        for url in urls {
            let fileType = await detector.detectFileType(at: url)
            
            await processFile(url: url, type: fileType)
        }
        
        showingResultOverlay = true
    }
    
    @MainActor
    private func processFile(url: URL, type: GPGFileType) async {
        do {
            switch type {
            case .encrypted:
                guard key.isSecret else {
                    processedFiles.append((url: url, success: false, message: "Decryption requires private key"))
                    return
                }
                let outputURL = url.deletingPathExtension()
                try await GPGService.shared.decryptFile(
                    sourceURL: url,
                    destinationURL: outputURL,
                    passphrase: ""
                )
                processedFiles.append((url: url, success: true, message: "Decrypted successfully"))
                
            case .notGPG:
                let outputURL = url.appendingPathExtension("gpg")
                try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: outputURL,
                    recipients: [key.fingerprint]
                )
                processedFiles.append((url: url, success: true, message: "Encrypted successfully"))
                
            case .publicKey, .privateKey:
                processedFiles.append((url: url, success: true, message: "Key import - use Import menu"))
                
            case .signature:
                processedFiles.append((url: url, success: false, message: "Signature verification not yet implemented"))
                
            case .unknown:
                processedFiles.append((url: url, success: false, message: "Unknown file type"))
            }
        } catch {
            processedFiles.append((url: url, success: false, message: error.localizedDescription))
        }
    }
}