//
//  SettingsView.swift
//  Moaiy
//
//  Application settings view
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("defaultKeyType") private var defaultKeyType = 0
    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage("backupFrequency") private var backupFrequency = 1
    @AppStorage("encryptionAlgorithm") private var encryptionAlgorithm = 0
    @AppStorage("fileNaming") private var fileNaming = 0

    @State private var showingBackupManager = false
    
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
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
        .sheet(isPresented: $showingBackupManager) {
            BackupManagerView()
                .environment(KeyManagementViewModel())
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
