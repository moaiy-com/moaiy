//
//  KeyCardView.swift
//  Moaiy
//
//  Simplified key card view with drop zone for drag-and-drop
//

import SwiftUI

struct KeyCardView: View {
    let key: GPGKey
    var onDelete: (() -> Void)?
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    @State private var isProcessing = false
    @State private var operationResults: [OperationResult] = []
    @State private var showingResultOverlay = false
    @State private var showingPasswordSheet = false
    @State private var showingYubiKeyPINSheet = false
    @State private var decryptAllowsEmptyPassword = true
    @State private var passwordSheetFileName = ""
    @State private var yubiKeyPINFileName = ""
    @State private var pendingDecryptRequests: [DecryptRequest] = []
    @State private var pendingDetectedFiles: [DetectedFile] = []
    @State private var promptAlert: PromptAlertContent?
    
    private let detector = GPGFileTypeDetector()

    private struct DecryptRequest {
        let sourceURL: URL
        let outputURL: URL
    }

    private struct DetectedFile {
        let url: URL
        let type: GPGFileType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            keyInfoSection
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
        .moaiyOperationPromptHost(
            alert: $promptAlert,
            operationResults: $operationResults,
            isShowingOperationResults: $showingResultOverlay,
            onOpenInFinder: { url in
                NSWorkspace.shared.selectFile(
                    url.path,
                    inFileViewerRootedAtPath: url.deletingLastPathComponent().path
                )
            }
        )
        .sheet(isPresented: $showingPasswordSheet) {
            PasswordInputSheet(
                fileName: passwordSheetFileName,
                allowsEmptyPassword: decryptAllowsEmptyPassword,
                onConfirm: { password in
                    showingPasswordSheet = false
                    decryptAllowsEmptyPassword = true
                    passwordSheetFileName = ""
                    Task {
                        await performQueuedDecryptions(password: password)
                    }
                },
                onCancel: {
                    showingPasswordSheet = false
                    decryptAllowsEmptyPassword = true
                    passwordSheetFileName = ""
                    pendingDecryptRequests = []
                    if !operationResults.isEmpty {
                        showingResultOverlay = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingYubiKeyPINSheet) {
            YubiKeyPINSheet(
                fileName: yubiKeyPINFileName,
                onConfirm: { pin in
                    showingYubiKeyPINSheet = false
                    yubiKeyPINFileName = ""
                    Task {
                        await performQueuedDecryptions(password: pin)
                    }
                },
                onCancel: {
                    showingYubiKeyPINSheet = false
                    yubiKeyPINFileName = ""
                    pendingDecryptRequests = []
                    if !operationResults.isEmpty {
                        showingResultOverlay = true
                    }
                }
            )
        }
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(key.fingerprint, forType: .string)
            }) {
                Label("action_copy_fingerprint", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: {
                onDelete?()
            }) {
                Label("action_delete_key", systemImage: "trash.fill")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var keyInfoSection: some View {
        HStack(alignment: .center, spacing: MoaiyUI.Spacing.md) {
            HStack(spacing: MoaiyUI.Spacing.lg) {
                Image(systemName: key.isSmartCardStub ? "memorychip.fill" : (key.isSecret ? "key.fill" : "key"))
                    .font(.title2)
                    .foregroundStyle(keyIconColor)
                    .frame(width: 40, height: 40)
                    .background(Color.moaiySurfaceSecondary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                    Text(key.name)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: MoaiyUI.Spacing.sm) {
                        Text(key.isSecret ? "key_type_private" : "key_type_public")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(keyTypeBadgeColor.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(keyTypeBadgeColor.opacity(0.35), lineWidth: 1)
                            )
                            .foregroundStyle(keyTypeBadgeColor)
                            .clipShape(Capsule())

                        Text(key.trustLevel.localizedName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(trustLevelColor.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(trustLevelColor.opacity(0.35), lineWidth: 1)
                            )
                            .foregroundStyle(trustLevelColor)
                            .clipShape(Capsule())

                        if key.isSmartCardStub {
                            Text("key_type_yubikey_stub")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.moaiyWarning.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.moaiyWarning.opacity(0.35), lineWidth: 1)
                                )
                                .foregroundStyle(Color.moaiyWarning)
                                .clipShape(Capsule())
                        }

                        if key.isExpired {
                            Text("status_expired")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                )
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }

                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: MoaiyUI.Spacing.md) {
                        Label(key.displayKeyType, systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        Label(keyDateRangeDisplayText, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(key.isExpired ? Color.red : Color.moaiyTextSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 800, alignment: .leading)
            .layoutPriority(1)

            KeyDropZoneView(
                hintTextKey: key.isSecret ? "drop_zone_hint" : "drop_zone_encrypt_title",
                onDrop: { urls in
                    handleDroppedFiles(urls: urls)
                },
                onTap: {
                    selectFilesAndProcess()
                }
            )
            .frame(minWidth: 80, idealWidth: 390, maxWidth: 390, alignment: .trailing)
            .frame(height: 52)
            .layoutPriority(3)

            KeyActionMenu(key: key, onDelete: onDelete)
                .frame(width: 36, alignment: .trailing)
                .fixedSize()
                .layoutPriority(3)
        }
    }
    
    // MARK: - Color Computed Properties
    
    private var keyIconColor: Color {
        if key.isSmartCardStub {
            return Color.moaiyWarning
        }
        return key.isSecret ? Color.moaiyAccentV2 : Color.moaiyTextSecondary
    }
    
    private var keyTypeBadgeColor: Color {
        if key.isSmartCardStub {
            return Color.moaiyWarning
        }
        return key.isSecret ? Color.moaiyAccentV2 : Color.moaiyInfo
    }
    
    private var trustLevelColor: Color {
        switch key.trustLevel {
        case .ultimate:
            return Color.moaiySuccess
        case .full:
            return Color.moaiyInfo
        case .marginal:
            return Color.moaiyWarning
        case .none:
            return Color.moaiyError
        case .unknown:
            return Color.moaiyTextSecondary
        }
    }

    private var keyDateRangeDisplayText: String {
        let createdText = key.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "-"
        let expirationText: String
        if let expiresAt = key.expiresAt {
            expirationText = expiresAt.formatted(date: .abbreviated, time: .omitted)
        } else {
            expirationText = String(localized: "statistics_no_expiration")
        }

        return "\(createdText) - \(expirationText)"
    }
    
    // MARK: - File Handling

    private func handleDroppedFiles(urls: [URL]) {
        Task { @MainActor in
            isProcessing = true
            operationResults = []
            pendingDecryptRequests = []
            decryptAllowsEmptyPassword = true
            passwordSheetFileName = ""

            var detectedFiles: [DetectedFile] = []
            for url in urls {
                let hasScopedAccess = url.startAccessingSecurityScopedResource()
                let fileType = await detector.detectFileType(at: url)
                if hasScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                detectedFiles.append(DetectedFile(url: url, type: fileType))
            }

            if requiresUntrustedEncryptionConfirmation(for: detectedFiles) {
                presentUntrustedRecipientConfirmation(for: detectedFiles)
                return
            }

            await processDetectedFiles(detectedFiles, allowUntrustedRecipients: false)
            completeBatchProcessing()
        }
    }

    @MainActor
    private func processDetectedFiles(_ detectedFiles: [DetectedFile], allowUntrustedRecipients: Bool) async {
        for detected in detectedFiles {
            let shouldContinue = await processFile(
                url: detected.url,
                type: detected.type,
                allowUntrustedRecipients: allowUntrustedRecipients
            )
            guard shouldContinue else {
                break
            }
        }
    }

    @MainActor
    private func completeBatchProcessing() {
        isProcessing = false
        if !pendingDecryptRequests.isEmpty {
            Task { @MainActor in
                await startQueuedDecryptionFlow()
            }
            return
        }
        if !operationResults.isEmpty {
            showingResultOverlay = true
        }
    }

    @MainActor
    private func startQueuedDecryptionFlow() async {
        if key.isSmartCardStub {
            if let hardwareTokenError = await KeyFileCryptoCoordinator.hardwareTokenPresenceErrorMessageIfNeeded(
                for: key,
                context: .decrypt
            ) {
                promptAlert = PromptAlertContent.failure(
                    title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .decrypt)),
                    message: hardwareTokenError
                )
                pendingDecryptRequests = []
                return
            }

            yubiKeyPINFileName = pendingDecryptRequests.first?.sourceURL.lastPathComponent ?? ""
            showingYubiKeyPINSheet = true
            return
        }

        let requiresPassphrase = await KeyFileCryptoCoordinator.requiresPassphrase(for: key.fingerprint)
        if requiresPassphrase {
            decryptAllowsEmptyPassword = false
            passwordSheetFileName = pendingDecryptRequests.first?.sourceURL.lastPathComponent ?? ""
            showingPasswordSheet = true
            return
        }

        decryptAllowsEmptyPassword = true
        passwordSheetFileName = ""
        await performQueuedDecryptions(password: "")
    }

    private func requiresUntrustedEncryptionConfirmation(for detectedFiles: [DetectedFile]) -> Bool {
        let intents = detectedFiles.map { detected in
            KeyFileIntent.autoDetected(type: detected.type)
        }
        return KeyFileCryptoCoordinator.shouldRequireUntrustedRecipientConfirmation(
            intents: intents,
            keyIsSecret: key.isSecret,
            keyIsTrusted: key.isTrusted
        )
    }

    private func presentUntrustedRecipientConfirmation(for detectedFiles: [DetectedFile]) {
        pendingDetectedFiles = detectedFiles
        promptAlert = PromptAlertContent.destructiveConfirmation(
            title: "encrypt_untrusted_recipient_title",
            message: String(localized: "encrypt_untrusted_recipient_message"),
            onConfirm: {
                let files = pendingDetectedFiles
                pendingDetectedFiles = []
                Task { @MainActor in
                    isProcessing = true
                    await processDetectedFiles(files, allowUntrustedRecipients: true)
                    completeBatchProcessing()
                }
            },
            onCancel: {
                pendingDetectedFiles = []
                isProcessing = false
            },
            onDismiss: {
                pendingDetectedFiles = []
                isProcessing = false
            }
        )
    }

    @MainActor
    private func processFile(url: URL, type: GPGFileType, allowUntrustedRecipients: Bool) async -> Bool {
        let route = KeyFileCryptoCoordinator.route(
            for: .autoDetected(type: type),
            keyIsSecret: key.isSecret
        )

        switch route {
        case .rejectDecryptRequiresPrivateKey:
            operationResults.append(
                OperationResult.failure(
                    fileURL: url,
                    operation: .decrypt,
                    errorMessage: String(localized: "error_decryption_requires_private_key")
                )
            )
            return true

        case .decrypt:
            if let hardwareTokenError = await KeyFileCryptoCoordinator.hardwareTokenPresenceErrorMessageIfNeeded(
                for: key,
                context: .decrypt
            ) {
                promptAlert = PromptAlertContent.failure(
                    title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .decrypt)),
                    message: hardwareTokenError
                )
                pendingDecryptRequests = []
                return false
            }

            if let mismatchMessage = await KeyFileCryptoCoordinator.decryptionKeyMismatchMessageIfNeeded(
                for: [url],
                preferredSecretKey: key.fingerprint,
                availableSecretKeys: viewModel.secretKeys
            ) {
                promptAlert = PromptAlertContent.failure(
                    title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .decrypt)),
                    message: mismatchMessage
                )
                pendingDecryptRequests = []
                return false
            }

            let defaultOutputURL = KeyActionFilePlanner.decryptedOutputURL(for: url)
            guard let outputURL = presentFileOperationSavePanel(
                defaultFileName: defaultOutputURL.lastPathComponent,
                preferredDirectory: url.deletingLastPathComponent()
            ) else {
                return true
            }

            pendingDecryptRequests.append(
                DecryptRequest(
                    sourceURL: url,
                    outputURL: outputURL
                )
            )
            return true

        case .encrypt:
            let defaultOutputURL = KeyActionFilePlanner.encryptedOutputURL(for: url)
            guard let outputURL = presentFileOperationSavePanel(
                defaultFileName: defaultOutputURL.lastPathComponent,
                preferredDirectory: url.deletingLastPathComponent()
            ) else {
                return true
            }
            let outcomes = await KeyFileCryptoCoordinator.encrypt(
                requests: [
                    KeyFileOperationRequest(
                        sourceURL: url,
                        destinationURL: outputURL
                    )
                ],
                recipientKey: key.fingerprint,
                allowUntrustedRecipients: allowUntrustedRecipients
            )

            operationResults.append(contentsOf: KeyFileOperationResultMapper.encryptResults(from: outcomes))
            return true
        }
    }

    @MainActor
    private func performQueuedDecryptions(password: String) async {
        guard !pendingDecryptRequests.isEmpty else {
            return
        }
        
        isProcessing = true
        let requests = pendingDecryptRequests.map {
            KeyFileOperationRequest(sourceURL: $0.sourceURL, destinationURL: $0.outputURL)
        }
        let outcomes = await KeyFileCryptoCoordinator.decrypt(
            requests: requests,
            passphrase: password,
            preferredSecretKey: key.fingerprint
        )
        operationResults.append(contentsOf: KeyFileOperationResultMapper.decryptResults(from: outcomes))
        
        pendingDecryptRequests = []
        isProcessing = false
        if !operationResults.isEmpty {
            showingResultOverlay = true
        }
    }

    private func presentFileOperationSavePanel(defaultFileName: String, preferredDirectory: URL) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName
        panel.directoryURL = preferredDirectory
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func selectFilesAndProcess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.message = String(localized: "action_select_files")
        panel.prompt = String(localized: "action_select_files")

        guard panel.runModal() == .OK else { return }
        handleDroppedFiles(urls: panel.urls)
    }
}
