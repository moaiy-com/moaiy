//
//  KeyEditSheet.swift
//  Moaiy
//
//  Key editing interface for modifying key properties
//

import SwiftUI

enum KeyEditTab: String, CaseIterable {
    case expiration = "Expiration"
    case userIds = "User IDs"
    case passphrase = "Passphrase"

    var titleKey: LocalizedStringKey {
        switch self {
        case .expiration: return "edit_select_expiration"
        case .userIds: return "edit_current_userids"
        case .passphrase: return "edit_new_passphrase"
        }
    }

    var icon: String {
        switch self {
        case .expiration: return "clock.fill"
        case .userIds: return "person.fill"
        case .passphrase: return "lock.fill"
        }
    }
}

struct KeyEditSheet: View {
    let key: GPGKey
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: KeyEditTab = .expiration
    @State private var promptAlert: PromptAlertContent?

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("edit_key_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(KeyEditTab.allCases, id: \.self) { tab in
                    Label(tab.titleKey, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .moaiyModalCard(cornerRadius: 10)
            .padding(.horizontal, 24)

            // Tab content
            Group {
                switch selectedTab {
                case .expiration:
                    ExpirationEditView(key: key, onSuccess: { message in
                        promptAlert = PromptAlertContent.success(
                            message: message,
                            onAcknowledge: { dismiss() }
                        )
                    })
                case .userIds:
                    UserIDsEditView(key: key, onSuccess: { message in
                        promptAlert = PromptAlertContent.success(
                            message: message,
                            onAcknowledge: { dismiss() }
                        )
                    })
                case .passphrase:
                    PassphraseEditView(key: key, onSuccess: { message in
                        promptAlert = PromptAlertContent.success(
                            message: message,
                            onAcknowledge: { dismiss() }
                        )
                    })
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 520, idealWidth: 620, maxWidth: 760, minHeight: 500, idealHeight: 620, maxHeight: 860)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }
}

// MARK: - Expiration Edit View

struct ExpirationEditView: View {
    let key: GPGKey
    let onSuccess: (String) -> Void
    @Environment(KeyManagementViewModel.self) private var viewModel

    @State private var expirationOption: ExpirationOption = .never
    @State private var customDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var passphrase = ""
    @State private var isUpdating = false
    @State private var promptAlert: PromptAlertContent?

    enum ExpirationOption: CaseIterable {
        case never
        case oneYear
        case twoYears
        case fiveYears
        case custom

        var titleKey: LocalizedStringKey {
            switch self {
            case .never:
                return "edit_expiration_never"
            case .oneYear:
                return "edit_expiration_one_year"
            case .twoYears:
                return "edit_expiration_two_years"
            case .fiveYears:
                return "edit_expiration_five_years"
            case .custom:
                return "edit_expiration_custom_date"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("edit_expiration_description")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)

            // Current expiration
            if let expiresAt = key.expiresAt {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.moaiyInfo)
                    Text("edit_current_expiration")
                        .font(.subheadline)
                    Spacer()
                    Text(expiresAt.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(MoaiyUI.Spacing.md)
                .moaiyBannerStyle(tint: Color.moaiyInfo)
            }

            // Expiration options
            VStack(alignment: .leading, spacing: 12) {
                Text("edit_select_expiration")
                    .font(.headline)

                ForEach(ExpirationOption.allCases, id: \.self) { option in
                    Button(action: { expirationOption = option }) {
                        HStack {
                            Image(systemName: expirationOption == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(expirationOption == option ? Color.moaiyAccentV2 : Color.moaiyTextSecondary)

                            Text(option.titleKey)
                                .font(.subheadline)
                                .foregroundStyle(Color.moaiyTextPrimary)

                            Spacer()

                            if option == .custom {
                                Text(customDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            if expirationOption == .custom {
                DatePicker(
                    "edit_custom_date",
                    selection: $customDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("edit_current_passphrase")
                    .font(.subheadline)
                SecureField("edit_passphrase_placeholder", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            // Action button
            Button(action: updateExpiration) {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("action_apply")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
            .controlSize(.large)
            .disabled(isUpdating)
        }
        .padding(MoaiyUI.Spacing.xxl)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private func updateExpiration() {
        isUpdating = true

        Task { @MainActor in
            let expirationDate: Date?
            switch expirationOption {
            case .never:
                expirationDate = nil
            case .oneYear:
                expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
            case .twoYears:
                expirationDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())
            case .fiveYears:
                expirationDate = Calendar.current.date(byAdding: .year, value: 5, to: Date())
            case .custom:
                expirationDate = customDate
            }

            do {
                try await viewModel.updateKeyExpiration(
                    for: key,
                    expiresAt: expirationDate,
                    passphrase: passphrase.isEmpty ? nil : passphrase
                )
                passphrase = ""
                onSuccess(String(localized: "edit_expiration_success"))
            } catch {
                promptAlert = PromptAlertContent.failure(
                    context: .keyEdit,
                    error: error
                )
            }
            isUpdating = false
        }
    }
}

// MARK: - User IDs Edit View

struct UserIDsEditView: View {
    let key: GPGKey
    let onSuccess: (String) -> Void
    @Environment(KeyManagementViewModel.self) private var viewModel

    @State private var newUserName = ""
    @State private var newUserEmail = ""
    @State private var passphrase = ""
    @State private var isAdding = false
    @State private var promptAlert: PromptAlertContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("edit_userids_description")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)

            // Current user IDs
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_current_userids")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(key.email)
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }

                    Spacer()

                    Text("primary")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.moaiyAccentV2.opacity(0.16))
                        .foregroundStyle(Color.moaiyAccentV2)
                        .clipShape(Capsule())
                }
                .padding(MoaiyUI.Spacing.md)
                .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.md)
            }

            // Add new user ID
            VStack(alignment: .leading, spacing: 12) {
                Text("edit_add_userid")
                    .font(.headline)

                TextField("edit_name_placeholder", text: $newUserName)
                    .textFieldStyle(.roundedBorder)

                TextField("edit_email_placeholder", text: $newUserEmail)
                    .textFieldStyle(.roundedBorder)

                SecureField("edit_passphrase_placeholder", text: $passphrase)
                    .textFieldStyle(.roundedBorder)

                Button(action: addUserID) {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("action_add")
                    }
                }
                .buttonStyle(.bordered)
                .tint(Color.moaiyAccentV2)
                .disabled(newUserName.isEmpty || newUserEmail.isEmpty || isAdding)
            }

            Spacer()

            // Info text
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.moaiyInfo)

                Text("edit_userid_info")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
            }
            .padding(MoaiyUI.Spacing.md)
            .moaiyBannerStyle(tint: Color.moaiyInfo)
        }
        .padding(MoaiyUI.Spacing.xxl)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private func addUserID() {
        isAdding = true

        Task { @MainActor in
            do {
                try await viewModel.addUserID(
                    to: key,
                    name: newUserName,
                    email: newUserEmail,
                    passphrase: passphrase.isEmpty ? nil : passphrase
                )
                newUserName = ""
                newUserEmail = ""
                passphrase = ""
                onSuccess(String(localized: "edit_userid_success"))
            } catch {
                promptAlert = PromptAlertContent.failure(
                    context: .keyEdit,
                    error: error
                )
            }
            isAdding = false
        }
    }
}

// MARK: - Passphrase Edit View

struct PassphraseEditView: View {
    let key: GPGKey
    let onSuccess: (String) -> Void
    @Environment(KeyManagementViewModel.self) private var viewModel

    @State private var currentPassphrase = ""
    @State private var newPassphrase = ""
    @State private var confirmPassphrase = ""
    @State private var isUpdating = false
    @State private var promptAlert: PromptAlertContent?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("edit_passphrase_description")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)

            // Current passphrase
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_current_passphrase")
                    .font(.headline)

                SecureField("edit_passphrase_placeholder", text: $currentPassphrase)
                    .textFieldStyle(.roundedBorder)
            }

            // New passphrase
            VStack(alignment: .leading, spacing: 8) {
                Text("edit_new_passphrase")
                    .font(.headline)

                SecureField("edit_new_passphrase_placeholder", text: $newPassphrase)
                    .textFieldStyle(.roundedBorder)

                SecureField("edit_confirm_passphrase_placeholder", text: $confirmPassphrase)
                    .textFieldStyle(.roundedBorder)

                if !newPassphrase.isEmpty && newPassphrase != confirmPassphrase {
                    Text("edit_passphrase_mismatch")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyError)
                }
            }

