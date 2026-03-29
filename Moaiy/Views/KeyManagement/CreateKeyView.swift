//
//  CreateKeyView.swift
//  Moaiy
//
//  Create new key flow (single page)
//

import SwiftUI

struct CreateKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel

    @AppStorage("defaultKeyType") private var defaultKeyTypeSetting = 0

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var createdKeyFingerprint: String?
    @State private var showNoPasswordConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            Group {
                if isCreating {
                    CreatingKeyView()
                } else if showSuccess {
                    SuccessView(fingerprint: createdKeyFingerprint ?? "") {
                        dismiss()
                    }
                } else {
                    contentView
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isCreating && !showSuccess {
                Divider()
                footerView
                    .padding(16)
            }
        }
        .frame(width: 560, height: 620)
        .alert("create_key_empty_passphrase_title", isPresented: $showNoPasswordConfirmation) {
            Button("create_key_empty_passphrase_confirm", role: .destructive) {
                createKey()
            }
            Button("action_cancel", role: .cancel) { }
        } message: {
            Text("create_key_empty_passphrase_message")
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("wizard_create_key_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("wizard_create_key_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isCreating)
        }
        .padding(16)
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("wizard_basic_info_description")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Form {
                    Section {
                        TextField(String(localized: "field_key_name"), text: $name)
                            .textContentType(.name)

                        TextField(String(localized: "field_email"), text: $email)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()

                        HStack {
                            Text("setting_default_key_type")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedKeyType.rawValue)
                                .fontWeight(.medium)
                        }
                    } footer: {
                        Text("create_key_default_type_hint")
                    }

                    Section {
                        SecureField("field_password", text: $password)
                        SecureField("field_confirm_password", text: $confirmPassword)
                    } footer: {
                        if !password.isEmpty && password != confirmPassword {
                            Text("error_password_mismatch")
                                .foregroundStyle(.red)
                        } else if password.isEmpty {
                            Text("wizard_password_optional")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)

                VStack(alignment: .leading, spacing: 10) {
                    Label("create_key_passphrase_tips_title", systemImage: "shield.lefthalf.filled")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Label("create_key_passphrase_tip_strong", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("create_key_passphrase_tip_manager", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("create_key_passphrase_tip_recovery", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let error = errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            Button("action_cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("action_create_key") {
                handleCreateButtonTapped()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCreate || isCreating)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var selectedKeyType: KeyType {
        switch defaultKeyTypeSetting {
        case 1:
            return .rsa2048
        case 2:
            return .ecc
        default:
            return .rsa4096
        }
    }

    private var canCreate: Bool {
        guard !name.isEmpty, !email.isEmpty, isValidEmail(email) else {
            return false
        }

        if password.isEmpty && confirmPassword.isEmpty {
            return true
        }
        return !password.isEmpty && password == confirmPassword
    }

    private func handleCreateButtonTapped() {
        errorMessage = nil
        if password.isEmpty {
            showNoPasswordConfirmation = true
            return
        }
        createKey()
    }

    private func createKey() {
        isCreating = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let passphrase = password.isEmpty ? nil : password
                let fingerprint = try await viewModel.generateKey(
                    name: name,
                    email: email,
                    keyType: selectedKeyType,
                    passphrase: passphrase
                )

                createdKeyFingerprint = fingerprint
                isCreating = false
                withAnimation {
                    showSuccess = true
                }
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailPattern, options: .regularExpression) != nil
    }
}

// MARK: - Creating Key View

struct CreatingKeyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("wizard_creating_key")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("wizard_creating_key_description")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Success View

struct SuccessView: View {
    let fingerprint: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("wizard_key_created")
                .font(.title2)
                .fontWeight(.semibold)

            Text("wizard_key_created_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("wizard_fingerprint")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatFingerprint(fingerprint))
                    .font(.system(.caption, design: .monospaced))
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button("action_done") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func formatFingerprint(_ fp: String) -> String {
        var result = ""
        for (index, char) in fp.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}

#Preview {
    CreateKeyView()
}
