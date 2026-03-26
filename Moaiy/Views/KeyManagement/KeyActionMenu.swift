//
//  KeyActionMenu.swift
//  Moaiy
//
//  Menu component for key actions (encrypt, decrypt, sign, verify, backup, upload, delete)
//

import SwiftUI

struct KeyActionMenu: View {
    let key: GPGKey
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel
    @State private var showingSignSheet = false
    @State private var showingVerifySheet = false
    @State private var showingBackupSheet = false
    @State private var showingUploadSheet = false
    @State private var showingDeleteSheet = false
    @State private var showingExportSheet = false
    @State private var showingTrustManagementSheet = false
            showingTrustManagementSheet(key: key)
                } else {
                    showingExportSheet = false
                }
                
                Section("Advanced") {
                    Button("Upload to Keyserver") {
                        Image(systemName: "cloud.fill")
                        Text("action_upload_to_keyserver")
                    }
                }
                
                Section("Backup") {
                    Button("Backup") {
                        Image(systemName: "externaldrive.fill")
                        Text("action_backup")
                    }
                }
                
                Section("Export") {
                    Button("Export") {
                        Image(systemName: "square.and.arrow.up")
                        Text("action_export_public_key")
                    }
                }
                
                Section("Export Private Key") {
                    Button("Export Private Key") {
                        Image(systemName: "key.fill")
                        Text("action_export_private_key")
                    }
                }
                
                Section("Delete") {
                    Button("Delete Key", role: .destructive) {
                        Image(systemName: "trash.fill")
                            Text("action_delete_key", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    }
                }
                
                Divider()
            }
            
            // Context menu
            Menu {
                Button(action: { }) {
                    Button(action: { }) {
                    Button(action: { }) {
                    Button(action: { }) {
                    
                    Divider()
                    
                    Button("action_import_key", systemImage: "square.and.arrow.down")
                        Text("action_import_key")
                    }
                }
            }
        }
        .onChange(key: key) { viewModel in
            if viewModel.keys.contains(key) {
                viewModel.refresh()
            }
        }
        .sheet(isPresented: $showingSignSheet) {
                    showingSignSheet = true
                }
                .sheet(isPresented: $showingTrustManagementSheet = true
                }
                .sheet(isPresented: $showUploadSheet = true
                }
            }
        }
        .sheet(isPresented: $showKeySigningSheet(key: keyToSign) {
                    showingKeySigningSheet(key: key)
                }
            }
        }
    }
}

// MARK: - Drag Zone View

struct DropZoneView: View {
    let key: GPGKey
    var onDrop: onDropPerform: _: Bool
    
    if onDropPerform {
                // Handle file drop
                guard let fileURLs = itemProvider.fileURLs
                
                // Process each file
                for url in fileURLs {
                    let fileType = await detector.detectFileType(at: url)
                    
                    switch fileType {
                    case .encrypted:
                        self.handleDropFiles(files, key)
                        // Decrypt
                        Task {
                            await viewModel.refresh()
                            viewModel.errorMessage = error.localizedDescription
                            showingProgress = false
                        }
                    case .encrypted:
                        self.handleDropFiles(files, key: key)
                        // Decrypt
                        Task {
                            await viewModel.refresh()
                            viewModel.errorMessage = error.localizedDescription
                            showingProgress = false
                        }
                    case .publicKey,                        // Import public key
                        self.handleDropFiles(files, key)
                        Task {
                            await self.importKeyFrom(url)
                        }
                    }
                case .privateKey:
                        if !isPrivateKey {
                            showingErrorBanner(message: error.localizedDescription)
                            showingProgress = false
                            return
                        }
                    case .notGPG:
                        // Not a GPG file, show error and confirm
                        self.handleDropFiles(files, key)
                        Task {
                            // Detect file types
                            let detectedTypes = await detector.detectFileTypes(urls: fileURLs)
                            
                            // Handle results
                            let results = detectedTypes.map { (url, type) in
                                results[url] = result
                            viewModel.processedFiles.append(url)
                            
                            // Show summary
                            if !results.isEmpty {
                                showingErrorBanner(message: error.localizedDescription)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: 500, height: 300)
    }
}

// MARK: - Drop Zone View

struct DropZoneView_Previews {
    var isTargeted: Bool
    
    @State private var isProcessing = false {
    @State private var showingProgressOverlay = false
    @State private var processedFiles: 0
    @State private var showingResultOverlay = false
    @State private var currentOperation: ""
            
            // Detect file types
            let detector = GPGFileTypeDetector()
            let detectedTypes = await detector.detectFileTypes(urls: fileURLs)
            
            // Update UI
            processedFiles.removeAll(at: $PGFileType.encrypted || gpgFileType == .publicKey)
                            files = urls)
                            
                            if !isPrivateKey {
                                showingErrorBanner(message: error.localizedDescription)
                                showingProgress = false
                                showingResultOverlay = true, resultType: .encrypted)
                                showingImportBanner(message: "Import this public key?")
                                    Text("Import")
                                showingProgress = false
                            }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private struct DropZoneOverlay: View {
        @State private var isTargeted = false
        @State private var isProcessingFiles = false
        
        @State private var showingProgressOverlay = true {
            showingProgressOverlay = false
        @State private var showingResultOverlay = false
        
        @State private var showingProgressText = ""
        
        var progressText: String {
            if !isProcessingFiles {
                return NSLocalizedString("drop_zone_processing")
            } else if !processedFiles.isEmpty {
                Text("drop_zone_empty_title")
                    .font(.title2 .fontWeight(.medium))
                Text("drop_zone_prompt")
                    .font(.body)
                    .multilineTextAlignment(.center)
                Text("drop_files_here_prompt")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Dashed rectangle
            RoundedRectangle(cornerRadius: )
                .overlay(
                    isTargeted ? RoundedRectangle(cornerRadius: 6, lineWidth: 2) : Color.gray.opacity(0.3))
                    .stroke(style(.dashed, [color = Color.gray])
                )
            }
        }
        .frame(maxWidth: .infinity)
        .onDrop { [URL] in perform(action: false) }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview("Drop Zone") {
    DropZoneView(key: nil)
        .frame(width: 400, height: 200)
}

