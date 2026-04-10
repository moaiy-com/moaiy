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
        CredentialInputSheet(
            titleKey: "password_required_title",
            confirmButtonKey: "decrypt_button",
            isConfirmDisabled: password.isEmpty,
            onConfirm: submitPassword,
            onCancel: onCancel,
            subtitle: {
                Text("password_required_description")
                    .font(MoaiyUI.Typography.sheetBody)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .multilineTextAlignment(.center)
            },
            input: {
                passwordField
            },
            context: AnyView(fileInfoView),
            error: showError ? AnyView(errorBanner) : nil
        )
        .onAppear {
            isPasswordFocused = true
        }
    }
    
    private var fileInfoView: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.moaiyTextSecondary)
            
            Text(fileName)
                .font(MoaiyUI.Typography.sheetBody)
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
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
            Text("password_field_label")
                .font(MoaiyUI.Typography.fieldLabel)
                .foregroundStyle(Color.moaiyTextSecondary)
            
            SecureField("password_field_placeholder", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isPasswordFocused)
                .onSubmit {
                    submitPassword()
                }
        }
    }
    
    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.moaiyWarning)
            
            Text("password_empty_error")
                .font(MoaiyUI.Typography.caption)
                .foregroundStyle(Color.moaiyTextPrimary)
        }
        .padding(.horizontal, MoaiyUI.Spacing.md)
        .padding(.vertical, MoaiyUI.Spacing.sm)
        .moaiyBannerStyle(tint: Color.moaiyWarning)
        .transition(.opacity)
    }

    private func submitPassword() {
        guard !password.isEmpty else {
            withAnimation {
                showError = true
            }
            return
        }

        onConfirm(password)
    }
}

#Preview {
    PasswordInputSheet(
        fileName: "secret_document.pdf.gpg",
        onConfirm: { _ in },
        onCancel: {}
    )
}
