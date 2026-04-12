//
//  KeyActionMenu.swift
//  Moaiy
//
//  Menu component for key actions (encrypt, decrypt, sign, verify, backup, upload, delete)
//

import SwiftUI

struct KeyActionFilePlanner {
    static func encryptedOutputURL(for inputURL: URL) -> URL {
        inputURL.appendingPathExtension(Constants.File.defaultEncryptedExtension)
    }

    static func decryptedOutputURL(for inputURL: URL) -> URL {
        let ext = inputURL.pathExtension.lowercased()
        if Constants.File.encryptedExtensions.contains(ext) {
            return inputURL.deletingPathExtension()
        }
        if ext.isEmpty {
            return inputURL.appendingPathExtension("decrypted")
        }
        return inputURL.deletingPathExtension()
    }

    static func detachedSignatureOutputURL(for inputURL: URL) -> URL {
        inputURL.appendingPathExtension("sig")
    }

    static func defaultPublicFileName(for keyName: String) -> String {
        "\(sanitizedKeyName(for: keyName))_public.asc"
    }

    static func defaultPrivateFileName(for keyName: String) -> String {
        "\(sanitizedKeyName(for: keyName))_private.asc"
    }

    static func sanitizedKeyName(for keyName: String) -> String {
        keyName.replacingOccurrences(of: " ", with: "_")
    }
}

struct KeyFileOperationRequest {
    let sourceURL: URL
    let destinationURL: URL
}

struct KeyFileOperationOutcome {
    let sourceURL: URL
    let destinationURL: URL?
    let error: Error?
}

enum KeyFileOperationResultMapper {
    static func encryptResults(from outcomes: [KeyFileOperationOutcome]) -> [OperationResult] {
        outcomes.map { outcome in
            if let error = outcome.error {
                return OperationResult.failure(
                    fileURL: outcome.sourceURL,
                    operation: .encrypt,
                    errorMessage: UserFacingErrorMapper.message(for: error, context: .encrypt)
                )
            }

            guard let outputURL = outcome.destinationURL else {
                return OperationResult.failure(
                    fileURL: outcome.sourceURL,
                    operation: .encrypt,
                    errorMessage: UserFacingErrorMapper.message(
                        for: GPGError.encryptionFailed("No output generated"),
                        context: .encrypt
                    )
                )
            }

            return OperationResult.successEncrypt(
                fileURL: outcome.sourceURL,
                outputURL: outputURL
            )
        }
    }

    static func decryptResults(from outcomes: [KeyFileOperationOutcome]) -> [OperationResult] {
        outcomes.map { outcome in
            if let error = outcome.error {
                return OperationResult.failure(
                    fileURL: outcome.sourceURL,
                    operation: .decrypt,
                    errorMessage: UserFacingErrorMapper.message(for: error, context: .decrypt)
                )
            }

            guard let outputURL = outcome.destinationURL else {
                return OperationResult.failure(
                    fileURL: outcome.sourceURL,
                    operation: .decrypt,
                    errorMessage: UserFacingErrorMapper.message(
                        for: GPGError.decryptionFailed("No output generated"),
                        context: .decrypt
                    )
                )
            }

            return OperationResult.successDecrypt(
                fileURL: outcome.sourceURL,
                outputURL: outputURL
            )
        }
    }
}

enum KeyFileIntent {
    case encrypt
    case decrypt
    case autoDetected(type: GPGFileType)
}

enum KeyFileRoute {
    case encrypt
    case decrypt
    case rejectDecryptRequiresPrivateKey

    var requiresUntrustedRecipientConfirmation: Bool {
        switch self {
        case .encrypt:
            return true
        case .decrypt, .rejectDecryptRequiresPrivateKey:
            return false
        }
    }

    var isExecutable: Bool {
        switch self {
        case .encrypt, .decrypt:
            return true
        case .rejectDecryptRequiresPrivateKey:
            return false
        }
    }
}

enum KeyFileCryptoCoordinator {
    static func route(for intent: KeyFileIntent, keyIsSecret: Bool) -> KeyFileRoute {
        switch intent {
        case .encrypt:
            return .encrypt
        case .decrypt:
            return keyIsSecret ? .decrypt : .rejectDecryptRequiresPrivateKey
        case .autoDetected(let type):
            switch type {
            case .encrypted:
                return keyIsSecret ? .decrypt : .rejectDecryptRequiresPrivateKey
            case .notGPG, .publicKey, .privateKey, .signature, .unknown:
                return .encrypt
            }
        }
    }

