//
//  EncryptionView.swift
//  Moaiy
//
//  Encryption and decryption main view
//

import SwiftUI
import UniformTypeIdentifiers

struct EncryptionView: View {
    @State private var viewModel = EncryptionViewModel()
    @State private var selectedTab = 0
    @State private var showPassphraseSheet = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var pendingDecryptionText = ""
    @State private var showHistory = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("tab_text").tag(0)
                Text("tab_file").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            ZStack {
                if selectedTab == 0 {
                    TextEncryptionView(
                        viewModel: viewModel,
                        showPassphraseSheet: $showPassphraseSheet,
                        showSuccessMessage: $showSuccessMessage,
                        successMessage: $successMessage
                    )
                } else {
                    FileEncryptionView(
                        viewModel: viewModel,
                        showPassphraseSheet: $showPassphraseSheet,
                        showSuccessMessage: $showSuccessMessage,
                        successMessage: $successMessage
                    )
                }
                
                // Loading overlay
                if viewModel.isEncrypting || viewModel.isDecrypting {
                    LoadingOverlay(
                        message: viewModel.isEncrypting ? "encrypting_message" : "decrypting_message"
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isEncrypting)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isDecrypting)
        }
        .navigationTitle("section_encryption")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showHistory = true }) {
                    Label("action_view_history", systemImage: "clock.arrow.circlepath")
                }
                .badge(viewModel.operationHistory.isEmpty ? nil : "\(viewModel.operationHistory.count)")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.clearAll() }) {
                    Label("action_clear", systemImage: "trash")
                }
                .disabled(viewModel.inputText.isEmpty && viewModel.outputText.isEmpty)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.swapInputOutput() }) {
                    Label("action_swap", systemImage: "arrow.up.arrow.down")
                }
                .disabled(viewModel.outputText.isEmpty)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.pasteFromClipboard() }) {
                    Label("action_paste", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showHistory) {
            OperationHistoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPassphraseSheet) {
            PassphraseSheet(
                keyName: nil,
                onConfirm: { passphrase in
                    showPassphraseSheet = false
                    Task {
                        await viewModel.decryptText(passphrase: passphrase)
                        if viewModel.errorMessage == nil {
                            successMessage = "decryption_success"
                            showSuccessMessage = true
                        }
                    }
                },
                onCancel: {
                    showPassphraseSheet = false
                }
            )
        }
        .alert("operation_success", isPresented: $showSuccessMessage) {
            Button("action_ok", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("error_occurred", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("action_ok", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Text Encryption View

struct TextEncryptionView: View {
    @Bindable var viewModel: EncryptionViewModel
    @Binding var showPassphraseSheet: Bool
    @Binding var showSuccessMessage: Bool
    @Binding var successMessage: String
    
    var body: some View {
        HSplitView {
            // Left panel: Input and controls
            VStack(alignment: .leading, spacing: 16) {
                // Recipient key picker
                RecipientKeyPicker(viewModel: viewModel)
                
                Divider()
                
                // Input text
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("label_input")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { viewModel.pasteFromClipboard() }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("action_paste_help")
                    }
                    
                    TextEditor(text: $viewModel.inputText)
                        .font(.body)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: encryptText) {
                        Label("action_encrypt", systemImage: "lock.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canEncrypt || viewModel.isEncrypting)
                    
                    Button(action: { showPassphraseSheet = true }) {
                        Label("action_decrypt", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!viewModel.canDecrypt || viewModel.isDecrypting)
                }
            }
            .padding()
            .frame(minWidth: 350, idealWidth: 450)
            
            // Right panel: Output
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("label_output")
                        .font(.headline)
                    
                    Spacer()
                    
                    if viewModel.hasOutput {
                        Button(action: { viewModel.copyOutputToClipboard() }) {
                            Label("action_copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                
                if viewModel.hasOutput {
                    TextEditor(text: .constant(viewModel.outputText))
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Operation info
                    if let opType = viewModel.lastOperationType, let time = viewModel.lastOperationTime {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("last_operation \(opType.rawValue) \(time.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    EmptyOutputView()
                }
            }
            .padding()
            .frame(minWidth: 350, idealWidth: 450)
        }
    }
    
    private func encryptText() {
        Task {
            await viewModel.encryptText()
            if viewModel.errorMessage == nil {
                successMessage = "encryption_success"
                showSuccessMessage = true
            }
        }
    }
}

// MARK: - Empty Output View

struct EmptyOutputView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("output_empty_title")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("output_empty_description")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
}

// MARK: - File Encryption View

struct FileEncryptionView: View {
    @Bindable var viewModel: EncryptionViewModel
    @Binding var showPassphraseSheet: Bool
    @Binding var showSuccessMessage: Bool
    @Binding var successMessage: String
    
    @State private var isTargeted = false
    @State private var selectedFiles: [URL] = []
    @State private var operationMode: FileOperationMode = .encrypt
    @State private var processingProgress: Double = 0
    @State private var isProcessing = false
    @State private var currentProcessingFile: String?
    
    private let bookmarkManager = FileBookmarkManager.shared
    
    var body: some View {
        HSplitView {
            // Left panel: Settings
            VStack(alignment: .leading, spacing: 16) {
                // Recipient key picker
                RecipientKeyPicker(viewModel: viewModel)
                
                Divider()
                
                // Operation mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("operation_mode_title")
                        .font(.headline)
                    
                    Picker("", selection: $operationMode) {
                        Text("mode_encrypt").tag(FileOperationMode.encrypt)
                        Text("mode_decrypt").tag(FileOperationMode.decrypt)
                    }
                    .pickerStyle(.radioGroup)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 300, idealWidth: 350)
            
            // Right panel: File drop zone
            VStack(spacing: 24) {
                Spacer()
                
                // Drop zone
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                        .foregroundStyle(isTargeted ? Color.moiayAccent : .secondary)
                    
                    VStack(spacing: 16) {
                        Image(systemName: operationMode == .encrypt ? "doc.badge.lock" : "doc.badge.unlock")
                            .font(.system(size: 48))
                            .foregroundStyle(isTargeted ? Color.moiayAccent : .secondary)
                        
                        Text(operationMode == .encrypt ? "drop_zone_encrypt_title" : "drop_zone_decrypt_title")
                            .font(.headline)
                        
                        Text("drop_zone_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 500, maxHeight: 300)
                .background(isTargeted ? Color.moiayAccent.opacity(0.05) : Color.clear)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleFileDrop(providers: providers)
                    return true
                }
                
                // Progress indicator
                if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView(value: processingProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 400)
                        
                        if let currentFile = currentProcessingFile {
                            Text("processing_file \(currentFile)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Selected files
                if !selectedFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("selected_files_title")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(selectedFiles.count) files")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(selectedFiles, id: \.self) { url in
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundStyle(.secondary)
                                        Text(url.lastPathComponent)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: { removeFile(url) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                    .frame(maxWidth: 500)
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("action_select_files") {
                        selectFiles()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isProcessing)
                    
                    Button(action: processFiles) {
                        Label(
                            operationMode == .encrypt ? "action_encrypt_files" : "action_decrypt_files",
                            systemImage: operationMode == .encrypt ? "lock.fill" : "lock.open.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedFiles.isEmpty || (operationMode == .encrypt && viewModel.selectedRecipientKeys.isEmpty) || isProcessing)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 400, idealWidth: 550)
        }
    }
    
    private func handleFileDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            }
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select files to \(operationMode == .encrypt ? "encrypt" : "decrypt")"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if !selectedFiles.contains(url) {
                    selectedFiles.append(url)
                }
            }
            
            // Save bookmarks for sandbox access
            Task {
                for url in panel.urls {
                    await bookmarkManager.saveBookmark(for: url)
                }
            }
        }
    }
    
    private func removeFile(_ url: URL) {
        selectedFiles.removeAll { $0 == url }
    }
    
    private func processFiles() {
        if operationMode == .decrypt {
            showPassphraseSheet = true
        } else {
            Task {
                await encryptFiles()
            }
        }
    }
    
    private func encryptFiles() async {
        isProcessing = true
        processingProgress = 0
        let totalFiles = Double(selectedFiles.count)
        var completedFiles = 0.0
        
        for sourceURL in selectedFiles {
            currentProcessingFile = sourceURL.lastPathComponent
            
            // Start accessing security-scoped resource
            let hasAccess = await bookmarkManager.startAccessing(url: sourceURL)
            
            defer {
                if hasAccess {
                    Task { await bookmarkManager.stopAccessing(url: sourceURL) }
                }
            }
            
            let destinationURL = sourceURL.deletingLastPathComponent()
                .appendingPathComponent(sourceURL.lastPathComponent + ".gpg")
            
            do {
                _ = try await viewModel.encryptFile(sourceURL: sourceURL, destinationURL: destinationURL)
                completedFiles += 1
                processingProgress = completedFiles / totalFiles
            } catch {
                // Error is handled by viewModel.errorMessage
            }
        }
        
        isProcessing = false
        currentProcessingFile = nil
        
        if viewModel.errorMessage == nil {
            successMessage = "file_encryption_complete \(Int(completedFiles))"
            showSuccessMessage = true
            selectedFiles.removeAll()
        }
    }
    
    func decryptFiles(passphrase: String) async {
        isProcessing = true
        processingProgress = 0
        let totalFiles = Double(selectedFiles.count)
        var completedFiles = 0.0
        
        for sourceURL in selectedFiles {
            currentProcessingFile = sourceURL.lastPathComponent
            
            // Start accessing security-scoped resource
            let hasAccess = await bookmarkManager.startAccessing(url: sourceURL)
            
            defer {
                if hasAccess {
                    Task { await bookmarkManager.stopAccessing(url: sourceURL) }
                }
            }
            
            // Remove .gpg extension for output
            let destName = sourceURL.lastPathComponent.hasSuffix(".gpg") 
                ? String(sourceURL.lastPathComponent.dropLast(4))
                : sourceURL.lastPathComponent + ".decrypted"
            let destinationURL = sourceURL.deletingLastPathComponent()
                .appendingPathComponent(destName)
            
            do {
                _ = try await viewModel.decryptFile(sourceURL: sourceURL, destinationURL: destinationURL, passphrase: passphrase)
                completedFiles += 1
                processingProgress = completedFiles / totalFiles
            } catch {
                // Error is handled by viewModel.errorMessage
            }
        }
        
        isProcessing = false
        currentProcessingFile = nil
        
        if viewModel.errorMessage == nil {
            successMessage = "file_decryption_complete \(Int(completedFiles))"
            showSuccessMessage = true
            selectedFiles.removeAll()
        }
    }
}

// MARK: - File Operation Mode

enum FileOperationMode {
    case encrypt
    case decrypt
}

#Preview("Text Encryption") {
    EncryptionView()
        .frame(width: 1000, height: 700)
}

#Preview("Empty Output") {
    EmptyOutputView()
        .frame(width: 400, height: 400)
}
