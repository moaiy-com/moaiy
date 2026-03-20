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
    
    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                
                Picker("Default Key Type", selection: $defaultKeyType) {
                    Text("RSA-4096").tag(0)
                    Text("RSA-2048").tag(1)
                    Text("ECC (Curve25519)").tag(2)
                }
            } header: {
                Text("General")
                    .font(.headline)
            }
            
            Section {
                Toggle("Auto Backup", isOn: $autoBackup)
                
                if autoBackup {
                    Picker("Backup Frequency", selection: $backupFrequency) {
                        Text("Daily").tag(0)
                        Text("Weekly").tag(1)
                        Text("Monthly").tag(2)
                    }
                }
            } header: {
                Text("Backup")
                    .font(.headline)
            }
            
            Section {
                Picker("Encryption Algorithm", selection: $encryptionAlgorithm) {
                    Text("AES-256").tag(0)
                    Text("AES-192").tag(1)
                    Text("AES-128").tag(2)
                }
                
                Picker("File Naming", selection: $fileNaming) {
                    Text("filename.gpg").tag(0)
                    Text("filename.asc").tag(1)
                    Text("Custom").tag(2)
                }
            } header: {
                Text("Encryption")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 400)
    }
}

#Preview {
    SettingsView()
        .frame(width: 500, height: 500)
}