    static func canPerform(_ intent: KeyFileIntent, keyIsSecret: Bool) -> Bool {
        route(for: intent, keyIsSecret: keyIsSecret).isExecutable
    }

    static func shouldRequireUntrustedRecipientConfirmation(
        intents: [KeyFileIntent],
        keyIsSecret: Bool,
        keyIsTrusted: Bool
    ) -> Bool {
        guard !keyIsTrusted else { return false }
        return intents.contains { intent in
            route(for: intent, keyIsSecret: keyIsSecret).requiresUntrustedRecipientConfirmation
        }
    }

    @MainActor
    static func decryptionKeyMismatchMessageIfNeeded(
        for urls: [URL],
        preferredSecretKey: String,
        availableSecretKeys: [GPGKey]
    ) async -> String? {
        for url in urls {
            do {
                let result = try await GPGService.shared.checkDecryptionRecipientMatch(
                    sourceURL: url,
                    preferredSecretKey: preferredSecretKey
                )
                guard !result.matchesPreferredKey else {
                    continue
                }

                return UserFacingErrorMapper.decryptionKeyMismatchMessage(
                    recipientKeyIDs: result.recipientKeyIDs,
                    availableSecretKeys: availableSecretKeys
                )
            } catch {
                return UserFacingErrorMapper.message(for: error, context: .decrypt)
            }
        }

        return nil
    }

    @MainActor
    static func requiresPassphrase(for secretKeyID: String) async -> Bool {
        do {
            return try await GPGService.shared.secretKeyRequiresPassphrase(keyID: secretKeyID)
        } catch {
            return true
        }
    }

    @MainActor
    static func hardwareTokenPresenceErrorMessageIfNeeded(
        for key: GPGKey,
        context: UserFacingErrorContext
    ) async -> String? {
        guard key.requiresHardwareTokenForPrivateOps else {
            return nil
        }

        do {
            _ = try await GPGService.shared.checkSmartCardPresence()
            return nil
        } catch {
            return UserFacingErrorMapper.message(for: error, context: context)
        }
    }

    @MainActor
    static func encrypt(
        requests: [KeyFileOperationRequest],
        recipientKey: String,
        allowUntrustedRecipients: Bool = false
    ) async -> [KeyFileOperationOutcome] {
        var outcomes: [KeyFileOperationOutcome] = []
        outcomes.reserveCapacity(requests.count)

        for request in requests {
            do {
                let outputURL = try await withSecurityScopedAccess(
                    sourceURL: request.sourceURL,
                    destinationURL: request.destinationURL
                ) {
                    try await GPGService.shared.encryptFile(
                        sourceURL: request.sourceURL,
                        destinationURL: request.destinationURL,
                        recipients: [recipientKey],
                        allowUntrustedRecipients: allowUntrustedRecipients
                    )
                }
                outcomes.append(
                    KeyFileOperationOutcome(
                        sourceURL: request.sourceURL,
                        destinationURL: outputURL,
                        error: nil
                    )
                )
            } catch {
                outcomes.append(
                    KeyFileOperationOutcome(
                        sourceURL: request.sourceURL,
                        destinationURL: nil,
                        error: error
                    )
                )
            }
        }

        return outcomes
    }

    @MainActor
    static func decrypt(
        requests: [KeyFileOperationRequest],
        passphrase: String,
        preferredSecretKey: String
    ) async -> [KeyFileOperationOutcome] {
        var outcomes: [KeyFileOperationOutcome] = []
        outcomes.reserveCapacity(requests.count)

        for request in requests {
            do {
                let outputURL = try await withSecurityScopedAccess(
                    sourceURL: request.sourceURL,
                    destinationURL: request.destinationURL
                ) {
                    try await GPGService.shared.decryptFile(
                        sourceURL: request.sourceURL,
                        destinationURL: request.destinationURL,
                        passphrase: passphrase,
                        preferredSecretKey: preferredSecretKey
                    )
                }

                guard FileManager.default.fileExists(atPath: outputURL.path) else {
                    throw GPGError.decryptionFailed("No output generated")
                }

                outcomes.append(
                    KeyFileOperationOutcome(
                        sourceURL: request.sourceURL,
                        destinationURL: outputURL,
                        error: nil
                    )
                )
            } catch {
                outcomes.append(
                    KeyFileOperationOutcome(
                        sourceURL: request.sourceURL,
                        destinationURL: nil,
                        error: error
                    )
                )
            }
        }

        return outcomes
    }

