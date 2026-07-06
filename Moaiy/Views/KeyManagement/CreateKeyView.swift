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
    @State private var promptAlert: PromptAlertContent?
    @State private var selectedDefaultKeyType: PersistedDefaultKeyType = .rsa4096
    @State private var gpgService = GPGService.shared

    var body: some View {
        VStack(spacing: 16) {
            headerView

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)

            if !isCreating && !showSuccess {
                footerView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .moaiyModalAdaptiveSize(minWidth: 500, idealWidth: 580, maxWidth: 720, minHeight: 520, idealHeight: 640)
        .moaiyPromptAlertHost(alert: $promptAlert)
        .onAppear {
            syncSelectedKeyTypeFromDefaults()
        }
        .onChange(of: defaultKeyTypeSetting) { _, _ in
            syncSelectedKeyTypeFromDefaults()
        }
        .onChange(of: gpgService.capabilities.supportsKyber) { _, _ in
            syncSelectedKeyTypeFromDefaults()
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
        VStack(alignment: .leading, spacing: 20) {
            Text("wizard_basic_info_description")
                .font(.body)
                .foregroundStyle(.secondary)

            Form {
                Section {
                    TextField(AppLocalization.string("field_key_name"), text: $name)
                        .textContentType(.name)

                    TextField(AppLocalization.string("field_email"), text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()

                    Picker("create_key_type_label", selection: $selectedDefaultKeyType) {
                        ForEach(selectableDefaultKeyTypes) { option in
                            Text(LocalizedStringKey(option.displayKey))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text(LocalizedStringKey(keyTypeFooterKey))
                        .foregroundStyle(isSavedPostQuantumDefaultUnavailable ? Color.moaiyWarning : .secondary)
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
        selectedDefaultKeyType.keyType
    }

    private var persistedDefaultKeyType: PersistedDefaultKeyType {
        PersistedDefaultKeyType.resolved(rawValue: defaultKeyTypeSetting)
    }

    private var supportsPostQuantumKeyType: Bool {
        gpgService.capabilities.supportsKyber
    }

    private var selectableDefaultKeyTypes: [PersistedDefaultKeyType] {
        PersistedDefaultKeyType.selectable(supportsPostQuantum: supportsPostQuantumKeyType)
    }

    private var selectedKeyTypeIsSupported: Bool {
        selectedDefaultKeyType != .postQuantumHybrid || supportsPostQuantumKeyType
    }

    private var isSavedPostQuantumDefaultUnavailable: Bool {
        persistedDefaultKeyType == .postQuantumHybrid && !supportsPostQuantumKeyType
    }

    private var keyTypeFooterKey: String {
        if selectedDefaultKeyType == .postQuantumHybrid {
            return "create_key_pqc_compatibility_note"
        }

        if isSavedPostQuantumDefaultUnavailable {
            return "create_key_pqc_unavailable_note"
        }

        return "create_key_default_type_hint"
    }

    private var canCreate: Bool {
        guard selectedKeyTypeIsSupported else {
            return false
        }

        guard !name.isEmpty, !email.isEmpty, isValidEmail(email) else {
            return false
        }

        if password.isEmpty && confirmPassword.isEmpty {
            return true
        }
        return !password.isEmpty && password == confirmPassword
    }

    private var contentAlignment: Alignment {
        (isCreating || showSuccess) ? .center : .topLeading
    }

    private func handleCreateButtonTapped() {
        guard canCreate else {
            return
        }

        errorMessage = nil
        if password.isEmpty {
            promptAlert = PromptAlertContent.destructiveConfirmation(
                title: "create_key_empty_passphrase_title",
                message: AppLocalization.string("create_key_empty_passphrase_message"),
                confirmTitle: "create_key_empty_passphrase_confirm",
                onConfirm: { createKey() }
            )
            return
        }
        createKey()
    }

    private func createKey() {
        guard selectedKeyTypeIsSupported else {
            errorMessage = AppLocalization.string("create_key_pqc_unavailable_note")
            return
        }

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
                errorMessage = UserFacingErrorMapper.message(for: error, context: .general)
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailPattern, options: .regularExpression) != nil
    }

    private func syncSelectedKeyTypeFromDefaults() {
        if selectableDefaultKeyTypes.contains(persistedDefaultKeyType) {
            selectedDefaultKeyType = persistedDefaultKeyType
        } else {
            selectedDefaultKeyType = .rsa4096
        }
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

                Text(fingerprint.formattedFingerprint())
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

}

#Preview {
    CreateKeyView()
}
