//
//  KeyDetailView.swift
//  Moaiy
//
//  Key detail view showing comprehensive key information
//

import SwiftUI

struct KeyDetailView: View {
    let key: GPGKey
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    @State private var showingExportSheet = false
    @State private var showingDeleteSheet = false
    @State private var showingTrustManagement = false
    @State private var showingKeySigning = false
    @State private var showingKeyEdit = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismissNavigation
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                KeyDetailHeader(key: key)

                // Status Section
                KeyStatusSection(key: key, showingTrustManagement: $showingTrustManagement)

                // Actions
                KeyActionsSection(
                    key: key,
                    showingExportSheet: $showingExportSheet,
                    showingDeleteSheet: $showingDeleteSheet,
                    showingKeySigning: $showingKeySigning,
                    isDeleting: $isDeleting
                )
            }
            .padding()
        }
        .navigationTitle(key.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showingKeyEdit = true }) {
                    Label("action_edit", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingExportSheet = true }) {
                    Label("action_export_public_key", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportKeySheet(key: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingTrustManagement) {
            TrustManagementSheet(key: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingKeySigning) {
            KeySigningSheet(keyToSign: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingKeyEdit) {
            KeyEditSheet(key: key)
                .environment(viewModel)
        }
        .sheet(isPresented: $showingDeleteSheet) {
            DeleteKeySheet(
                key: key,
                isPresented: $showingDeleteSheet,
                isDeleting: $isDeleting,
                deleteError: $deleteError,
                onDeleteSuccess: { dismissNavigation() }
            )
                .environment(viewModel)
        }
        .alert("error_delete_failed", isPresented: .constant(deleteError != nil)) {
            Button("action_ok") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
    }
}

// MARK: - Header Section

struct KeyDetailHeader: View {
    let key: GPGKey
    
    var body: some View {
        HStack(spacing: 16) {
            // Key icon
            ZStack {
                Circle()
                    .fill(key.isSecret ? Color.moaiyAccentV2.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: key.isSecret ? "key.fill" : "key")
                    .font(.title)
                    .foregroundStyle(key.isSecret ? Color.moaiyAccentV2 : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(key.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Key type badge
                    Text(key.isSecret ? "key_type_private" : "key_type_public")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(keyTypeBadgeColor.opacity(0.2))
                        .foregroundStyle(keyTypeBadgeColor)
                        .clipShape(Capsule())
                }
                
                Text(key.email)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status indicators
            VStack(alignment: .trailing, spacing: 8) {
                if key.isExpired {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("status_expired")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                if key.isTrusted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("status_trusted")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var keyTypeBadgeColor: Color {
        key.isSecret ? Color.moaiyAccentV2 : .blue
    }
}

// MARK: - Status Section

struct KeyStatusSection: View {
    let key: GPGKey
    @Binding var showingTrustManagement: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Trust status
            HStack(spacing: 12) {
                Image(systemName: trustIcon)
                    .font(.title2)
                    .foregroundStyle(trustColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(key.trustLevel.localizedName)
                        .font(.headline)
                    Text(key.trustLevel.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("action_manage") {
                    showingTrustManagement = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Expiration status
            if key.isExpired {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("status_expired")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text("message_key_expired_description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            } else if let expiresAt = key.expiresAt {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("label_expires")
                            .font(.headline)
                        Text(expiresAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Capabilities
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color.moaiyAccentV2)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("label_capabilities")
                        .font(.headline)
                    HStack(spacing: 8) {
                        CapabilityBadge(name: "Encrypt", icon: "lock.fill")
                        CapabilityBadge(name: "Sign", icon: "signature")
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var trustIcon: String {
        switch key.trustLevel {
        case .ultimate: return "checkmark.seal.fill"
        case .full: return "checkmark.circle.fill"
        case .marginal: return "questionmark.circle.fill"
        case .none: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var trustColor: Color {
        switch key.trustLevel {
        case .ultimate: return .green
        case .full: return .blue
        case .marginal: return .orange
        case .none: return .red
        case .unknown: return .secondary
        }
    }
}

// MARK: - Actions Section

struct KeyActionsSection: View {
    let key: GPGKey
    @Binding var showingExportSheet: Bool
    @Binding var showingDeleteSheet: Bool
    @Binding var showingKeySigning: Bool
    @Binding var isDeleting: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Primary actions
            Button(action: { }) {
                Label("action_encrypt_file", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Secondary actions
            HStack(spacing: 12) {
                Button(action: { showingExportSheet = true }) {
                    Label("action_share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: { showingKeySigning = true }) {
                    Label("sign_key_button", systemImage: "signature")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Destructive action
            Button(role: .destructive, action: { showingDeleteSheet = true }) {
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("action_delete_key", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
            .disabled(isDeleting)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

struct CapabilityBadge: View {
    let name: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.moaiyAccentV2.opacity(0.1))
        .foregroundStyle(Color.moaiyAccentV2)
        .clipShape(Capsule())
    }
}

struct ExportKeySheet: View {
    let key: GPGKey
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    @State private var isExporting = false
    @State private var exportError: String?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.moaiyAccentV2)

                Text("action_export_public_key")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("export_key_description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Key info
            VStack(spacing: 8) {
                HStack {
                    Text("label_key_id")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(key.keyID)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("field_name")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(key.name)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("field_email")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(key.email)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Error message
            if let error = exportError {
                ErrorBanner(message: error)
            }
            
            // Actions
            VStack(spacing: 12) {
                Button(action: saveToFile) {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("action_save_to_file", systemImage: "doc.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isExporting)
                
                Button(action: copyToClipboard) {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("action_copy_to_clipboard", systemImage: "doc.on.clipboard")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isExporting)
                
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .moaiyModalAdaptiveSize(minWidth: 400, idealWidth: 500, maxWidth: 660)
    }
    
    private func saveToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "asc") ?? .item]
        panel.nameFieldStringValue = "\(key.name.replacingOccurrences(of: " ", with: "_"))_public.asc"
        panel.message = String(localized: "export_file_picker_message")
        
        if panel.runModal() == .OK, let url = panel.url {
            exportAndSave(to: url)
        }
    }
    
    private func exportAndSave(to url: URL) {
        isExporting = true
        exportError = nil

        Task { @MainActor in
            do {
                let keyData = try await viewModel.exportPublicKey(key)

                // Write to file
                guard url.startAccessingSecurityScopedResource() else {
                    throw GPGError.fileAccessDenied(url.path)
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                try keyData.write(to: url)

                isExporting = false
                dismiss()
            } catch {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }
    
    private func copyToClipboard() {
        isExporting = true
        exportError = nil

        Task { @MainActor in
            do {
                let keyData = try await viewModel.exportPublicKey(key)

                guard let keyString = String(data: keyData, encoding: .utf8) else {
                    throw GPGError.exportFailed("Failed to convert key to text")
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(keyString, forType: .string)

                isExporting = false
                dismiss()
            } catch {
                exportError = error.localizedDescription
                isExporting = false
            }
        }
    }
}

// MARK: - Delete Key Sheet

enum DeleteKeyOption: String, Identifiable {
    case secretOnly
    case publicOnly
    case both

    var id: String { rawValue }
}

struct DeleteKeySheet: View {
    let key: GPGKey
    @Binding var isPresented: Bool
    @Binding var isDeleting: Bool
    @Binding var deleteError: String?
    var onDeleteSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel
    @State private var selectedOption: DeleteKeyOption = .both

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "trash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("action_delete_key")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("delete_key_select_option")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Key info
            VStack(spacing: 8) {
                HStack {
                    Text("field_name")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(key.name)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("field_email")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(key.email)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Delete options
            VStack(spacing: 12) {
                Text(key.isSecret ? "delete_key_has_secret" : "delete_key_public_only")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if key.isSecret {
                    // Option 1: Private key only
                    DeleteOptionRow(
                        title: "delete_option_private",
                        description: "delete_option_private_description",
                        icon: "key.fill",
                        color: .orange,
                        isSelected: selectedOption == .secretOnly
                    ) {
                        selectedOption = .secretOnly
                    }

                    // Option 2: Public key only
                    DeleteOptionRow(
                        title: "delete_option_public",
                        description: "delete_option_public_description",
                        icon: "key",
                        color: .blue,
                        isSelected: selectedOption == .publicOnly
                    ) {
                        selectedOption = .publicOnly
                    }

                    // Option 3: Both keys
                    DeleteOptionRow(
                        title: "delete_option_both",
                        description: "delete_option_both_description",
                        icon: "trash.fill",
                        color: .red,
                        isSelected: selectedOption == .both
                    ) {
                        selectedOption = .both
                    }
                } else {
                    // Public key only - single option
                    DeleteOptionRow(
                        title: "delete_option_public",
                        description: "delete_option_public_description",
                        icon: "key",
                        color: .red,
                        isSelected: true
                    ) { }
                }
            }

            // Warning
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("delete_key_warning")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions
            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isDeleting)

                Button(role: .destructive) {
                    performDelete()
                } label: {
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("action_delete")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isDeleting)
            }
        }
        .padding(32)
        .moaiyModalAdaptiveSize(minWidth: 420, idealWidth: 520, maxWidth: 700)
    }

    private func performDelete() {
        isDeleting = true
        deleteError = nil

        Task { @MainActor in
            do {
                try await viewModel.deleteKey(key, option: selectedOption)
                isDeleting = false
                dismiss()
                onDeleteSuccess?()
            } catch {
                deleteError = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

struct DeleteOptionRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                }
            }
            .padding(12)
            .background(isSelected ? color.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Key Detail") {
    let sampleKey = GPGKey(
        id: "test",
        keyID: "ABC12345",
        fingerprint: "1234567890ABCDEF1234567890ABCDEF12345678",
        name: "Test User",
        email: "test@example.com",
        algorithm: "RSA",
        keyLength: 4096,
        isSecret: true,
        createdAt: Date(),
        expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
        trustLevel: .ultimate
    )
    
    NavigationStack {
        KeyDetailView(key: sampleKey)
    }
    .frame(width: 800, height: 900)
}
