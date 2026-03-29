//
//  BackupSheet.swift
//  Moaiy
//
//  Sheet for backing up keys
//

import SwiftUI

struct BackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    @State private var selectedKeys: Set<GPGKey> = []
    @State private var backupLocation: URL?
    @State private var isBackingUp = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("backup_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("action_cancel") {
                    dismiss()
                }
            }
            
            Text("backup_description")
                .font(.body)
                .foregroundStyle(.secondary)
            
            List(viewModel.keys.filter { $0.isSecret }, selection: $selectedKeys) { key in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { selectedKeys.contains(key) },
                        set: { if $0 {
                            selectedKeys.insert(key)
                        } else {
                            selectedKeys.remove(key)
                        }
                    })
                    
                    VStack(alignment: .leading) {
                        Text(key.name)
                            .font(.headline)
                        Text(key.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            HStack {
                Button("backup_select_all") {
                    selectedKeys = Set(viewModel.keys.filter { $0.isSecret })
                }
                Button("backup_select_none") {
                    selectedKeys = []
                }
            }
            
            HStack {
                Text("backup_location")
                    .font(.headline)
                Spacer()
                Button("backup_choose_location") {
                    chooseBackupLocation()
                }
            }
            
            if let location = backupLocation {
                Text(location.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("action_cancel") {
                    dismiss()
                }
                Button("action_backup") {
                    performBackup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedKeys.isEmpty || backupLocation == nil)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func chooseBackupLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = String(localized: "backup_choose_location_message")
        
        if panel.runModal() == .OK, let url = panel.url {
            backupLocation = url
        }
    }
    
    private func performBackup() {
        guard !selectedKeys.isEmpty, let location = backupLocation else { return }
        
        isBackingUp = true
        
        Task {
            for key in selectedKeys {
                do {
                    try await viewModel.exportPrivateKey(key: key, to: location)
                }
            }
            
            isBackingUp = false
            dismiss()
        }
    }
}
