//
//  SettingsView.swift
//  Moaiy
//
//  Application settings view
//

import SwiftUI
import AppKit

private enum TeamPolicyTemplateMetadataKey {
    static let operation = "policy.operation"
    static let templateID = "policy.templateID"
    static let templates = "policy.templates"
    static let appliedTemplateID = "policy.applied.templateID"
    static let appliedDefaultKeyType = "policy.applied.defaultKeyType"
    static let appliedEnableKeySigningMenu = "policy.applied.enableKeySigningMenu"
}

struct TeamPolicyTemplateDescriptor: Sendable, Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let summary: String
    let defaultKeyType: Int
    let enableKeySigningMenu: Bool
    let isManaged: Bool

    var defaultKeyTypeDisplayKey: String {
        switch defaultKeyType {
        case 1:
            return "key_type_rsa2048"
        case 2:
            return "key_type_ecc_curve25519"
        default:
            return "key_type_rsa4096"
        }
    }

    static func parseList(from metadata: [String: String]) -> [TeamPolicyTemplateDescriptor] {
        guard
            let rawTemplates = metadata[TeamPolicyTemplateMetadataKey.templates],
            let data = rawTemplates.data(using: .utf8)
        else {
            return []
        }

        guard let templates = try? JSONDecoder().decode([TeamPolicyTemplateDescriptor].self, from: data) else {
            return []
        }

        return templates.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func parseBool(_ value: String?) -> Bool? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }

        switch normalized {
        case "1", "true", "yes", "y":
            return true
        case "0", "false", "no", "n":
            return false
        default:
            return nil
        }
    }
}

struct SettingsView: View {
    @AppStorage("defaultKeyType") private var defaultKeyType = 0
    @AppStorage(Constants.StorageKeys.appLanguageCode) private var appLanguageCode = AppLanguageOption.system.rawValue
    @AppStorage(Constants.StorageKeys.enableKeySigningMenu) private var enableKeySigningMenu = false
    @AppStorage(Constants.StorageKeys.proEntitlementLastRefresh) private var proEntitlementLastRefresh = 0.0
    @State private var gpgVersion: String = ""
    @State private var activeGPGHomePath: String = ""
    @State private var proRuntime: ProRuntime = AppState.shared.proRuntime
    @State private var promptAlert: PromptAlertContent?
    @State private var teamPolicyTemplates: [TeamPolicyTemplateDescriptor] = []
    @State private var selectedTeamPolicyTemplateID = ""
    @State private var isLoadingTeamPolicyTemplates = false
    @State private var isApplyingTeamPolicyTemplate = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var nounProjectMoaiURL: URL? {
        URL(string: "https://thenounproject.com/browse/icons/term/moai-statue/")
    }

    private var privacyPolicyURL: URL? {
        URL(string: "https://moaiy.com/privacy")
    }

    private var teamPolicyTemplatesDescriptor: ProActionDescriptor? {
        proRuntime.menuDescriptors.first(where: { $0.feature == .teamPolicyTemplates })
    }

