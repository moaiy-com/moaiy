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

    static func nonConflictingURL(for desiredURL: URL, fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: desiredURL.path) else {
            return desiredURL
        }

        let ext = desiredURL.pathExtension
        let baseName = ext.isEmpty
            ? desiredURL.lastPathComponent
            : String(desiredURL.lastPathComponent.dropLast(ext.count + 1))
        let directory = desiredURL.deletingLastPathComponent()

        var index = 1
        while true {
            let candidateName = ext.isEmpty
                ? "\(baseName) (\(index))"
                : "\(baseName) (\(index)).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            index += 1
        }
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

enum KeyActionAlertDecision: Equatable {
    case none
    case success(String)
    case error(String)
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
    // Reserved feature: backup & restore flow is kept in code but hidden from the menu for now.
    private let isBackupRestoreMenuEnabled = false

    @State private var showingUploadSheet = false
    @State private var showingBackupSheet = false
    @State private var showingTrustSheet = false
    @State private var showingSigningSheet = false
    @State private var showingEditSheet = false
    @State private var pendingPassphraseAction: PassphraseAction?
    @State private var alertTitle: LocalizedStringKey = "operation_success"
    @State private var alertMessage = ""
    @State private var showingAlert = false

    private enum PassphraseAction {
        case decrypt([URL])
        case signDetached([URL])
        case exportSecret(URL)
    }

    var body: some View {
        Menu {
            Section {
                Button(action: encryptFromPicker) {
                    Label("action_encrypt", systemImage: "lock.fill")
                        .font(.system(size: 14))
                }
                Button(action: decryptFromPicker) {
                    Label("action_decrypt", systemImage: "lock.open.fill")
                        .font(.system(size: 14))
                }
                .disabled(!key.isSecret)
                Button(action: signDetachedFromPicker) {
                    Label("action_sign_detached", systemImage: "signature")
                        .font(.system(size: 14))
                }
                .disabled(!key.isSecret)
                if isKeySigningMenuEnabled {
                    Button(action: {
                        guard key.isSecret else { return }
                        showingSigningSheet = true
                    }) {
                        Label("action_sign_key", systemImage: "signature")
                            .font(.system(size: 14))
                    }
                    .disabled(!key.isSecret)
                }
                Button(action: verifyFromPicker) {
                    Label("action_verify_signature", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 14))
                }
                Button(action: {
                    showingTrustSheet = true
                }) {
                    Label("trust_management_title", systemImage: "checkmark.shield")
                        .font(.system(size: 14))
                }
                Button(action: {
                    guard key.isSecret else { return }
                    showingEditSheet = true
                }) {
                    Label("action_edit", systemImage: "pencil")
                        .font(.system(size: 14))
                }
                .disabled(!key.isSecret)
            }

            Divider()

            Section {
                Button(action: {
                    showingUploadSheet = true
                }) {
                    Label("upload_to_keyserver_title", systemImage: "cloud.fill")
                        .font(.system(size: 14))
                }
                if isBackupRestoreMenuEnabled {
                    Button(action: {
                        showingBackupSheet = true
                    }) {
                        Label("backup_title", systemImage: "externaldrive.fill")
                            .font(.system(size: 14))
                    }
                }
            }

            Divider()

            Section {
                Button(action: exportPublicKey) {
                    Label("action_export_public_key", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14))
                }
                if key.isSecret {
                    Button(action: exportPrivateKey) {
                        Label("action_export_private_key", systemImage: "key.fill")
                            .font(.system(size: 14))
                    }
                }
            }

            Divider()

