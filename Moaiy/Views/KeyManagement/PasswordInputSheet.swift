//
//  PasswordInputSheet.swift
//  Moaiy
//
//  Sheet for password input when decrypting files
//

import SwiftUI

struct PasswordInputSheet: View {
    let fileName: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var password = ""
    @State private var showError = false
    @FocusState private var isPasswordFocused: Bool
    
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
            headerView
            fileInfoView
            passwordField
            errorView
            buttonsView
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 360, idealWidth: 420, maxWidth: 520)
        .onAppear {
            isPasswordFocused = true
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(Color.moaiyAccentV2)
            
            Text("password_required_title")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.moaiyTextPrimary)
            
            Text("password_required_description")
                .font(.body)
                .foregroundStyle(Color.moaiyTextSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var fileInfoView: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.moaiyTextSecondary)
            
            Text(fileName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Image(systemName: "arrow.right")
                .foregroundStyle(Color.moaiyTextSecondary.opacity(0.75))
            
            Image(systemName: "lock.open.fill")
                .foregroundStyle(Color.moaiySuccess)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: Color.moaiyInfo)
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("password_field_label")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)
            
            SecureField("password_field_placeholder", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isPasswordFocused)
                .onSubmit {
                    if !password.isEmpty {
                        onConfirm(password)
                    } else {
                        showError = true
                    }
                }
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        if showError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.moaiyWarning)
                
                Text("password_empty_error")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextPrimary)
            }
            .padding(.horizontal, MoaiyUI.Spacing.md)
            .padding(.vertical, MoaiyUI.Spacing.sm)
            .moaiyBannerStyle(tint: Color.moaiyWarning)
            .transition(.opacity)
        }
    }
    
    private var buttonsView: some View {
        HStack(spacing: 12) {
            Button("action_cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
            
            Button("decrypt_button") {
                if password.isEmpty {
                    withAnimation {
                        showError = true
                    }
                } else {
                    onConfirm(password)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
            .disabled(password.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}

#Preview {
    PasswordInputSheet(
        fileName: "secret_document.pdf.gpg",
        onConfirm: { _ in },
        onCancel: {}
    )
}
