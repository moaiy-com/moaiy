//
//  SettingsView.swift
//  Moaiy
//
//  Application settings view
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("defaultKeyType") private var defaultKeyType = 0
    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage("backupFrequency") private var backupFrequency = 1
    @AppStorage("encryptionAlgorithm") private var encryptionAlgorithm = 0
    @AppStorage("fileNaming") private var fileNaming = 0

    @State private var showingBackupManager = false
    @State private var gpgVersion: String = ""
    @State private var activeGPGHomePath: String = ""
    @State private var isUsingExternalGPGHome = false
    @State private var keyringError: String?
    @State private var isSwitchingKeyring = false
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        Form {
            Section {
                Picker("setting_theme", selection: $appearance) {
                    Text("theme_system").tag(0)
                    Text("theme_light").tag(1)
                    Text("theme_dark").tag(2)
                }
                
                Picker("setting_default_key_type", selection: $defaultKeyType) {
                    Text("key_type_rsa4096").tag(0)
                    Text("key_type_rsa2048").tag(1)
                    Text("key_type_ecc_curve25519").tag(2)
                }
            } header: {
                Text("section_general")
                    .font(.headline)
            }
            
            Section {
                Toggle("setting_auto_backup", isOn: $autoBackup)

                if autoBackup {
                    Picker("setting_backup_frequency", selection: $backupFrequency) {
                        Text("frequency_daily").tag(0)
                        Text("frequency_weekly").tag(1)
                        Text("frequency_monthly").tag(2)
                    }
                }

                Button(action: { showingBackupManager = true }) {
                    HStack {
                        Label("setting_backup_manager", systemImage: "externaldrive.fill.badge.icloud")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("section_backup")
                    .font(.headline)
            }
            
            Section {
                Picker("setting_encryption_algorithm", selection: $encryptionAlgorithm) {
                    Text("algorithm_aes256").tag(0)
                    Text("algorithm_aes192").tag(1)
                    Text("algorithm_aes128").tag(2)
                }
                
                Picker("setting_file_naming", selection: $fileNaming) {
                    Text("naming_filename_gpg").tag(0)
                    Text("naming_filename_asc").tag(1)
                    Text("naming_custom").tag(2)
                }
            } header: {
                Text("section_encryption")
                    .font(.headline)
            }

            Section {
                HStack(alignment: .top) {
                    Text("setting_keyring_mode")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isUsingExternalGPGHome {
                        Text("setting_keyring_mode_external")
                            .foregroundStyle(.primary)
                    } else {
                        Text("setting_keyring_mode_app")
                            .foregroundStyle(.primary)
                    }
                }

                HStack(alignment: .top) {
                    Text("setting_keyring_path")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if activeGPGHomePath.isEmpty {
                        Text("setting_keyring_path_unavailable")
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(activeGPGHomePath)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }

                Button("action_select_external_keyring") {
                    chooseExternalKeyringFolder()
                }
                .disabled(isSwitchingKeyring)

                if isUsingExternalGPGHome {
                    Button("action_use_app_managed_keyring") {
                        Task {
                            await switchToAppManagedKeyring()
                        }
                    }
                    .disabled(isSwitchingKeyring)
                }

                if let keyringError {
                    Text(keyringError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("section_keyring")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Text("about_app_version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(appVersion) (\(appBuild))")
                        .foregroundStyle(.primary)
                }
                
                HStack {
                    Text("about_gpg_version")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if gpgVersion.isEmpty {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Text(gpgVersion)
                            .foregroundStyle(.primary)
                    }
                }
            } header: {
                Text("section_about")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .task {
            await loadGPGVersion()
            refreshKeyringState()
        }
        .sheet(isPresented: $showingBackupManager) {
            BackupManagerView()
                .environment(AppState.shared.keyManagement)
        }
    }
    
    @MainActor
    private func loadGPGVersion() async {
        let service = GPGService.shared
        if let version = service.gpgVersion {
            gpgVersion = version
        } else {
            gpgVersion = "about_gpg_not_available"
        }
    }

    @MainActor
    private func refreshKeyringState() {
        let service = GPGService.shared
        activeGPGHomePath = service.activeGPGHomePath
        isUsingExternalGPGHome = service.isUsingExternalGPGHome
    }

    private func chooseExternalKeyringFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = GPGService.shared.systemGPGHomeURL.deletingLastPathComponent()
        panel.message = String(localized: "setting_keyring_picker_message")
        panel.prompt = String(localized: "action_select_external_keyring")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await useExternalKeyring(at: url)
        }
    }

    @MainActor
    private func useExternalKeyring(at url: URL) async {
        isSwitchingKeyring = true
        keyringError = nil

        do {
            try GPGService.shared.configureExternalGPGHome(url)
            await AppState.shared.keyManagement.refresh()
            refreshKeyringState()
        } catch {
            keyringError = error.localizedDescription
        }

        isSwitchingKeyring = false
    }

    @MainActor
    private func switchToAppManagedKeyring() async {
        isSwitchingKeyring = true
        keyringError = nil

        do {
            try GPGService.shared.useAppManagedGPGHome()
            await AppState.shared.keyManagement.refresh()
            refreshKeyringState()
        } catch {
            keyringError = error.localizedDescription
        }

        isSwitchingKeyring = false
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