    static func summarize(
        outcomes: [KeyFileOperationOutcome]
    ) -> (successCount: Int, failureCount: Int, firstError: Error?) {
        var successCount = 0
        var failureCount = 0
        var firstError: Error?

        for outcome in outcomes {
            if let error = outcome.error {
                failureCount += 1
                if firstError == nil {
                    firstError = error
                }
            } else {
                successCount += 1
            }
        }

        return (successCount, failureCount, firstError)
    }

    @MainActor
    private static func withSecurityScopedAccess<T>(
        sourceURL: URL,
        destinationURL: URL,
        operation: () async throws -> T
    ) async throws -> T {
        let hasSourceAccess = sourceURL.startAccessingSecurityScopedResource()
        let hasOutputAccess = destinationURL.startAccessingSecurityScopedResource()
        defer {
            if hasSourceAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            if hasOutputAccess {
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }

        return try await operation()
    }
}

enum KeyActionAlertDecision: Equatable {
    case none
    case success(String)
    case error(String)
}

struct KeyActionMenuAvailability {
    let hasSecretKey: Bool
    let isSmartCardStub: Bool
    let isKeySigningMenuEnabled: Bool
    let isBackupRestoreMenuEnabled: Bool

    init(
        key: GPGKey,
        isKeySigningMenuEnabled: Bool,
        isBackupRestoreMenuEnabled: Bool = false
    ) {
        self.hasSecretKey = key.isSecret
        self.isSmartCardStub = key.isSmartCardStub
        self.isKeySigningMenuEnabled = isKeySigningMenuEnabled
        self.isBackupRestoreMenuEnabled = isBackupRestoreMenuEnabled
    }

    var canDecrypt: Bool {
        KeyFileCryptoCoordinator.canPerform(.decrypt, keyIsSecret: hasSecretKey)
    }
    var canSignDetached: Bool { hasSecretKey }
    var canEdit: Bool { hasSecretKey && !isSmartCardStub }
    var canSignKey: Bool { hasSecretKey && !isSmartCardStub && isKeySigningMenuEnabled }
    var showsSignKey: Bool { isKeySigningMenuEnabled }
    var showsExportPrivateKey: Bool { hasSecretKey && !isSmartCardStub }
    // Reserved feature: keep backup/restore implementation, hide entry for now.
    var showsBackupRestore: Bool { isBackupRestoreMenuEnabled }
}

struct KeyActionBatchResultPlanner {
    static func makeAlertDecision(
        successCount: Int,
        failureCount: Int,
        successMessage: String,
        firstErrorMessage: String?
    ) -> KeyActionAlertDecision {
        guard successCount > 0 || failureCount > 0 else {
            return .none
        }

        if failureCount == 0 {
            return .success(successMessage)
        }

        let fallbackErrorMessage = String(localized: "error_occurred")
        let errorText: String
        if let firstErrorMessage, !firstErrorMessage.isEmpty {
            errorText = firstErrorMessage
        } else {
            errorText = fallbackErrorMessage
        }

        if successCount > 0 {
            return .error("\(successMessage)\n\(errorText)")
        }
        return .error(errorText)
    }
}

struct KeyActionMenu: View {
    let key: GPGKey
    var onDelete: (() -> Void)?
    @Environment(KeyManagementViewModel.self) private var viewModel

    // Reserved feature: key certification/signing is kept in code but hidden from menu for now.
    private let isKeySigningMenuEnabled = false
    // Reserved feature: backup/restore flow is retained, only menu entry is hidden.
    private let isBackupRestoreMenuEnabled = false
    @State private var showingUploadSheet = false
    @State private var showingBackupSheet = false
    @State private var showingTrustSheet = false
    @State private var showingSigningSheet = false
    @State private var showingEditSheet = false
    @State private var pendingPassphraseAction: PassphraseAction?
    @State private var pendingPassphraseAllowsEmpty = true
    @State private var pendingYubiKeyPINAction: YubiKeyPINAction?
    @State private var pendingYubiKeyPINFileName = ""
    @State private var pendingUntrustedEncryptURLs: [URL] = []
    @State private var operationResults: [OperationResult] = []
    @State private var showingResultOverlay = false
    @State private var promptAlert: PromptAlertContent?

