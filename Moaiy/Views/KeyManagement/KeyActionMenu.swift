//
//  KeyActionMenu.swift
//  Moaiy
//
//  Menu component for key actions (encrypt, decrypt, sign, verify, backup, upload, delete)
//

import SwiftUI
import UniformTypeIdentifiers

struct KeyActionMenu: View {
    let key: GPGKey
    var onDelete: (() -> Void)?
    @Environment(KeyManagementViewModel.self) private var viewModel

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
        case exportSecret(URL)
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
                .disabled(!key.isSecret)
                Button(action: {
                    showingSigningSheet = true
                }) {
                    Label("action_sign_key", systemImage: "signature")
                }
                Button(action: {
                    showingTrustSheet = true
                }) {
                    Label("trust_management_title", systemImage: "checkmark.shield")
                }
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("action_edit", systemImage: "pencil")
                }
            }

            Divider()

            Section {
                Button(action: {
                    showingUploadSheet = true
                }) {
                    Label("upload_to_keyserver_title", systemImage: "cloud.fill")
                }
                Button(action: {
                    showingBackupSheet = true
                }) {
                    Label("backup_title", systemImage: "externaldrive.fill")
                }
            }

            Divider()

            Section {
                Button(action: exportPublicKey) {
                    Label("action_export_public_key", systemImage: "square.and.arrow.up")
                }
                if key.isSecret {
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
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .sheet(
            isPresented: Binding(
                get: { pendingPassphraseAction != nil },
                set: { if !$0 { pendingPassphraseAction = nil } }
            )
        ) {
            PassphraseSheet(
                keyName: key.name,
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
        case .exportSecret(let outputURL):
            await exportPrivateKey(to: outputURL, passphrase: passphrase)
        }
    }

    @MainActor
    private func encryptFiles(_ urls: [URL]) async {
        do {
            for url in urls {
                let outputURL = url.appendingPathExtension("gpg")
                try await GPGService.shared.encryptFile(
                    sourceURL: url,
                    destinationURL: outputURL,
                    recipients: [key.fingerprint]
                )
            }
            showSuccess(message: String(localized: "operation_success_encrypt"))
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    @MainActor
    private func decryptFiles(_ urls: [URL], passphrase: String) async {
        do {
            for url in urls {
                let outputURL: URL
                if url.pathExtension.isEmpty {
                    outputURL = url.appendingPathExtension("decrypted")
                } else {
                    outputURL = url.deletingPathExtension()
                }

                try await GPGService.shared.decryptFile(
                    sourceURL: url,
                    destinationURL: outputURL,
                    passphrase: passphrase
                )
            }
            showSuccess(message: String(localized: "operation_success_decrypt"))
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    @MainActor
    private func exportPublicKey(to outputURL: URL) async {
        do {
            let keyData = try await viewModel.exportPublicKey(key)
            try writeDataSafely(keyData, to: outputURL)
            showSuccess(message: String(localized: "action_export_public_key"))
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    @MainActor
    private func exportPrivateKey(to outputURL: URL, passphrase: String) async {
        do {
            let keyData = try await viewModel.exportSecretKey(key, passphrase: passphrase)
            try writeDataSafely(keyData, to: outputURL)
            showSuccess(message: String(localized: "action_export_private_key"))
        } catch {
            showError(message: error.localizedDescription)
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

    private var defaultPublicFileName: String {
        "\(sanitizedKeyName)_public.asc"
    }

    private var defaultPrivateFileName: String {
        "\(sanitizedKeyName)_private.asc"
    }

    private var sanitizedKeyName: String {
        key.name.replacingOccurrences(of: " ", with: "_")
    }

    private func showSuccess(message: String) {
        alertTitle = "operation_success"
        alertMessage = message
        showingAlert = true
    }

    private func showError(message: String) {
        alertTitle = "error_occurred"
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
