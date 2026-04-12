//
//  ImportKeySheet.swift
//  Moaiy
//
//  Import key sheet for importing GPG keys
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel

    private enum ImportMode: String, CaseIterable, Identifiable {
        case file
        case keyserver
        case yubikey
        case system

        var id: String { rawValue }
    }

    @State private var importMode: ImportMode = .file
    @State private var importedFileURL: URL?
    @State private var keyserverQuery = ""
    @State private var selectedKeyserver = Constants.GPG.defaultKeyserver
    @State private var systemKeyringURL: URL?
    @State private var isImporting = false
    @State private var migrationResult: KeyMigrationResult?
    @State private var yubiKeyImportResult: SmartCardLearnResult?
    @State private var promptAlert: PromptAlertContent?

    private let keyservers = Constants.GPG.supportedKeyservers

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xxl) {
            // Header
            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    Image(systemName: headerIconName)
                        .font(.system(size: 48))
                        .foregroundStyle(Color.moaiyAccentV2)

                    Text("action_import_key")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)

                    Text("import_key_description")
                        .font(.body)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            adaptiveImportModePicker
            .onChange(of: importMode) { _, _ in
                migrationResult = nil
                yubiKeyImportResult = nil
                promptAlert = nil
            }

            // Import source
            ScrollView {
                VStack(spacing: 16) {
                    if importMode == .file {
                        if let fileURL = importedFileURL {
                            FilePreviewCard(url: fileURL) {
                                importedFileURL = nil
                                promptAlert = nil
                            }
                        } else {
                            DropZoneView { url in
                                importedFileURL = url
                                promptAlert = nil
                            }
                        }
                    } else if importMode == .keyserver {
                        KeyserverImportCard(
                            query: $keyserverQuery,
                            selectedKeyserver: $selectedKeyserver,
                            keyservers: keyservers
                        )
                        .onChange(of: keyserverQuery) { _, _ in
                            promptAlert = nil
                        }
                    } else if importMode == .yubikey {
                        YubiKeyImportCard(isImporting: isImporting)

                        if let yubiKeyImportResult {
                            YubiKeyImportResultCard(
                                result: yubiKeyImportResult,
                                onGuideToKeyserver: moveToKeyserverImport(suggestedQuery:)
                            )
                        }
                    } else {
                        SystemKeyringImportCard(
                            selectedURL: systemKeyringURL,
                            isImporting: isImporting,
                            onSelectFolder: chooseSystemKeyringFolder
                        )

                        if let migrationResult {
                            MigrationResultCard(
                                result: migrationResult,
                                onRetry: migrationResult.sourceSecretKeyCount > 0 && !migrationResult.secretKeysMigrated
                                    ? { importFromSystemKeyring() }
                                    : nil
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 360)

            if let yubiKeyImportResult, shouldShowYubiKeyPublicKeyGuidance(yubiKeyImportResult) {
                smartCardCompletionGuidanceBar(for: yubiKeyImportResult)
            }

            // Actions
            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: {
                    runImport()
                }) {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("action_import_key")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .controlSize(.large)
                .disabled(!canImport || isImporting)
            }
        }
        .padding(MoaiyUI.Spacing.xxxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 420, idealWidth: 540, maxWidth: 720)
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    @ViewBuilder
    private var adaptiveImportModePicker: some View {
        HStack {
            Spacer()
            Picker("", selection: $importMode) {
                importModePickerContent
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Spacer()
        }
        .padding(.horizontal, MoaiyUI.Spacing.xs)
    }

    @ViewBuilder
    private var importModePickerContent: some View {
        Text("import_mode_from_file").tag(ImportMode.file)
        Text("import_mode_from_keyserver").tag(ImportMode.keyserver)
        Text("import_mode_from_smartcard").tag(ImportMode.yubikey)
        Text("import_mode_from_existing_keys").tag(ImportMode.system)
    }

    private var canImport: Bool {
        if importMode == .file {
            return importedFileURL != nil
        }
        if importMode == .keyserver {
            return !keyserverQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if importMode == .yubikey {
            return true
        }
        return systemKeyringURL != nil
    }

    private var headerIconName: String {
        switch importMode {
        case .file:
            return "square.and.arrow.down"
        case .keyserver:
            return "globe"
        case .yubikey:
            return "memorychip.fill"
        case .system:
            return "internaldrive"
        }
    }

    private func runImport() {
        if importMode == .file {
            importFromFile()
        } else if importMode == .keyserver {
            importFromKeyserver()
        } else if importMode == .yubikey {
            importFromYubiKey()
        } else {
            importFromSystemKeyring()
        }
    }

    private func importFromFile() {
        guard let fileURL = importedFileURL else { return }

        isImporting = true
        promptAlert = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.importKey(from: fileURL)
                isImporting = false
                showImportSuccessAlert(result)
            } catch {
                isImporting = false
                showImportErrorAlert(error)
            }
        }
    }

    private func importFromKeyserver() {
        let query = keyserverQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isImporting = true
        promptAlert = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.importKeyFromKeyserver(
                    query: query,
                    keyserver: selectedKeyserver
                )
                isImporting = false
                showImportSuccessAlert(result)
            } catch {
                isImporting = false
                showImportErrorAlert(error)
            }
        }
    }

    private func chooseSystemKeyringFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = GPGService.shared.systemGPGHomeURL.deletingLastPathComponent()
        panel.message = String(localized: "migration_keyring_picker_message")
        panel.prompt = String(localized: "action_select_external_keyring")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        systemKeyringURL = url
        migrationResult = nil
        promptAlert = nil
    }

    private func importFromSystemKeyring() {
        guard let sourceURL = systemKeyringURL else { return }

        isImporting = true
        promptAlert = nil
        migrationResult = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.migrateKeysFromExternalKeyring(at: sourceURL)
                migrationResult = result
                isImporting = false
            } catch {
                isImporting = false
                showImportErrorAlert(error)
            }
        }
    }

    private func importFromYubiKey() {
        isImporting = true
        promptAlert = nil
        migrationResult = nil
        yubiKeyImportResult = nil

        Task { @MainActor in
            do {
                let result = try await viewModel.importYubiKeyStubs()
                yubiKeyImportResult = result
                isImporting = false
                if shouldAutoMoveToKeyserverAfterURLFetch(result) {
                    moveToKeyserverImport(
                        suggestedQuery: result.pendingPublicKeyFingerprints.first ?? result.importedStubs.first?.fingerprint
                    )
                    showAutomaticKeyserverGuidanceAlert(result)
                } else {
                    showYubiKeyPublicKeyGuidanceAlertIfNeeded(result)
                }
            } catch {
                isImporting = false
                showImportErrorAlert(error)
            }
        }
    }

    private func showImportSuccessAlert(_ result: KeyImportResult) {
        let details = String(
            format: String(localized: "import_success_details"),
            locale: Locale.current,
            Int64(result.imported),
            Int64(result.unchanged)
        )
        promptAlert = PromptAlertContent.success(
            message: "\(String(localized: "import_success_message"))\n\(details)"
        )
    }

    private func showImportErrorAlert(_ error: Error) {
        promptAlert = PromptAlertContent.failure(
            context: .importKey,
            error: error
        )
    }

    private func showYubiKeyPublicKeyGuidanceAlertIfNeeded(_ result: SmartCardLearnResult) {
        guard shouldShowYubiKeyPublicKeyGuidance(result) else {
            return
        }

        var messageLines: [String] = []
        if result.pendingPublicKeyCount > 0 {
            messageLines.append(
                String(
                    format: String(localized: "yubikey_import_completion_counts"),
                    locale: Locale.current,
                    Int64(result.completedPublicKeyCount),
                    Int64(result.pendingPublicKeyCount)
                )
            )
        }
        messageLines.append(contentsOf: result.completionIssues.map(yubiKeyCompletionIssueMessage(for:)))
        if messageLines.isEmpty {
            messageLines.append(String(localized: "yubikey_import_result_no_stubs"))
        }
        let message = messageLines.joined(separator: "\n")

        promptAlert = PromptAlertContent(
            title: yubiKeyCompletionGuidanceTitle(for: result.publicKeyCompletionLevel),
            message: message,
            actionTitle: "action_ok",
            actionRole: .cancel,
            onAcknowledge: nil,
            secondaryActionTitle: "import_mode_from_keyserver",
            secondaryActionRole: nil,
            onSecondaryAction: {
                moveToKeyserverImport(
                    suggestedQuery: result.pendingPublicKeyFingerprints.first ?? result.importedStubs.first?.fingerprint
                )
            }
        )
    }

    private func shouldAutoMoveToKeyserverAfterURLFetch(_ result: SmartCardLearnResult) -> Bool {
        result.urlFetchTried && !result.urlFetchSucceeded && result.pendingPublicKeyCount > 0
    }

    private func showAutomaticKeyserverGuidanceAlert(_ result: SmartCardLearnResult) {
        var messageLines: [String] = [
            String(localized: "yubikey_import_completion_issue_url_fetch_failed")
        ]
        messageLines.append(
            String(
                format: String(localized: "yubikey_import_completion_counts"),
                locale: Locale.current,
                Int64(result.completedPublicKeyCount),
                Int64(result.pendingPublicKeyCount)
            )
        )
        let message = messageLines.joined(separator: "\n")

        promptAlert = PromptAlertContent(
            title: LocalizedStringKey("yubikey_import_completion_partial_title"),
            message: message,
            actionTitle: "action_ok",
            actionRole: .cancel,
            onAcknowledge: nil
        )
    }

    private func shouldShowYubiKeyPublicKeyGuidance(_ result: SmartCardLearnResult) -> Bool {
        if result.publicKeyCompletionLevel != .complete {
            return true
        }
        return !result.completionIssues.isEmpty
    }

    private func moveToKeyserverImport(suggestedQuery: String?) {
        if let suggestedQuery {
            let normalizedQuery = suggestedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedQuery.isEmpty {
                keyserverQuery = normalizedQuery
            }
        }
        importMode = .keyserver
    }

    private func yubiKeyCompletionGuidanceTitle(
        for completionLevel: SmartCardPublicKeyCompletionLevel
    ) -> LocalizedStringKey {
        switch completionLevel {
        case .complete:
            return LocalizedStringKey("yubikey_import_completion_complete_title")
        case .partial:
            return LocalizedStringKey("yubikey_import_completion_partial_title")
        case .stubOnly:
            return LocalizedStringKey("yubikey_import_completion_stub_only_title")
        }
    }

    private func yubiKeyCompletionIssueMessage(for issue: SmartCardPublicKeyCompletionIssue) -> String {
        switch issue {
        case .missingPublicKeyURL:
            return String(localized: "yubikey_import_completion_issue_missing_public_key_url")
        case .urlFetchFailed:
            return String(localized: "yubikey_import_completion_issue_url_fetch_failed")
        case .keyserverUnreachable:
            return String(localized: "yubikey_import_completion_issue_keyserver_unreachable")
        case .keyserverFetchFailed:
            return String(localized: "yubikey_import_completion_issue_keyserver_fetch_failed")
        }
    }

    private func completionTint(for completionLevel: SmartCardPublicKeyCompletionLevel) -> Color {
        switch completionLevel {
        case .complete:
            return Color.moaiySuccess
        case .partial:
            return Color.moaiyInfo
        case .stubOnly:
            return Color.moaiyWarning
        }
    }

    private func smartCardCompletionGuidanceBar(for result: SmartCardLearnResult) -> some View {
        HStack(alignment: .center, spacing: MoaiyUI.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(yubiKeyCompletionGuidanceTitle(for: result.publicKeyCompletionLevel))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.moaiyTextPrimary)

                Text(yubiKeyGuidanceSummaryText(for: result))
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: MoaiyUI.Spacing.sm)

            Button {
                moveToKeyserverImport(
                    suggestedQuery: result.pendingPublicKeyFingerprints.first ?? result.importedStubs.first?.fingerprint
                )
            } label: {
                Label("import_mode_from_keyserver", systemImage: "globe")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.moaiyAccentV2)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: completionTint(for: result.publicKeyCompletionLevel))
    }

    private func yubiKeyGuidanceSummaryText(for result: SmartCardLearnResult) -> String {
        if result.pendingPublicKeyCount > 0 {
            return String(
                format: String(localized: "yubikey_import_completion_counts"),
                locale: Locale.current,
                Int64(result.completedPublicKeyCount),
                Int64(result.pendingPublicKeyCount)
            )
        }
        if let issue = result.completionIssues.first {
            return yubiKeyCompletionIssueMessage(for: issue)
        }
        return String(localized: "yubikey_import_result_no_stubs")
    }
}

