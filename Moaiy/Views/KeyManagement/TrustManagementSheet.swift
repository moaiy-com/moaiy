//
//  TrustManagementSheet.swift
//  Moaiy
//
//  Trust management interface for keys
//

import SwiftUI

struct TrustManagementSheet: View {
    let key: GPGKey
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTrustLevel: TrustLevel
    @State private var isUpdating = false
    @State private var promptAlert: PromptAlertContent?
    @State private var trustDetails: KeyTrustDetails?
    
    init(key: GPGKey) {
        self.key = key
        _selectedTrustLevel = State(initialValue: key.trustLevel)
    }
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("trust_management_title")
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CurrentTrustCard(key: key, trustDetails: trustDetails)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("trust_select_level")
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(TrustLevel.allCases, id: \.self) { level in
                                TrustLevelRow(
                                    level: level,
                                    isSelected: selectedTrustLevel == level,
                                    action: { selectedTrustLevel = level }
                                )
                            }
                        }
                    }

                    if selectedTrustLevel == .ultimate && key.trustLevel != .ultimate {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.moaiyWarning)

                            Text("trust_ultimate_warning")
                                .font(.caption)
                                .foregroundStyle(Color.moaiyTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(MoaiyUI.Spacing.md)
                        .moaiyBannerStyle(tint: Color.moaiyWarning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: updateTrust) {
                    if isUpdating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("action_save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .disabled(selectedTrustLevel == key.trustLevel || isUpdating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 500, idealWidth: 600, maxWidth: 720, minHeight: 560, idealHeight: 680, maxHeight: 860)
        .task {
            await loadTrustDetails()
        }
        .moaiyPromptAlertHost(alert: $promptAlert)
    }
    
    private func loadTrustDetails() async {
        do {
            trustDetails = try await viewModel.getTrustDetails(for: key)
        } catch {
            // Silently fail, trust details are optional
            print("Failed to load trust details: \(error)")
        }
    }
    
    private func updateTrust() {
        isUpdating = true
        
        Task {
            do {
                try await viewModel.setTrust(for: key, trustLevel: selectedTrustLevel)
                dismiss()
            } catch {
                promptAlert = PromptAlertContent.failure(
                    context: .trust,
                    error: error
                )
            }
            isUpdating = false
        }
    }
}

// MARK: - Current Trust Card

struct CurrentTrustCard: View {
    let key: GPGKey
    let trustDetails: KeyTrustDetails?
    
    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            HStack {
                Image(systemName: trustIcon)
                    .font(.title)
                    .foregroundStyle(trustColor)
                    .frame(width: 40, height: 40)
                    .background(trustColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("trust_current_level")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Text(key.trustLevel.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
                
                Spacer()
            }
            
            if let details = trustDetails {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                    HStack {
                        Text("trust_signatures")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text("\(details.signatureCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    HStack {
                        Text("trust_owner_trust")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text(details.ownerTrust.localizedName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    HStack {
                        Text("trust_calculated_trust")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text(details.calculatedTrust.localizedName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle()
    }
    
    private var trustIcon: String {
        switch key.trustLevel {
        case .ultimate: return "checkmark.seal.fill"
        case .full: return "checkmark.circle.fill"
        case .marginal: return "questionmark.circle.fill"
        case .none: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var trustColor: Color {
        switch key.trustLevel {
        case .ultimate: return Color.moaiySuccess
        case .full: return Color.moaiyInfo
        case .marginal: return Color.moaiyWarning
        case .none: return Color.moaiyError
        case .unknown: return Color.moaiyTextSecondary
        }
    }
}

// MARK: - Trust Level Row

struct TrustLevelRow: View {
    let level: TrustLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    
                    Text(level.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.moaiyAccentV2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? Color.moaiyAccentV2.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.moaiyAccentV2 : Color.moaiyBorderPrimary.opacity(0.8),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var icon: String {
        switch level {
        case .ultimate: return "checkmark.seal.fill"
        case .full: return "checkmark.circle.fill"
        case .marginal: return "questionmark.circle.fill"
        case .none: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var color: Color {
        switch level {
        case .ultimate: return Color.moaiySuccess
        case .full: return Color.moaiyInfo
        case .marginal: return Color.moaiyWarning
        case .none: return Color.moaiyError
        case .unknown: return Color.moaiyTextSecondary
        }
    }
}

// MARK: - Preview

#Preview("Trust Management") {
    TrustManagementSheet(key: GPGKey(
        id: "1",
        keyID: "ABC12345",
        fingerprint: "1234567890ABCDEF1234567890ABCDEF12345678",
        name: "Test User",
        email: "test@example.com",
        algorithm: "RSA",
        keyLength: 4096,
        isSecret: true,
        createdAt: Date(),
        expiresAt: nil,
        trustLevel: .full
    ))
    .environment(KeyManagementViewModel())
}

@MainActor
@Observable
final class SubkeyManagementViewModel {
    private let service: SubkeyManaging

    var subkeys: [GPGSubkey] = []
    var isLoading = false
    var isApplyingChanges = false
    var errorMessage: String?

    init() {
        self.service = GPGService.shared
    }

    init(service: SubkeyManaging) {
        self.service = service
    }

    func loadSubkeys(for key: GPGKey) async {
        guard key.isSecret, !key.isSmartCardStub else {
            subkeys = []
            errorMessage = AppLocalization.string("subkey_error_unavailable")
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            subkeys = try await service.listSubkeys(primaryKeyID: key.fingerprint)
                .sorted { lhs, rhs in
                    (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
                }
        } catch {
            errorMessage = UserFacingErrorMapper.message(for: error, context: .keyEdit)
        }

        isLoading = false
    }

    func addSubkey(
        for key: GPGKey,
        usage: SubkeyUsage,
        expiresAt: Date?,
        passphrase: String?
    ) async throws {
        guard key.isSecret, !key.isSmartCardStub else {
            throw GPGError.keyNotFound(key.fingerprint)
        }
        guard !isApplyingChanges else {
            throw GPGError.operationCancelled
        }

        isApplyingChanges = true
        defer { isApplyingChanges = false }

        try await service.addSubkey(
            primaryKeyID: key.fingerprint,
            usage: usage,
            expiresAt: expiresAt,
            passphrase: passphrase
        )
        await loadSubkeys(for: key)
    }

    func updateSubkeyExpiration(
        for key: GPGKey,
        subkeyFingerprint: String,
        expiresAt: Date?,
        passphrase: String?
    ) async throws {
        guard key.isSecret, !key.isSmartCardStub else {
            throw GPGError.keyNotFound(key.fingerprint)
        }
        guard !isApplyingChanges else {
            throw GPGError.operationCancelled
        }

        isApplyingChanges = true
        defer { isApplyingChanges = false }

        try await service.updateSubkeyExpiration(
            primaryKeyID: key.fingerprint,
            subkeyFingerprint: subkeyFingerprint,
            expiresAt: expiresAt,
            passphrase: passphrase
        )
        await loadSubkeys(for: key)
    }
}

struct SubkeyManagementSheet: View {
    let key: GPGKey
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SubkeyManagementViewModel()
    @State private var selectedUsage: SubkeyUsage = .encrypt
    @State private var newSubkeyExpirationPreset: SubkeyExpirationPreset = .oneYear
    @State private var newSubkeyCustomDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var addSubkeyPassphrase = ""

    @State private var selectedSubkeyFingerprint: String?
    @State private var updateExpirationPreset: SubkeyExpirationPreset = .oneYear
    @State private var updateCustomDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var updatePassphrase = ""

    @State private var promptAlert: PromptAlertContent?

    private var selectedSubkey: GPGSubkey? {
        guard let selectedSubkeyFingerprint else { return nil }
        return viewModel.subkeys.first(where: { $0.fingerprint == selectedSubkeyFingerprint })
    }

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("subkey_management_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                Spacer()

                Button("action_refresh") {
                    Task {
                        await viewModel.loadSubkeys(for: key)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading || viewModel.isApplyingChanges)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("subkey_list_title")
                            .font(.headline)

                        if viewModel.isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("subkey_loading")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                            .padding(MoaiyUI.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .moaiyCardStyle()
                        } else if viewModel.subkeys.isEmpty {
                            Text("subkey_empty_state")
                                .font(.subheadline)
                                .foregroundStyle(Color.moaiyTextSecondary)
                                .padding(MoaiyUI.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .moaiyCardStyle()
                        } else {
                            ForEach(viewModel.subkeys) { subkey in
                                SubkeyRowView(
                                    subkey: subkey,
                                    onEditExpiration: {
                                        selectedSubkeyFingerprint = subkey.fingerprint
                                        updateExpirationPreset = .oneYear
                                        updateCustomDate = subkey.expiresAt ?? (Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
                                    }
                                )
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(Color.moaiyError)
                            .padding(MoaiyUI.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .moaiyBannerStyle(tint: Color.moaiyError)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("subkey_add_title")
                            .font(.headline)

                        Picker("subkey_usage_title", selection: $selectedUsage) {
                            ForEach(SubkeyUsage.allCases) { usage in
                                Text(usage.localizedName)
                                    .tag(usage)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("subkey_expiration_title", selection: $newSubkeyExpirationPreset) {
                            ForEach(SubkeyExpirationPreset.allCases) { preset in
                                Text(LocalizedStringKey(preset.titleKey))
                                    .tag(preset)
                            }
                        }
                        .pickerStyle(.menu)

                        if newSubkeyExpirationPreset == .custom {
                            DatePicker(
                                "subkey_expiration_custom_date",
                                selection: $newSubkeyCustomDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }

                        SecureField("subkey_passphrase_placeholder", text: $addSubkeyPassphrase)
                            .textFieldStyle(.roundedBorder)

                        Button(action: addSubkey) {
                            if viewModel.isApplyingChanges {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("subkey_action_add")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.moaiyAccentV2)
                        .disabled(viewModel.isApplyingChanges)
                    }
                    .padding(MoaiyUI.Spacing.md)
                    .moaiyCardStyle()

                    if let selectedSubkey {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("subkey_update_expiration_title")
                                .font(.headline)

                            Text(String(
                                format: AppLocalization.string("subkey_selected_fingerprint_format"),
                                selectedSubkey.fingerprint
                            ))
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                            .textSelection(.enabled)

                            Picker("subkey_expiration_title", selection: $updateExpirationPreset) {
                                ForEach(SubkeyExpirationPreset.allCases) { preset in
                                    Text(LocalizedStringKey(preset.titleKey))
                                        .tag(preset)
                                }
                            }
                            .pickerStyle(.menu)

                            if updateExpirationPreset == .custom {
                                DatePicker(
                                    "subkey_expiration_custom_date",
                                    selection: $updateCustomDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                            }

                            SecureField("subkey_passphrase_placeholder", text: $updatePassphrase)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 12) {
                                Button("action_cancel") {
                                    selectedSubkeyFingerprint = nil
                                    updatePassphrase = ""
                                }
                                .buttonStyle(.bordered)

                                Button(action: {
                                    updateSubkeyExpiration(for: selectedSubkey)
                                }) {
                                    if viewModel.isApplyingChanges {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("subkey_action_update_expiration")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.moaiyAccentV2)
                                .disabled(viewModel.isApplyingChanges)
                            }
                        }
                        .padding(MoaiyUI.Spacing.md)
                        .moaiyCardStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 600, idealWidth: 760, maxWidth: 980, minHeight: 560, idealHeight: 720, maxHeight: 920)
        .task {
            await viewModel.loadSubkeys(for: key)
        }
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private func addSubkey() {
        Task {
            do {
                try await viewModel.addSubkey(
                    for: key,
                    usage: selectedUsage,
                    expiresAt: newSubkeyExpirationPreset.resolveDate(customDate: newSubkeyCustomDate),
                    passphrase: addSubkeyPassphrase.isEmpty ? nil : addSubkeyPassphrase
                )
                addSubkeyPassphrase = ""
                promptAlert = PromptAlertContent.success(message: AppLocalization.string("subkey_add_success"))
            } catch {
                promptAlert = PromptAlertContent.failure(context: .keyEdit, error: error)
            }
        }
    }

    private func updateSubkeyExpiration(for subkey: GPGSubkey) {
        Task {
            do {
                try await viewModel.updateSubkeyExpiration(
                    for: key,
                    subkeyFingerprint: subkey.fingerprint,
                    expiresAt: updateExpirationPreset.resolveDate(customDate: updateCustomDate),
                    passphrase: updatePassphrase.isEmpty ? nil : updatePassphrase
                )
                selectedSubkeyFingerprint = nil
                updatePassphrase = ""
                promptAlert = PromptAlertContent.success(message: AppLocalization.string("subkey_update_expiration_success"))
            } catch {
                promptAlert = PromptAlertContent.failure(context: .keyEdit, error: error)
            }
        }
    }
}

private struct SubkeyRowView: View {
    let subkey: GPGSubkey
    let onEditExpiration: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subkey.algorithm)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    Text(subkey.fingerprint)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(subkey.status.localizedName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.14))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())

                    Button("subkey_action_edit_expiration") {
                        onEditExpiration()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            HStack(spacing: 6) {
                Text("\(AppLocalization.string("subkey_key_length_label")) \(subkey.keyLength)")

                if !subkey.usages.isEmpty {
                    metadataDot
                    Text(subkey.usageDisplayName)
                }

                metadataDot
                Text(materialText)

                metadataDot
                Text(expirationText)
            }
            .font(.caption2)
            .foregroundStyle(Color.moaiyTextSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .padding(.horizontal, MoaiyUI.Spacing.md)
        .padding(.vertical, 10)
        .moaiyCardStyle()
    }

    private var metadataDot: some View {
        Circle()
            .fill(Color.moaiyTextSecondary.opacity(0.6))
            .frame(width: 3, height: 3)
    }

    private var materialText: String {
        AppLocalization.string(
            subkey.isSecretMaterial ? "subkey_material_local" : "subkey_material_external"
        )
    }

    private var expirationText: String {
        if let expiresAt = subkey.expiresAt {
            return String(
                format: AppLocalization.string("subkey_expiration_format"),
                expiresAt.formatted(date: .abbreviated, time: .omitted)
            )
        }
        return AppLocalization.string("subkey_expiration_never")
    }

    private var statusColor: Color {
        switch subkey.status {
        case .valid:
            return Color.moaiySuccess
        case .revoked, .disabled, .invalid:
            return Color.moaiyError
        case .expired:
            return Color.moaiyWarning
        case .unknown:
            return Color.moaiyTextSecondary
        }
    }
}

struct OwnerTrustTransferSheet: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var promptAlert: PromptAlertContent?

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ownertrust_transfer_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text("ownertrust_transfer_subtitle")
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

            VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                Text("ownertrust_transfer_export_description")
                    .font(.subheadline)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: exportOwnerTrust) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("action_export_ownertrust", systemImage: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .disabled(isExporting || isImporting)
            }
            .padding(MoaiyUI.Spacing.md)
            .moaiyCardStyle()

            VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                Text("ownertrust_transfer_import_description")
                    .font(.subheadline)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: importOwnerTrust) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("action_import_ownertrust", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .disabled(isExporting || isImporting)
            }
            .padding(MoaiyUI.Spacing.md)
            .moaiyCardStyle()

            Spacer()
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 520, idealWidth: 620, maxWidth: 760, minHeight: 420, idealHeight: 520, maxHeight: 700)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private func exportOwnerTrust() {
        guard let outputURL = presentOwnerTrustSavePanel() else { return }

        isExporting = true
        Task {
            do {
                let data = try await viewModel.exportOwnerTrust()
                let hasOutputAccess = outputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasOutputAccess {
                        outputURL.stopAccessingSecurityScopedResource()
                    }
                }

                try data.write(to: outputURL, options: .atomic)
                promptAlert = PromptAlertContent.success(message: AppLocalization.string("ownertrust_export_success_message"))
            } catch {
                promptAlert = PromptAlertContent.failure(context: .trust, error: error)
            }
            isExporting = false
        }
    }

    private func importOwnerTrust() {
        guard let inputURL = presentOwnerTrustImportPanel() else { return }

        isImporting = true
        Task {
            do {
                try await viewModel.importOwnerTrust(from: inputURL)
                promptAlert = PromptAlertContent.success(message: AppLocalization.string("ownertrust_import_success_message"))
            } catch {
                promptAlert = PromptAlertContent.failure(context: .trust, error: error)
            }
            isImporting = false
        }
    }

    private func presentOwnerTrustSavePanel() -> URL? {
        let panel = NSSavePanel()
        panel.title = AppLocalization.string("action_export_ownertrust")
        panel.nameFieldStringValue = "ownertrust.txt"
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func presentOwnerTrustImportPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = AppLocalization.string("action_import_ownertrust")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

struct RevocationCenterSheet: View {
    let key: GPGKey
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: RevocationReason = .noLongerUsed
    @State private var reasonDescription = ""
    @State private var passphrase = ""
    @State private var isGenerating = false
    @State private var isImporting = false
    @State private var promptAlert: PromptAlertContent?

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("revocation_center_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text("revocation_center_subtitle")
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

            KeyInfoCard(key: key)

            VStack(alignment: .leading, spacing: 12) {
                Text("revocation_reason_title")
                    .font(.headline)

                Picker("revocation_reason_title", selection: $selectedReason) {
                    ForEach(RevocationReason.allCases) { reason in
                        Text(reason.localizedName)
                            .tag(reason)
                    }
                }
                .pickerStyle(.menu)

                TextField("revocation_description_placeholder", text: $reasonDescription)
                    .textFieldStyle(.roundedBorder)

                SecureField("revocation_passphrase_placeholder", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(MoaiyUI.Spacing.md)
            .moaiyCardStyle()

            HStack(spacing: 12) {
                Button(action: generateRevocationCertificate) {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("action_generate_revocation_certificate", systemImage: "shield.lefthalf.filled.slash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .disabled(isGenerating || isImporting)

                Button(action: importRevocationCertificate) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("action_import_revocation_certificate", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating || isImporting)
            }

            Spacer()
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 560, idealWidth: 700, maxWidth: 860, minHeight: 480, idealHeight: 620, maxHeight: 840)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private func generateRevocationCertificate() {
        guard let outputURL = presentRevocationSavePanel() else { return }

        isGenerating = true
        Task {
            do {
                let certificateData = try await viewModel.generateRevocationCertificate(
                    for: key,
                    reason: selectedReason,
                    description: reasonDescription,
                    passphrase: passphrase.isEmpty ? nil : passphrase
                )

                let hasOutputAccess = outputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasOutputAccess {
                        outputURL.stopAccessingSecurityScopedResource()
                    }
                }

                try certificateData.write(to: outputURL, options: .atomic)
                promptAlert = PromptAlertContent.success(message: AppLocalization.string("revocation_success_message"))
            } catch {
                promptAlert = PromptAlertContent.failure(context: .keyEdit, error: error)
            }
            isGenerating = false
        }
    }

    private func importRevocationCertificate() {
        guard let inputURL = presentRevocationImportPanel() else { return }

        isImporting = true
        Task {
            do {
                try await viewModel.importRevocationCertificate(from: inputURL)
                promptAlert = PromptAlertContent.success(message: AppLocalization.string("revocation_import_success_message"))
            } catch {
                promptAlert = PromptAlertContent.failure(context: .keyEdit, error: error)
            }
            isImporting = false
        }
    }

    private func presentRevocationSavePanel() -> URL? {
        let panel = NSSavePanel()
        panel.title = AppLocalization.string("action_generate_revocation_certificate")
        panel.nameFieldStringValue = "\(KeyActionFilePlanner.sanitizedKeyName(for: key.name))_revocation.asc"
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func presentRevocationImportPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = AppLocalization.string("action_import_revocation_certificate")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
