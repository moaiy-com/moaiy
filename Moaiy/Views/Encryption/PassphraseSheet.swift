//
//  PassphraseSheet.swift
//  Moaiy
//
//  Passphrase input sheet for decryption operations
//

import SwiftUI

struct PassphraseSheet: View {
    let keyName: String?
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var passphrase = ""
    @State private var showError = false
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(Color.moaiyAccent)
            
            // Title
            VStack(spacing: 8) {
                Text("passphrase_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let keyName = keyName {
                    Text("passphrase_subtitle \(keyName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("passphrase_subtitle_default")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Input
            SecureInputField(
                title: "",
                placeholder: "passphrase_placeholder",
                text: $passphrase
            )
            .focused($isFieldFocused)
            .onSubmit {
                if !passphrase.isEmpty {
                    onConfirm(passphrase)
                }
            }
            
            if showError {
                Text("passphrase_error_empty")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Buttons
            HStack(spacing: 16) {
                Button("action_cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("action_confirm") {
                    if passphrase.isEmpty {
                        showError = true
                    } else {
                        onConfirm(passphrase)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(passphrase.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(32)
        .frame(width: 400)
        .onAppear {
            isFieldFocused = true
        }
    }
}

#Preview {
    PassphraseSheet(
        keyName: "work@example.com",
        onConfirm: { _ in },
        onCancel: { }
    )
}