            Section {
                Button(role: .destructive, action: {
                    onDelete?()
                }) {
                    Label("action_delete_key", systemImage: "trash.fill")
                        .font(.system(size: 14))
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .sheet(
            isPresented: Binding(
                get: { pendingPassphraseAction != nil },
                set: { if !$0 { pendingPassphraseAction = nil } }
            )
        ) {
            PassphraseSheet(
                keyName: key.name,
                allowsEmptyPassphrase: true,
                onConfirm: { passphrase in
                    guard let action = pendingPassphraseAction else { return }
                    pendingPassphraseAction = nil
                    Task {
                        await executePassphraseAction(action, passphrase: passphrase)
                    }
                },
                onCancel: {
                    pendingPassphraseAction = nil
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
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("action_ok", role: .cancel) { }
        } message: {
            Text(alertMessage)
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

        Task {
            await encryptFiles(selectedURLs)
        }
    }

    private func decryptFromPicker() {
        guard key.isSecret else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = String(localized: "drop_zone_hint")

        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }

        pendingPassphraseAction = .decrypt(selectedURLs)
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

        pendingPassphraseAction = .signDetached(selectedURLs)
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
    private func encryptFiles(_ urls: [URL]) async {
        var encryptedFileCount = 0
        var failedFileCount = 0
        var firstError: Error?

        for url in urls {
            do {
                let defaultOutputURL = KeyActionFilePlanner.encryptedOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    continue
                }
                let plannedOutputURL = KeyActionFilePlanner.nonConflictingURL(for: outputURL)

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = plannedOutputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        plannedOutputURL.stopAccessingSecurityScopedResource()
                    }
                }

                _ = try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: plannedOutputURL,
                    recipients: [key.fingerprint]
                )
                encryptedFileCount += 1
            } catch {
                failedFileCount += 1
                if firstError == nil {
                    firstError = error
                }
            }
        }

        showBatchOperationResult(
            successCount: encryptedFileCount,
            failureCount: failedFileCount,
            successMessage: String(localized: "operation_success_encrypt"),
            firstError: firstError,
            errorContext: .encrypt,
            failureTitleKey: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .encrypt))
        )
    }

    @MainActor
    private func decryptFiles(_ urls: [URL], passphrase: String) async {
        var decryptedFileCount = 0
        var failedFileCount = 0
        var firstError: Error?

        for url in urls {
            do {
                let defaultOutputURL = KeyActionFilePlanner.decryptedOutputURL(for: url)
                guard let outputURL = presentFileOperationSavePanel(
                    defaultFileName: defaultOutputURL.lastPathComponent,
                    preferredDirectory: url.deletingLastPathComponent()
                ) else {
                    continue
                }
                let plannedOutputURL = KeyActionFilePlanner.nonConflictingURL(for: outputURL)

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = plannedOutputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        plannedOutputURL.stopAccessingSecurityScopedResource()
                    }
                }

                _ = try await GPGService.shared.decryptFile(
                    sourceURL: url,
                    destinationURL: plannedOutputURL,
                    passphrase: passphrase
                )
                decryptedFileCount += 1
            } catch {
                failedFileCount += 1
                if firstError == nil {
                    firstError = error
                }
            }
        }

        showBatchOperationResult(
            successCount: decryptedFileCount,
            failureCount: failedFileCount,
            successMessage: String(localized: "operation_success_decrypt"),
            firstError: firstError,
            errorContext: .decrypt,
            failureTitleKey: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: .decrypt))
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
                let plannedOutputURL = KeyActionFilePlanner.nonConflictingURL(for: outputURL)

                let hasSourceAccess = url.startAccessingSecurityScopedResource()
                let hasOutputAccess = plannedOutputURL.startAccessingSecurityScopedResource()
                defer {
                    if hasSourceAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    if hasOutputAccess {
                        plannedOutputURL.stopAccessingSecurityScopedResource()
                    }
                }

                _ = try await GPGService.shared.signFileDetached(
                    sourceURL: url,
                    destinationURL: plannedOutputURL,
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
            showSuccess(message: String(localized: "action_export_public_key"))
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
            showSuccess(message: String(localized: "action_export_private_key"))
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

    private var defaultPublicFileName: String {
        KeyActionFilePlanner.defaultPublicFileName(for: key.name)
    }

    private var defaultPrivateFileName: String {
        KeyActionFilePlanner.defaultPrivateFileName(for: key.name)
    }

    private func showSuccess(message: String) {
        alertTitle = "operation_success"
        alertMessage = message
        showingAlert = true
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
        alertTitle = title
        alertMessage = message
        showingAlert = true
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
