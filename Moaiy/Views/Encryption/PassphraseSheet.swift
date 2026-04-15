//
//  PassphraseSheet.swift
//  Moaiy
//
//  Passphrase input sheet for decryption operations
//

import SwiftUI

struct CredentialInputSheet<SubtitleContent: View, InputContent: View>: View {
    let titleKey: LocalizedStringKey
    let confirmButtonKey: LocalizedStringKey
    let isConfirmDisabled: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let subtitleContent: SubtitleContent
    private let inputContent: InputContent
    private let contextContent: AnyView?
    private let helperContent: AnyView?
    private let errorContent: AnyView?

    init(
        titleKey: LocalizedStringKey,
        confirmButtonKey: LocalizedStringKey,
        isConfirmDisabled: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder subtitle: () -> SubtitleContent,
        @ViewBuilder input: () -> InputContent,
        context: AnyView? = nil,
        helper: AnyView? = nil,
        error: AnyView? = nil
    ) {
        self.titleKey = titleKey
        self.confirmButtonKey = confirmButtonKey
        self.isConfirmDisabled = isConfirmDisabled
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.subtitleContent = subtitle()
        self.inputContent = input()
        self.contextContent = context
        self.helperContent = helper
        self.errorContent = error
    }

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xxl) {
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: MoaiyUI.IconSize.closeButton))
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: MoaiyUI.Spacing.sm) {
                Image(systemName: "lock.shield")
                    .font(.system(size: MoaiyUI.IconSize.sheetHero))
                    .foregroundStyle(Color.moaiyAccentV2)

                Text(titleKey)
                    .font(MoaiyUI.Typography.sheetTitle)
                    .foregroundStyle(Color.moaiyTextPrimary)

                subtitleContent
            }

            if let contextContent {
                contextContent
            }

            inputContent

            if let helperContent {
                helperContent
            }

            if let errorContent {
                errorContent
            }

            HStack(spacing: MoaiyUI.Spacing.lg) {
                Button("action_cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button(confirmButtonKey) {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .disabled(isConfirmDisabled)
                .keyboardShortcut(.return, modifiers: [])
            }
            .font(MoaiyUI.Typography.button)
        }
        .padding(MoaiyUI.Spacing.xxxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 360, idealWidth: 420, maxWidth: 520)
    }
}

struct PassphraseSheet: View {
    let keyName: String?
    var allowsEmptyPassphrase = false
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var passphrase = ""
    @State private var showError = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        CredentialInputSheet(
            titleKey: "passphrase_title",
            confirmButtonKey: "action_confirm",
            isConfirmDisabled: !allowsEmptyPassphrase && passphrase.isEmpty,
            onConfirm: submitPassphrase,
            onCancel: onCancel,
            subtitle: {
                subtitleView
            },
            input: {
                passphraseField
            },
            helper: allowsEmptyPassphrase ? AnyView(optionalHintView) : nil,
            error: showError ? AnyView(errorBanner) : nil
        )
        .onAppear {
            isFieldFocused = true
        }
    }

    private var subtitleView: some View {
        Group {
            if let keyName {
                Text(
                    String(
                        format: AppLocalization.string("passphrase_subtitle"),
                        locale: AppLocalization.locale,
                        keyName
                    )
                )
            } else {
                Text("passphrase_subtitle_default")
            }
        }
        .font(MoaiyUI.Typography.sheetSubtitle)
        .foregroundStyle(Color.moaiyTextSecondary)
        .multilineTextAlignment(.center)
    }

    private var passphraseField: some View {
        SecureInputField(
            title: "",
            placeholder: "passphrase_placeholder",
            text: $passphrase
        )
        .focused($isFieldFocused)
        .onSubmit {
            submitPassphrase()
        }
    }

    private var optionalHintView: some View {
        Text("wizard_password_optional")
            .font(MoaiyUI.Typography.caption)
            .foregroundStyle(Color.moaiyTextSecondary)
            .multilineTextAlignment(.center)
    }

    private var errorBanner: some View {
        HStack(spacing: MoaiyUI.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.moaiyError)
            Text("passphrase_error_empty")
                .font(MoaiyUI.Typography.caption)
                .foregroundStyle(Color.moaiyTextPrimary)
        }
        .padding(.horizontal, MoaiyUI.Spacing.md)
        .padding(.vertical, MoaiyUI.Spacing.sm)
        .moaiyBannerStyle(tint: Color.moaiyError)
    }

    private func submitPassphrase() {
        guard allowsEmptyPassphrase || !passphrase.isEmpty else {
            showError = true
            return
        }

        onConfirm(passphrase)
    }
}

#Preview {
    PassphraseSheet(
        keyName: "work@example.com",
        onConfirm: { _ in },
        onCancel: { }
    )
}