struct YubiKeyImportCard: View {
    let isImporting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("yubikey_import_description")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)

            HStack(spacing: MoaiyUI.Spacing.sm) {
                Image(systemName: "memorychip.fill")
                    .foregroundStyle(Color.moaiyWarning)
                Text("yubikey_import_info_hint")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
            }
            .padding(MoaiyUI.Spacing.sm)
            .moaiyBannerStyle(tint: Color.moaiyInfo)

            if isImporting {
                HStack(spacing: MoaiyUI.Spacing.sm) {
                    ProgressView()
                    Text("yubikey_import_in_progress")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
            }
        }
        .moaiyModalCard()
    }
}

struct YubiKeyImportResultCard: View {
    let result: SmartCardLearnResult
    var onGuideToKeyserver: ((String?) -> Void)? = nil

    private var visibleStubs: [ImportedStubDescriptor] {
        Array(result.importedStubs.prefix(5))
    }

    private var hiddenCount: Int {
        max(result.importedStubs.count - visibleStubs.count, 0)
    }

    private var completionTint: Color {
        switch result.publicKeyCompletionLevel {
        case .complete:
            return Color.moaiySuccess
        case .partial:
            return Color.moaiyInfo
        case .stubOnly:
            return Color.moaiyWarning
        }
    }