    private var availability: KeyActionMenuAvailability {
        KeyActionMenuAvailability(
            key: key,
            isKeySigningMenuEnabled: isKeySigningMenuEnabled,
            isBackupRestoreMenuEnabled: isBackupRestoreMenuEnabled
        )
    }

    private enum PassphraseAction {
        case decrypt([URL])
        case signDetached([URL])
        case exportSecret(URL)
    }

    private enum YubiKeyPINAction {
        case decrypt([URL])
        case signDetached([URL])
    }

    var body: some View {
        Menu {
            Section {
                Button(action: encryptFromPicker) {
                    Label("action_encrypt", systemImage: "lock.fill")
                }
                Button(action: decryptFromPicker) {
                    Label("action_decrypt", systemImage: "lock.open.fill")
                }
                .disabled(!availability.canDecrypt)
                Button(action: signDetachedFromPicker) {
                    Label("action_sign_detached", systemImage: "signature")
                }
                .disabled(!availability.canSignDetached)
                if availability.showsSignKey {
                    Button(action: {
                        guard availability.canSignKey else { return }
                        showingSigningSheet = true
                    }) {
                        Label("action_sign_key", systemImage: "signature")
                    }
                    .disabled(!availability.canSignKey)
                }
                Button(action: verifyFromPicker) {
                    Label("action_verify_signature", systemImage: "checkmark.seal.fill")
                }
                Button(action: {
                    showingTrustSheet = true
                }) {
                    Label("trust_management_title", systemImage: "checkmark.shield")
                }
                Button(action: {
                    guard availability.canEdit else { return }
                    showingEditSheet = true
                }) {
                    Label("action_edit", systemImage: "pencil")
                }
                .disabled(!availability.canEdit)
            }

            Divider()

            Section {
                Button(action: {
                    showingUploadSheet = true
                }) {
                    Label("upload_to_keyserver_title", systemImage: "cloud.fill")
                }
                // Keep this block in place so backup/restore can be re-enabled by toggling
                // `isBackupRestoreMenuEnabled` without touching the flow implementation.
                if availability.showsBackupRestore {
                    Button(action: {
                        showingBackupSheet = true
                    }) {
                        Label("backup_title", systemImage: "externaldrive.fill")
                    }
                }
            }

            Divider()

            Section {
                Button(action: exportPublicKey) {
                    Label("action_export_public_key", systemImage: "square.and.arrow.up")
                }
                if availability.showsExportPrivateKey {
                    Button(action: exportPrivateKey) {
                        Label("action_export_private_key", systemImage: "key.fill")
                    }
                }
            }

            Divider()

            Section {
                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("action_delete_key", systemImage: "trash.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
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
        .sheet(
            isPresented: Binding(
                get: { pendingPassphraseAction != nil },
                set: {
                    if !$0 {
                        pendingPassphraseAction = nil
                        pendingPassphraseAllowsEmpty = true
                    }
                }
            )
        ) {
            PassphraseSheet(
                keyName: key.name,
                allowsEmptyPassphrase: pendingPassphraseAllowsEmpty,
                onConfirm: { passphrase in
                    guard let action = pendingPassphraseAction else { return }
                    pendingPassphraseAction = nil
                    pendingPassphraseAllowsEmpty = true
                    Task {
                        await executePassphraseAction(action, passphrase: passphrase)
                    }
                },
                onCancel: {
                    pendingPassphraseAction = nil
                    pendingPassphraseAllowsEmpty = true
                }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { pendingYubiKeyPINAction != nil },
                set: {
                    if !$0 {
                        pendingYubiKeyPINAction = nil
                        pendingYubiKeyPINFileName = ""
                    }
                }
            )
        ) {
            YubiKeyPINSheet(
                fileName: pendingYubiKeyPINFileName,
                onConfirm: { pin in
                    guard let action = pendingYubiKeyPINAction else { return }
                    pendingYubiKeyPINAction = nil
                    pendingYubiKeyPINFileName = ""
                    Task {
                        await executeYubiKeyPINAction(action, pin: pin)
                    }
                },
                onCancel: {
                    pendingYubiKeyPINAction = nil
                    pendingYubiKeyPINFileName = ""
                }
            )
        }
        .sheet(isPresented: $showingUploadSheet) {
            UploadToKeyserverSheet(
                key: key,
                onDismiss: {
                    showingUploadSheet = false
                },
                onSuccess: {
                    showingUploadSheet = false
                }
            )
            .environment(viewModel)
        }
        .sheet(isPresented: $showingSigningSheet) {
            KeySigningSheet(keyToSign: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingTrustSheet) {
            TrustManagementSheet(key: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingEditSheet) {
            KeyEditSheet(key: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingBackupSheet) {
            BackupManagerView()
                .environment(viewModel)
        }
    }

    private func encryptFromPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "drop_zone_hint")

        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }

        let intents = Array(repeating: KeyFileIntent.encrypt, count: selectedURLs.count)
        if KeyFileCryptoCoordinator.shouldRequireUntrustedRecipientConfirmation(
            intents: intents,
            keyIsSecret: key.isSecret,
            keyIsTrusted: key.isTrusted
        ) {
            presentUntrustedRecipientConfirmation(for: selectedURLs)
            return
        }

        Task {
            await encryptFiles(selectedURLs)
        }
    }

    private func decryptFromPicker() {
        guard KeyFileCryptoCoordinator.canPerform(.decrypt, keyIsSecret: key.isSecret) else {
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "drop_zone_hint")

        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }

        Task { @MainActor in
            if let hardwareTokenError = await KeyFileCryptoCoordinator.hardwareTokenPresenceErrorMessageIfNeeded(
                for: key,
                context: .decrypt
            ) {
                showError(
                    title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .decrypt)),
                    message: hardwareTokenError
                )
                return
            }

            if let mismatchMessage = await KeyFileCryptoCoordinator.decryptionKeyMismatchMessageIfNeeded(
                for: selectedURLs,
                preferredSecretKey: key.fingerprint,
                availableSecretKeys: viewModel.secretKeys
            ) {
                showError(
                    title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .decrypt)),
                    message: mismatchMessage
                )
                return
            }

