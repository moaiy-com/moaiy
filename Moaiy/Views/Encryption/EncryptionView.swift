//
//  EncryptionView.swift
//  Moaiy
//
//  Encryption and decryption view
//

import SwiftUI

struct EncryptionView: View {
    @State private var selectedTab = 0
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var selectedRecipients: Set<String> = []
    
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
            if selectedTab == 0 {
                TextEncryptionView(
                    inputText: $inputText,
                    outputText: $outputText,
                    selectedRecipients: $selectedRecipients
                )
            } else {
                FileEncryptionView()
            }
        }
        .navigationTitle("section_encryption")
    }
}

// MARK: - Text Encryption View
struct TextEncryptionView: View {
    @Binding var inputText: String
    @Binding var outputText: String
    @Binding var selectedRecipients: Set<String>
    
    var body: some View {
        HStack(spacing: 16) {
            // Input
            VStack(alignment: .leading, spacing: 8) {
                Text("label_input")
                    .font(.headline)
                
                TextEditor(text: $inputText)
                    .font(.body)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(height: 200)
            }
            
            // Controls
            VStack(spacing: 12) {
                Button(action: encrypt) {
                    Image(systemName: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(inputText.isEmpty)
                
                Button(action: decrypt) {
                    Image(systemName: "arrow.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(outputText.isEmpty)
            }
            
            // Output
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("label_output")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !outputText.isEmpty {
                        Button(action: copyOutput) {
                            Label("action_copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                
                TextEditor(text: .constant(outputText))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .frame(height: 200)
                    .disabled(true)
            }
        }
        .padding()
    }
    
    private func encrypt() {
        // TODO: Implement encryption
        outputText = "-----BEGIN PGP MESSAGE-----\n\nEncrypted content will appear here...\n\n-----END PGP MESSAGE-----"
    }
    
    private func decrypt() {
        // TODO: Implement decryption
        inputText = "Decrypted content will appear here..."
    }
    
    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }
}

// MARK: - File Encryption View
struct FileEncryptionView: View {
    @State private var isTargeted = false
    
    
    var body: some View {
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
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(isTargeted ? Color.moiayAccent : .secondary)
                    
                    Text("drop_zone_title")
                        .font(.headline)
                    
                    Text("drop_zone_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 500, maxHeight: 300)
            .background(isTargeted ? Color.moiayAccent.opacity(0.05) : Color.clear)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                // TODO: Handle file drop
                return true
            }
            
            // Or select button
            Button("action_select_files") { }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    EncryptionView()
        .frame(width: 900, height: 600)
}