            Spacer()

            // Action button
            Button(action: updatePassphrase) {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("action_save")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
            .controlSize(.large)
            .disabled(newPassphrase.isEmpty || newPassphrase != confirmPassphrase || isUpdating)
        }
        .padding(MoaiyUI.Spacing.xxl)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private func updatePassphrase() {
        isUpdating = true

        Task { @MainActor in
            do {
                try await viewModel.changePassphrase(
                    for: key,
                    oldPassphrase: currentPassphrase,
                    newPassphrase: newPassphrase,
                    allowEmptyOldPassphrase: true
                )
                currentPassphrase = ""
                newPassphrase = ""
                confirmPassphrase = ""
                onSuccess(String(localized: "edit_passphrase_success"))
            } catch {
                promptAlert = PromptAlertContent.failure(
                    context: .keyEdit,
                    error: error
                )
            }
            isUpdating = false
        }
    }
}

// MARK: - Preview

#Preview("Key Edit") {
    KeyEditSheet(key: GPGKey(
        id: "1",
        keyID: "ABC12345",
        fingerprint: "1234567890ABCDEF1234567890ABCDEF12345678",
        name: "Test User",
        email: "test@example.com",
        algorithm: "RSA",
        keyLength: 4096,
        isSecret: true,
        createdAt: Date(),
        expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
        trustLevel: .ultimate
    ))
    .environment(KeyManagementViewModel())
}