            if key.isSmartCardStub {
                pendingYubiKeyPINFileName = selectedURLs.first?.lastPathComponent ?? ""
                pendingYubiKeyPINAction = .decrypt(selectedURLs)
                return
            }

            let requiresPassphrase = await KeyFileCryptoCoordinator.requiresPassphrase(for: key.fingerprint)
            if requiresPassphrase {
                pendingPassphraseAllowsEmpty = false
                pendingPassphraseAction = .decrypt(selectedURLs)
            } else {
                await decryptFiles(selectedURLs, passphrase: "")
            }
        }
    }

    private func signDetachedFromPicker() {
        guard key.isSecret else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "sign_detached_file_picker_message")

        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }

        Task { @MainActor in
            if let hardwareTokenError = await KeyFileCryptoCoordinator.hardwareTokenPresenceErrorMessageIfNeeded(
                for: key,
                context: .sign
            ) {
                showError(
                    title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .sign)),
                    message: hardwareTokenError
                )
                return
            }

            if key.isSmartCardStub {
                pendingYubiKeyPINFileName = selectedURLs.first?.lastPathComponent ?? ""
                pendingYubiKeyPINAction = .signDetached(selectedURLs)
                return
            }

            pendingPassphraseAllowsEmpty = true
            pendingPassphraseAction = .signDetached(selectedURLs)
        }
    }

    private func verifyFromPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "verify_file_picker_message")

        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }

        Task {
            await verifyFiles(selectedURLs)
        }
    }

    private func exportPublicKey() {
        guard let outputURL = presentExportPanel(defaultFileName: defaultPublicFileName) else { return }

        Task {
            await exportPublicKey(to: outputURL)
        }
    }

    private func exportPrivateKey() {
        guard key.isSecret else { return }
        guard let outputURL = presentExportPanel(defaultFileName: defaultPrivateFileName) else { return }
        pendingPassphraseAllowsEmpty = true
        pendingPassphraseAction = .exportSecret(outputURL)
    }

    @MainActor
    private func executePassphraseAction(_ action: PassphraseAction, passphrase: String) async {
        switch action {
        case .decrypt(let urls):
            await decryptFiles(urls, passphrase: passphrase)
        case .signDetached(let urls):
            await signFilesDetached(urls, passphrase: passphrase)
        case .exportSecret(let outputURL):
            await exportPrivateKey(to: outputURL, passphrase: passphrase)
        }
    }

    @MainActor
    private func executeYubiKeyPINAction(_ action: YubiKeyPINAction, pin: String) async {
        switch action {
        case .decrypt(let urls):
            await decryptFiles(urls, passphrase: pin)
        case .signDetached(let urls):
            await signFilesDetached(urls, passphrase: pin)
        }
    }

    @MainActor
    private func encryptFiles(_ urls: [URL], allowUntrustedRecipients: Bool = false) async {
        let requests = collectFileOperationRequests(
            from: urls,
            defaultOutputURLProvider: KeyActionFilePlanner.encryptedOutputURL(for:)
        )

        let outcomes = await KeyFileCryptoCoordinator.encrypt(
            requests: requests,
            recipientKey: key.fingerprint,
            allowUntrustedRecipients: allowUntrustedRecipients
        )
        showOperationResults(
            KeyFileOperationResultMapper.encryptResults(from: outcomes)
        )
    }

    @MainActor
    private func decryptFiles(_ urls: [URL], passphrase: String) async {
        let requests = collectFileOperationRequests(
            from: urls,
            defaultOutputURLProvider: KeyActionFilePlanner.decryptedOutputURL(for:)
        )

        let outcomes = await KeyFileCryptoCoordinator.decrypt(
            requests: requests,
            passphrase: passphrase,
            preferredSecretKey: key.fingerprint
        )
        showOperationResults(
            KeyFileOperationResultMapper.decryptResults(from: outcomes)
        )
    }

    @MainActor
    private func signFilesDetached(_ urls: [URL], passphrase: String) async {
        var signedFileCount = 0
        var failedFileCount = 0
        var firstError: Error?

        for url in urls {
            do {
                let defaultOutputURL = KeyActionFilePlanner.detachedSignatureOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    continue
                }
                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = outputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        outputURL.stopAccessingSecurityScopedResource()
                    }
                }

                _ = try await GPGService.shared.signFileDetached(
                    sourceURL: url,
                    destinationURL: outputURL,
                    keyID: key.fingerprint,
                    passphrase: passphrase
                )
                signedFileCount += 1
            } catch {
                failedFileCount += 1
                if firstError == nil {
                    firstError = error
                }
            }
        }

        showBatchOperationResult(
            successCount: signedFileCount,
            failureCount: failedFileCount,
            successMessage: String(localized: "operation_success_sign_detached"),
            firstError: firstError,
            errorContext: .sign,
            failureTitleKey: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .sign))
        )
    }

    @MainActor
    private func verifyFiles(_ urls: [URL]) async {
        var verifiedFileCount = 0
        var failedFileCount = 0
        var firstErrorMessage: String?
        var processedPaths = Set<String>()
        let selectedPathSet = Set(urls.map(\.path))

        let orderedURLs = urls.sorted { lhs, rhs in
            lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
        }

        for url in orderedURLs {
            if processedPaths.contains(url.path) {
                continue
            }

            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "sig" || fileExtension == "asc" {
                let signedFileURL = url.deletingPathExtension()
                if selectedPathSet.contains(signedFileURL.path) {
                    processedPaths.insert(signedFileURL.path)
                }
            } else {
                let signatureURLs = [
                    url.appendingPathExtension("sig"),
                    url.appendingPathExtension("asc")
                ]
                for signatureURL in signatureURLs where selectedPathSet.contains(signatureURL.path) {
                    processedPaths.insert(signatureURL.path)
                }
            }

            processedPaths.insert(url.path)

            do {
                _ = try await GPGService.shared.verifySignatureFile(at: url)
                verifiedFileCount += 1
            } catch {
                failedFileCount += 1
                if firstErrorMessage == nil {
                    firstErrorMessage = UserFacingErrorMapper.message(for: error, context: .verify)
                }
            }
        }

        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: verifiedFileCount,
            failureCount: failedFileCount,
            successMessage: String(localized: "operation_success_verify"),
            firstErrorMessage: firstErrorMessage
        )

        switch decision {
        case .none:
            return
        case .success(let message):
            showSuccess(message: message)
        case .error(let message):
            showError(
                title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .verify)),
                message: message
            )
        }
    }

    @MainActor
    private func exportPublicKey(to outputURL: URL) async {
        do {
            let keyData = try await viewModel.exportPublicKey(key)
            try writeDataSafely(keyData, to: outputURL)
            showSuccess(message: String(localized: "export_public_key_success_message"))
        } catch {
            showError(
                title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .exportKey)),
                message: UserFacingErrorMapper.message(for: error, context: .exportKey)
            )
        }
    }

    @MainActor
    private func exportPrivateKey(to outputURL: URL, passphrase: String) async {
        do {
            let keyData = try await viewModel.exportSecretKey(key, passphrase: passphrase)
            try writeDataSafely(keyData, to: outputURL)
            showSuccess(message: String(localized: "export_private_key_success_message"))
        } catch {
            showError(
                title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .exportKey)),
                message: UserFacingErrorMapper.message(for: error, context: .exportKey)
            )
        }
    }

    private func writeDataSafely(_ data: Data, to url: URL) throws {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func presentExportPanel(defaultFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "asc") ?? .data]
        panel.nameFieldStringValue = defaultFileName
        panel.message = String(localized: "export_file_picker_message")
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func presentFileOperationSavePanel(defaultFileName: String, preferredDirectory: URL) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFileName
        panel.directoryURL = preferredDirectory
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func collectFileOperationRequests(
        from urls: [URL],
        defaultOutputURLProvider: (URL) -> URL
    ) -> [KeyFileOperationRequest] {
        var requests: [KeyFileOperationRequest] = []
        requests.reserveCapacity(urls.count)

        for url in urls {
            let defaultOutputURL = defaultOutputURLProvider(url)
            guard let outputURL = presentFileOperationSavePanel(
                defaultFileName: defaultOutputURL.lastPathComponent,
                preferredDirectory: url.deletingLastPathComponent()
            ) else {
                continue
            }
            requests.append(
                KeyFileOperationRequest(
                    sourceURL: url,
                    destinationURL: outputURL
                )
            )
        }

        return requests
    }

    private func presentUntrustedRecipientConfirmation(for urls: [URL]) {
        pendingUntrustedEncryptURLs = urls
        promptAlert = PromptAlertContent.destructiveConfirmation(
            title: "encrypt_untrusted_recipient_title",
            message: String(localized: "encrypt_untrusted_recipient_message"),
            onConfirm: {
                let selectedURLs = pendingUntrustedEncryptURLs
                pendingUntrustedEncryptURLs = []
                Task {
                    await encryptFiles(selectedURLs, allowUntrustedRecipients: true)
                }
            },
            onCancel: {
                pendingUntrustedEncryptURLs = []
            },
            onDismiss: {
                pendingUntrustedEncryptURLs = []
            }
        )
    }

    private var defaultPublicFileName: String {
        KeyActionFilePlanner.defaultPublicFileName(for: key.name)
    }

    private var defaultPrivateFileName: String {
        KeyActionFilePlanner.defaultPrivateFileName(for: key.name)
    }

    private func showSuccess(message: String) {
        promptAlert = PromptAlertContent.success(
            message: message
        )
    }

    private func showBatchOperationResult(
        successCount: Int,
        failureCount: Int,
        successMessage: String,
        firstError: Error?,
        errorContext: UserFacingErrorContext,
        failureTitleKey: LocalizedStringKey
    ) {
        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: successCount,
            failureCount: failureCount,
            successMessage: successMessage,
            firstErrorMessage: firstError.map {
                UserFacingErrorMapper.message(for: $0, context: errorContext)
            }
        )

        switch decision {
        case .none:
            return
        case .success(let message):
            showSuccess(message: message)
        case .error(let message):
            showError(title: failureTitleKey, message: message)
        }
    }

    private func showError(title: LocalizedStringKey, message: String) {
        promptAlert = PromptAlertContent.failure(
            title: title,
            message: message
        )
    }

    private func showOperationResults(_ results: [OperationResult]) {
        guard !results.isEmpty else { return }
        operationResults = results
        showingResultOverlay = true
    }
}

#Preview {
    KeyActionMenu(key: GPGKey(
        id: "test",
        keyID: "ABC123",
        fingerprint: "1234 5678 90AB CDEF 1234 5678 90AB CDEF 1234 5678",
        name: "Test User",
        email: "test@example.com",
        algorithm: "RSA",
        keyLength: 4096,
        isSecret: false,
        createdAt: Date(),
        expiresAt: nil,
        trustLevel: .full
    ))
    .environment(KeyManagementViewModel())
}