    private var preferredGuidanceQuery: String? {
        result.pendingPublicKeyFingerprints.first ?? result.importedStubs.first?.fingerprint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("yubikey_import_result_title")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            Text(
                String(
                    format: String(localized: "yubikey_import_result_summary"),
                    locale: Locale.current,
                    Int64(result.learnedStubCount),
                    result.cardSerialNumber
                )
            )
            .font(.caption)
            .foregroundStyle(Color.moaiyTextSecondary)

            VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                Text(completionTitleKey())
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextPrimary)

                Text(
                    String(
                        format: String(localized: "yubikey_import_completion_counts"),
                        locale: Locale.current,
                        Int64(result.completedPublicKeyCount),
                        Int64(result.pendingPublicKeyCount)
                    )
                )
                .font(.caption2)
                .foregroundStyle(Color.moaiyTextSecondary)

                if let keyserverUsed = result.keyserverUsed {
                    Text(
                        String(
                            format: String(localized: "yubikey_import_completion_keyserver_used"),
                            locale: Locale.current,
                            keyserverUsed
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(Color.moaiyTextSecondary)
                }

                if result.publicKeyCompletionLevel != .complete || !result.completionIssues.isEmpty {
                    Button {
                        onGuideToKeyserver?(preferredGuidanceQuery)
                    } label: {
                        Label("import_mode_from_keyserver", systemImage: "globe")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.moaiyAccentV2)
                }

                ForEach(result.completionIssues, id: \.self) { issue in
                    Text(localizationKey(for: issue))
                        .font(.caption2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
            }
            .padding(MoaiyUI.Spacing.sm)
            .moaiyBannerStyle(tint: completionTint)

            if visibleStubs.isEmpty {
                Text("yubikey_import_result_no_stubs")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
            } else {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                    if result.includesExistingStubs {
                        Text(
                            String(
                                format: String(localized: "yubikey_import_result_existing_stubs"),
                                locale: Locale.current,
                                Int64(result.importedStubs.count)
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                    }

                    ForEach(visibleStubs, id: \.fingerprint) { stub in
                        HStack(alignment: .top, spacing: MoaiyUI.Spacing.sm) {
                            Image(systemName: "memorychip.fill")
                                .foregroundStyle(Color.moaiyWarning)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(for: stub))
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextPrimary)
                                Text(displayEmail(for: stub))
                                    .font(.caption2)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                                Text("\(stub.keyID) • \(shortFingerprint(stub.fingerprint))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                                if let cardSerial = displayCardSerial(for: stub) {
                                    Text(
                                        String(
                                            format: String(localized: "yubikey_import_result_card_serial"),
                                            locale: Locale.current,
                                            cardSerial
                                        )
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                                }
                            }
                        }
                    }

                    if hiddenCount > 0 {
                        Text(
                            String(
                                format: String(localized: "yubikey_import_result_more_items"),
                                locale: Locale.current,
                                Int64(hiddenCount)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: completionTint)
    }

    private func displayName(for descriptor: ImportedStubDescriptor) -> String {
        if descriptor.isUIDResolved, !descriptor.name.isEmpty {
            return descriptor.name
        }
        return String(localized: "yubikey_import_name_unavailable")
    }

    private func displayEmail(for descriptor: ImportedStubDescriptor) -> String {
        if descriptor.isUIDResolved, !descriptor.email.isEmpty {
            return descriptor.email
        }
        return String(localized: "yubikey_import_email_unavailable")
    }

    private func shortFingerprint(_ fingerprint: String) -> String {
        guard fingerprint.count > 16 else { return fingerprint }
        return String(fingerprint.suffix(16))
    }

    private func completionTitleKey() -> LocalizedStringKey {
        switch result.publicKeyCompletionLevel {
        case .complete:
            return LocalizedStringKey("yubikey_import_completion_complete_title")
        case .partial:
            return LocalizedStringKey("yubikey_import_completion_partial_title")
        case .stubOnly:
            return LocalizedStringKey("yubikey_import_completion_stub_only_title")
        }
    }

    private func localizationKey(for issue: SmartCardPublicKeyCompletionIssue) -> LocalizedStringKey {
        switch issue {
        case .missingPublicKeyURL:
            return LocalizedStringKey("yubikey_import_completion_issue_missing_public_key_url")
        case .urlFetchFailed:
            return LocalizedStringKey("yubikey_import_completion_issue_url_fetch_failed")
        case .keyserverUnreachable:
            return LocalizedStringKey("yubikey_import_completion_issue_keyserver_unreachable")
        case .keyserverFetchFailed:
            return LocalizedStringKey("yubikey_import_completion_issue_keyserver_fetch_failed")
        }
    }

    private func displayCardSerial(for descriptor: ImportedStubDescriptor) -> String? {
        guard let serial = descriptor.cardSerialNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !serial.isEmpty else {
            return nil
        }
        return serial
    }
}

struct SystemKeyringImportCard: View {
    let selectedURL: URL?
    let isImporting: Bool
    let onSelectFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("migration_system_keyring_message")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)

            if let selectedURL {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.moaiyAccentV2)
                    Text(selectedURL.path)
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(MoaiyUI.Spacing.sm)
                .moaiyBannerStyle(tint: Color.moaiyInfo)
            }

            Button(action: onSelectFolder) {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("action_select_external_keyring", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
        }
        .moaiyModalCard()
    }
}

struct MigrationResultCard: View {
    let result: KeyMigrationResult
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
            Text("import_success_message")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            Text(
                String(
                    format: String(localized: "import_success_details"),
                    locale: Locale.current,
                    Int64(result.imported),
                    Int64(result.unchanged)
                )
            )
            .font(.caption)
            .foregroundStyle(Color.moaiyTextSecondary)

            Text(
                "\(result.sourcePublicKeyCount) \(String(localized: "key_type_public")) • \(result.sourceSecretKeyCount) \(String(localized: "backup_keys_secret"))"
            )
            .font(.caption)
            .foregroundStyle(Color.moaiyTextSecondary)

            if result.sourceSecretKeyCount > 0 && !result.secretKeysMigrated {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                    Text("migration_secret_keys_incomplete_warning")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyWarning)

                    if let onRetry {
                        Button("action_retry") {
                            onRetry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyBannerStyle(tint: Color.moaiySuccess)
    }
}

struct KeyserverImportCard: View {
    @Binding var query: String
    @Binding var selectedKeyserver: String
    let keyservers: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("keyserver_label")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            TextField("import_keyserver_query_placeholder", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Text("import_keyserver_query_hint")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)

            Picker("keyserver_label", selection: $selectedKeyserver) {
                ForEach(keyservers, id: \.self) { keyserver in
                    Text(keyserver).tag(keyserver)
                }
            }
            .pickerStyle(.menu)
        }
        .moaiyModalCard()
    }
}

// MARK: - Drop Zone View

struct DropZoneView: View {
    let onFileSelected: (URL) -> Void
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.lg) {
            Image(systemName: isTargeted ? "doc.badge.plus" : "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(isTargeted ? Color.moaiyAccentV2 : Color.moaiyTextSecondary)
            
            Text("drop_zone_title")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)
            
            Text("drop_zone_subtitle")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)
            
            Button("action_select_files") {
                selectFile()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(isTargeted ? Color.moaiyAccentV2.opacity(0.08) : Color.moaiySurfaceSecondary.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: MoaiyUI.Radius.lg, style: .continuous)
                .stroke(
                    isTargeted ? Color.moaiyFocusRing : Color.moaiyBorderPrimary.opacity(0.85),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: MoaiyUI.Radius.lg, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "asc") ?? .item,
            .init(filenameExtension: "gpg") ?? .item,
            .init(filenameExtension: "pgp") ?? .item
        ]
        panel.message = String(localized: "import_file_picker_message")
        
        if panel.runModal() == .OK, let url = panel.url {
            onFileSelected(url)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    onFileSelected(url)
                }
            }
        }
        
        return true
    }
}

// MARK: - File Preview Card

struct FilePreviewCard: View {
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: MoaiyUI.Spacing.md) {
            Image(systemName: "doc.text.fill")
                .font(.title)
                .foregroundStyle(Color.moaiyAccentV2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .foregroundStyle(Color.moaiyTextPrimary)
                    .lineLimit(1)
                
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.moaiyTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.md)
    }
}

// MARK: - Preview

#Preview {
    ImportKeySheet()
        .environment(KeyManagementViewModel())
}