    private var selectedTeamPolicyTemplate: TeamPolicyTemplateDescriptor? {
        teamPolicyTemplates.first(where: { $0.id == selectedTeamPolicyTemplateID })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.lg) {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                    Text("section_general")
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    HStack(alignment: .firstTextBaseline) {
                        Text("setting_language")
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Spacer()

                        Picker("setting_language", selection: $appLanguageCode) {
                            ForEach(AppLanguageOption.allCases, id: \.rawValue) { option in
                                Text(LocalizedStringKey(option.settingsDisplayKey))
                                    .tag(option.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }

                    HStack(alignment: .center) {
                        Text("setting_default_key_type")
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Spacer()

                        Picker("setting_default_key_type", selection: $defaultKeyType) {
                            Text("key_type_rsa4096").tag(0)
                            Text("key_type_rsa2048").tag(1)
                            Text("key_type_ecc_curve25519").tag(2)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(minWidth: 260, idealWidth: 340, maxWidth: 380, alignment: .trailing)
                    }

                    Toggle(isOn: $enableKeySigningMenu) {
                        Text("setting_enable_key_signing")
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moaiyModalCard()

                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                    Text("section_keyring")
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    HStack(alignment: .top) {
                        Text("setting_keyring_path")
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        if activeGPGHomePath.isEmpty {
                            Text("setting_keyring_path_unavailable")
                                .foregroundStyle(Color.moaiyTextPrimary)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(activeGPGHomePath)
                                .foregroundStyle(Color.moaiyTextPrimary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }

                    if !activeGPGHomePath.isEmpty {
                        Button("open_in_finder") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: activeGPGHomePath, isDirectory: true))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moaiyModalCard()

                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                    Text("section_pro")
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    ForEach(proRuntime.settingsDescriptors) { descriptor in
                        let availability = proRuntime.availability(for: descriptor.feature)
                        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(LocalizedStringKey(descriptor.titleKey))
                                    .foregroundStyle(Color.moaiyTextSecondary)
                                Spacer()
                                Text(LocalizedStringKey(availability.statusDisplayKey))
                                    .foregroundStyle(
                                        availability.isEnabled
                                            ? Color.moaiySuccess
                                            : Color.moaiyWarning
                                    )
                            }

                            if !availability.isEnabled {
                                Text(LocalizedStringKey(availability.messageKey))
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("setting_pro_entitlement_source")
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text(
                            LocalizedStringKey(
                                proRuntime.availability(for: .hardwareKeyAdvanced).source.displayKey
                            )
                        )
                        .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    if proEntitlementLastRefresh > 0 {
                        HStack(alignment: .firstTextBaseline) {
                            Text("setting_pro_last_refresh")
                                .foregroundStyle(Color.moaiyTextSecondary)
                            Spacer()
                            Text(
                                Date(timeIntervalSince1970: proEntitlementLastRefresh)
                                    .formatted(.dateTime.year().month().day().hour().minute())
                            )
                            .foregroundStyle(Color.moaiyTextPrimary)
                        }
                    }

                    HStack(spacing: MoaiyUI.Spacing.sm) {
                        Button("action_restore_purchases") {
                            Task {
                                await restorePurchases()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("action_refresh_pro_status") {
                            Task {
                                await refreshProState()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if let descriptor = teamPolicyTemplatesDescriptor {
                        Divider()

                        let availability = proRuntime.availability(for: descriptor.feature)
                        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(LocalizedStringKey(descriptor.titleKey))
                                    .foregroundStyle(Color.moaiyTextSecondary)
                                Spacer()
                                if isLoadingTeamPolicyTemplates || isApplyingTeamPolicyTemplate {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }

                            if !availability.isEnabled {
                                Text(LocalizedStringKey(availability.messageKey))
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            } else {
                                Picker(
                                    "pro_team_policy_templates_picker_label",
                                    selection: $selectedTeamPolicyTemplateID
                                ) {
                                    ForEach(teamPolicyTemplates) { template in
                                        Text(template.name)
                                            .tag(template.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .disabled(teamPolicyTemplates.isEmpty || isLoadingTeamPolicyTemplates)

                                if let selectedTeamPolicyTemplate {
                                    if !selectedTeamPolicyTemplate.summary.isEmpty {
                                        Text(selectedTeamPolicyTemplate.summary)
                                            .font(.caption)
                                            .foregroundStyle(Color.moaiyTextSecondary)
                                    }

                                    HStack(alignment: .firstTextBaseline) {
                                        Text("setting_default_key_type")
                                            .foregroundStyle(Color.moaiyTextSecondary)
                                        Spacer()
                                        Text(LocalizedStringKey(selectedTeamPolicyTemplate.defaultKeyTypeDisplayKey))
                                            .foregroundStyle(Color.moaiyTextPrimary)
                                    }

                                    HStack(alignment: .firstTextBaseline) {
                                        Text("setting_enable_key_signing")
                                            .foregroundStyle(Color.moaiyTextSecondary)
                                        Spacer()
                                        Text(
                                            LocalizedStringKey(
                                                selectedTeamPolicyTemplate.enableKeySigningMenu
                                                    ? "pro_team_policy_templates_value_enabled"
                                                    : "pro_team_policy_templates_value_disabled"
                                            )
                                        )
                                        .foregroundStyle(Color.moaiyTextPrimary)
                                    }
                                } else if isLoadingTeamPolicyTemplates {
                                    Text("pro_team_policy_templates_loading")
                                        .font(.caption)
                                        .foregroundStyle(Color.moaiyTextSecondary)
                                } else {
                                    Text("pro_team_policy_templates_empty")
                                        .font(.caption)
                                        .foregroundStyle(Color.moaiyTextSecondary)
                                }

                                HStack(spacing: MoaiyUI.Spacing.sm) {
                                    Button("action_pro_team_policy_templates_reload") {
                                        Task {
                                            await loadTeamPolicyTemplates(
                                                forceRefresh: true,
                                                showFailureAlert: true
                                            )
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isLoadingTeamPolicyTemplates || isApplyingTeamPolicyTemplate)

                                    Button("action_pro_team_policy_templates_apply") {
                                        Task {
                                            await applySelectedTeamPolicyTemplate()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(
                                        selectedTeamPolicyTemplate == nil
                                            || isLoadingTeamPolicyTemplates
                                            || isApplyingTeamPolicyTemplate
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moaiyModalCard()

                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                    Text("section_about")
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    HStack {
                        Text("about_app_version")
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text("\(appVersion) (\(appBuild))")
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    HStack {
                        Text("about_gpg_version")
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        if gpgVersion.isEmpty {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Text("\(gpgVersion) · \(AppLocalization.string("about_gpg_embedded"))")
                                .foregroundStyle(Color.moaiyTextPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    HStack {
                        Text("setting_keyring_mode")
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text("setting_keyring_mode_app")
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                        Text("about_icon_credit_title")
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Text("about_icon_credit_text")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        if let nounProjectMoaiURL {
                            Link(destination: nounProjectMoaiURL) {
                                Text("about_icon_credit_link")
                            }
                            .font(.caption)
                            .tint(Color.moaiyAccentV2)
                        }
                    }

                    if let privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            Label("privacy_policy", systemImage: "hand.raised")
                                .font(.subheadline)
                        }
                        .tint(Color.moaiyAccentV2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .moaiyModalCard()
        }
        .padding(MoaiyUI.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 420, idealWidth: 560, maxWidth: 760)
        .moaiyPromptAlertHost(alert: $promptAlert)
        .task {
            normalizeLanguageSelection()
            await loadGPGVersion()
            refreshKeyringState()
            await refreshProState()
        }
    }

    @MainActor
    private func normalizeLanguageSelection() {
        appLanguageCode = AppLanguageOption.from(storageValue: appLanguageCode).rawValue
    }
    
    @MainActor
    private func loadGPGVersion() async {
        let service = GPGService.shared
        if let version = service.gpgVersion {
            gpgVersion = version
        } else {
            gpgVersion = AppLocalization.string("about_gpg_not_available")
        }
    }

    @MainActor
    private func refreshKeyringState() {
        let service = GPGService.shared
        activeGPGHomePath = service.activeGPGHomePath
    }

    @MainActor
    private func refreshProState() async {
        await proRuntime.refreshEntitlements()
        proEntitlementLastRefresh = Date().timeIntervalSince1970
        await loadTeamPolicyTemplates(forceRefresh: true)
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await proRuntime.restorePurchases()
            proEntitlementLastRefresh = Date().timeIntervalSince1970
            await loadTeamPolicyTemplates(forceRefresh: true)
            promptAlert = .success(
                message: AppLocalization.string("pro_restore_success_message"),
                title: "pro_restore_success_title"
            )
        } catch {
            promptAlert = .failure(
                title: "pro_restore_failure_title",
                message: AppLocalization.string("pro_restore_failure_message")
            )
        }
    }

    @MainActor
    private func loadTeamPolicyTemplates(
        forceRefresh: Bool,
        showFailureAlert: Bool = false
    ) async {
        guard let descriptor = teamPolicyTemplatesDescriptor else {
            teamPolicyTemplates = []
            selectedTeamPolicyTemplateID = ""
            return
        }

        let availability = proRuntime.availability(for: descriptor.feature)
        guard availability.isEnabled else {
            teamPolicyTemplates = []
            selectedTeamPolicyTemplateID = ""
            return
        }

        if isLoadingTeamPolicyTemplates {
            return
        }

        if !forceRefresh && !teamPolicyTemplates.isEmpty {
            return
        }

        isLoadingTeamPolicyTemplates = true
        defer { isLoadingTeamPolicyTemplates = false }

        do {
            let result = try await proRuntime.executeMenuAction(
                descriptor: descriptor,
                keyFingerprint: nil,
                metadata: [
                    TeamPolicyTemplateMetadataKey.operation: "list"
                ]
            )

            let loadedTemplates = TeamPolicyTemplateDescriptor.parseList(from: result.metadata)
            teamPolicyTemplates = loadedTemplates

            if let selected = loadedTemplates.first(where: { $0.id == selectedTeamPolicyTemplateID }) {
                selectedTeamPolicyTemplateID = selected.id
            } else {
                selectedTeamPolicyTemplateID = loadedTemplates.first?.id ?? ""
            }
        } catch {
            teamPolicyTemplates = []
            selectedTeamPolicyTemplateID = ""
            if showFailureAlert {
                promptAlert = .failure(
                    title: "pro_feature_locked_title",
                    message: AppLocalization.string("pro_team_policy_templates_operation_failed_message")
                )
            }
        }
    }

    @MainActor
    private func applySelectedTeamPolicyTemplate() async {
        guard let descriptor = teamPolicyTemplatesDescriptor else { return }
        guard let selectedTemplate = selectedTeamPolicyTemplate else { return }

        isApplyingTeamPolicyTemplate = true
        defer { isApplyingTeamPolicyTemplate = false }

        do {
            let result = try await proRuntime.executeMenuAction(
                descriptor: descriptor,
                keyFingerprint: nil,
                metadata: [
                    TeamPolicyTemplateMetadataKey.operation: "apply",
                    TeamPolicyTemplateMetadataKey.templateID: selectedTemplate.id
                ]
            )

            guard
                let resolvedDefaultKeyType = Int(
                    result.metadata[TeamPolicyTemplateMetadataKey.appliedDefaultKeyType] ?? ""
                ),
                let resolvedSigningState = TeamPolicyTemplateDescriptor.parseBool(
                    result.metadata[TeamPolicyTemplateMetadataKey.appliedEnableKeySigningMenu]
                )
            else {
                promptAlert = .failure(
                    title: "pro_feature_locked_title",
                    message: AppLocalization.string("pro_team_policy_templates_operation_failed_message")
                )
                return
            }

            defaultKeyType = resolvedDefaultKeyType
            enableKeySigningMenu = resolvedSigningState
            selectedTeamPolicyTemplateID = result.metadata[TeamPolicyTemplateMetadataKey.appliedTemplateID]
                ?? selectedTemplate.id

            promptAlert = .success(
                message: AppLocalization.localizedString(forKey: result.messageKey),
                title: LocalizedStringKey(descriptor.titleKey)
            )

            await loadTeamPolicyTemplates(forceRefresh: true)
        } catch ProModuleExecutionError.featureLocked {
            let availability = proRuntime.availability(for: descriptor.feature)
            promptAlert = .info(
                title: "pro_feature_locked_title",
                message: AppLocalization.localizedString(forKey: availability.messageKey)
            )
        } catch {
            promptAlert = .failure(
                title: "pro_feature_locked_title",
                message: AppLocalization.string("pro_team_policy_templates_operation_failed_message")
            )
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
