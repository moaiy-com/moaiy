//
//  KeyCardWithDropZone.swift
//  Moaiy
//
//  Extended KeyCardView with drop zone functionality
//

import SwiftUI

struct KeyCardWithDropZone: View {
    let key: GPGKey
    var onDelete: (() -> Void)?
    
    @State private var isProcessing = false
    @State private var processedFiles: [(url: URL, success: Bool, message: String)] = []
    @State private var showingResult = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KeyCardView(key: key, onDelete: onDelete)
            
            DropZoneView(onDrop: { urls in
                handleDroppedFiles(urls)
            })
            
            if showingResult && !processedFiles.isEmpty {
                resultOverlay
            }
        }
    }
    
    // MARK: - Result Overlay
    
    @ViewBuilder
    private var resultOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("operation_results")
                    .font(.headline)
                Spacer()
                Button(action: { showingResult = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            if processedFiles.isEmpty {
                Text("no_files_processed")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(processedFiles, id: \.url) { result in
                    HStack(spacing: 8) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.url.lastPathComponent)
                                .font(.body)
                                .lineLimit(1)
                            Text(result.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - File Handling
    
    private func handleDroppedFiles(_ urls: [URL]) {
        Task {
            isProcessing = true
            processedFiles = []
            
            let detector = GPGFileTypeDetector()
            
            for url in urls {
                let fileType = await detector.detectFileType(at: url)
                await processFile(url: url, type: fileType)
            }
            
            isProcessing = false
            showingResult = true
        }
    }
    
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
                processedFiles.append((url: url, success: true, message: "Use Import menu action"))
                
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

#Preview {
    KeyCardWithDropZone(key: GPGKey(
        id: "test",
        name: "Test User",
        email: "test@example.com",
        fingerprint: "ABC123",
        isSecret: true,
        trustLevel: .ultimate,
        keyType: "RSA",
        createdAt: Date()
    ))
    .frame(width: 400)
}
