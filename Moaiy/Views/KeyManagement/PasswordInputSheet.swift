//
//  PasswordInputSheet.swift
//  Moaiy
//
//  Sheet for password input when decrypting files
//

import SwiftUI

struct PasswordInputSheet: View {
    let fileName: String
    var allowsEmptyPassword = false
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var password = ""
    @State private var showError = false
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        CredentialInputSheet(
            titleKey: allowsEmptyPassword ? "passphrase_title" : "password_required_title",
            confirmButtonKey: "decrypt_button",
            isConfirmDisabled: !allowsEmptyPassword && password.isEmpty,
            onConfirm: submitPassword,
            onCancel: onCancel,
            subtitle: {
                Text(allowsEmptyPassword ? "passphrase_subtitle_default" : "password_required_description")
                    .font(MoaiyUI.Typography.sheetBody)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .multilineTextAlignment(.center)
            },
            input: {
                passwordField
            },
            context: AnyView(fileInfoView),
            helper: allowsEmptyPassword ? AnyView(optionalHintView) : nil,
            error: showError ? AnyView(errorBanner) : nil
        )
        .onAppear {
            isPasswordFocused = true
        }
    }

    private var optionalHintView: some View {
        Text("wizard_password_optional")
            .font(MoaiyUI.Typography.caption)
            .foregroundStyle(Color.moaiyTextSecondary)
            .multilineTextAlignment(.center)
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
        guard allowsEmptyPassword || !password.isEmpty else {
            withAnimation {
                showError = true
            }
            return
        }

        onConfirm(password)
    }
}

struct YubiKeyPINSheet: View {
    let fileName: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var showError = false
    @FocusState private var isPINFocused: Bool

    var body: some View {
        CredentialInputSheet(
            titleKey: "yubikey_pin_title",
            confirmButtonKey: "action_confirm",
            isConfirmDisabled: pin.isEmpty,
            onConfirm: submitPIN,
            onCancel: onCancel,
            subtitle: {
                Text("yubikey_pin_subtitle")
                    .font(MoaiyUI.Typography.sheetBody)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .multilineTextAlignment(.center)
            },
            input: {
                pinInputField
            },
            context: AnyView(fileInfoView),
            error: showError ? AnyView(errorBanner) : nil
        )
        .onAppear {
            isPINFocused = true
        }
    }

    private var fileInfoView: some View {
        HStack {
            Image(systemName: "memorychip.fill")
                .foregroundStyle(Color.moaiyWarning)

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

    private var pinInputField: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
            Text("yubikey_pin_field_label")
                .font(MoaiyUI.Typography.fieldLabel)
                .foregroundStyle(Color.moaiyTextSecondary)

            SecureField("yubikey_pin_placeholder", text: $pin)
                .textFieldStyle(.roundedBorder)
                .focused($isPINFocused)
                .onSubmit {
                    submitPIN()
                }
        }
    }

    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.moaiyWarning)

            Text("yubikey_pin_empty_error")
                .font(MoaiyUI.Typography.caption)
                .foregroundStyle(Color.moaiyTextPrimary)
        }
        .padding(.horizontal, MoaiyUI.Spacing.md)
        .padding(.vertical, MoaiyUI.Spacing.sm)
        .moaiyBannerStyle(tint: Color.moaiyWarning)
        .transition(.opacity)
    }

    private func submitPIN() {
        guard !pin.isEmpty else {
            withAnimation {
                showError = true
            }
            return
        }

        onConfirm(pin)
    }
}

#Preview {
    PasswordInputSheet(
        fileName: "secret_document.pdf.gpg",
        onConfirm: { _ in },
        onCancel: {}
    )
}
