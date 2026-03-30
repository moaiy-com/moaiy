//
//  PassphraseSheet.swift
//  Moaiy
//
//  Passphrase input sheet for decryption operations
//

import SwiftUI

struct PassphraseSheet: View {
    let keyName: String?
    var allowsEmptyPassphrase = false
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var passphrase = ""
    @State private var showError = false
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

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
                    Text(
                        String(
                            format: String(localized: "passphrase_subtitle"),
                            locale: Locale.current,
                            keyName
                        )
                    )
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
                if allowsEmptyPassphrase || !passphrase.isEmpty {
                    onConfirm(passphrase)
                } else {
                    showError = true
                }
            }

            if allowsEmptyPassphrase {
                Text("wizard_password_optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                    if !allowsEmptyPassphrase && passphrase.isEmpty {
                        showError = true
                    } else {
                        onConfirm(passphrase)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allowsEmptyPassphrase && passphrase.isEmpty)
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
