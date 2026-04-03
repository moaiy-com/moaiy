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
        VStack(spacing: MoaiyUI.Spacing.xxl) {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            // Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(Color.moaiyAccentV2)
            
            // Title
            VStack(spacing: 8) {
                Text("passphrase_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.moaiyTextPrimary)
                
                if let keyName = keyName {
                    Text(
                        String(
                            format: String(localized: "passphrase_subtitle"),
                            locale: Locale.current,
                            keyName
                        )
                    )
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("passphrase_subtitle_default")
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
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
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if showError {
                HStack(spacing: MoaiyUI.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.moaiyError)
                    Text("passphrase_error_empty")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
                .padding(.horizontal, MoaiyUI.Spacing.md)
                .padding(.vertical, MoaiyUI.Spacing.sm)
                .moaiyBannerStyle(tint: Color.moaiyError)
            }
            
            // Buttons
            HStack(spacing: MoaiyUI.Spacing.lg) {
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
                .tint(Color.moaiyAccentV2)
                .disabled(!allowsEmptyPassphrase && passphrase.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(MoaiyUI.Spacing.xxxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 360, idealWidth: 420, maxWidth: 520)
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
