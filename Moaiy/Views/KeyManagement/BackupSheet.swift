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
        VStack(spacing: MoaiyUI.Spacing.xl) {
            HStack {
                Text("backup_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.moaiyTextPrimary)
                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("backup_description")
                .font(.body)
                .foregroundStyle(Color.moaiyTextSecondary)
            
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
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            
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
                    .foregroundStyle(Color.moaiyTextSecondary)
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
                .tint(Color.moaiyAccentV2)
                .disabled(selectedKeys.isEmpty || backupLocation == nil)
            }
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 440, idealWidth: 540, maxWidth: 720, minHeight: 360, idealHeight: 460)
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
