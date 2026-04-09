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
            VStack(spacing: MoaiyUI.Spacing.xl) {
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
            .padding(MoaiyUI.Spacing.xxl)
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
        HStack(spacing: MoaiyUI.Spacing.lg) {
            // Key icon
            ZStack {
                Circle()
                    .fill(key.isSecret ? Color.moaiyAccentV2.opacity(0.1) : Color.moaiyInfo.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: key.isSecret ? "key.fill" : "key")
                    .font(.title)
                    .foregroundStyle(key.isSecret ? Color.moaiyAccentV2 : Color.moaiyInfo)
            }
            
            VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                HStack(spacing: MoaiyUI.Spacing.sm) {
                    Text(key.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    
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
                    .foregroundStyle(Color.moaiyTextSecondary)
            }
            
            Spacer()
            
            // Status indicators
            VStack(alignment: .trailing, spacing: MoaiyUI.Spacing.sm) {
                if key.isExpired {
                    HStack(spacing: MoaiyUI.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.moaiyError)
                        Text("status_expired")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyError)
                    }
                }
                
                if key.isTrusted {
                    HStack(spacing: MoaiyUI.Spacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.moaiySuccess)
                        Text("status_trusted")
                            .font(.caption)
                            .foregroundStyle(Color.moaiySuccess)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
    }
    
    private var keyTypeBadgeColor: Color {
        key.isSecret ? Color.moaiyAccentV2 : Color.moaiyInfo
    }
}

// MARK: - Status Section

struct KeyStatusSection: View {
    let key: GPGKey
    @Binding var showingTrustManagement: Bool

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.lg) {
            // Trust status
            HStack(spacing: MoaiyUI.Spacing.md) {
                Image(systemName: trustIcon)
                    .font(.title2)
                    .foregroundStyle(trustColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(key.trustLevel.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text(key.trustLevel.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                Spacer()

                Button("action_manage") {
                    showingTrustManagement = true
                }
                .buttonStyle(.bordered)
                .tint(Color.moaiyAccentV2)
                .controlSize(.small)
            }
            
            // Expiration status
            if key.isExpired {
                HStack(spacing: MoaiyUI.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyError)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("status_expired")
                            .font(.headline)
                            .foregroundStyle(Color.moaiyError)
                        Text("message_key_expired_description")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                    
                    Spacer()
                }
            } else if let expiresAt = key.expiresAt {
                HStack(spacing: MoaiyUI.Spacing.md) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyInfo)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("label_expires")
                            .font(.headline)
                            .foregroundStyle(Color.moaiyTextPrimary)
                        Text(expiresAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Capabilities
            HStack(spacing: MoaiyUI.Spacing.md) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color.moaiyAccentV2)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("label_capabilities")
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    HStack(spacing: MoaiyUI.Spacing.sm) {
                        CapabilityBadge(name: "Encrypt", icon: "lock.fill")
                        CapabilityBadge(name: "Sign", icon: "signature")
                    }
                }
                
                Spacer()
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
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
        case .ultimate: return Color.moaiySuccess
        case .full: return Color.moaiyInfo
        case .marginal: return Color.moaiyWarning
        case .none: return Color.moaiyError
        case .unknown: return Color.moaiyTextSecondary
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
        VStack(spacing: MoaiyUI.Spacing.md) {
            // Primary actions
            Button(action: { }) {
                Label("action_encrypt_file", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
            .controlSize(.large)

            // Secondary actions
            HStack(spacing: MoaiyUI.Spacing.md) {
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
                .padding(.vertical, MoaiyUI.Spacing.sm)
            
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
            .foregroundStyle(Color.moaiyError)
            .disabled(isDeleting)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
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
        VStack(spacing: MoaiyUI.Spacing.xxl) {
            // Header
            VStack(spacing: MoaiyUI.Spacing.sm) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.moaiyAccentV2)

                Text("action_export_public_key")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.moaiyTextPrimary)

                Text("export_key_description")
                    .font(.body)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Key info
            VStack(spacing: MoaiyUI.Spacing.sm) {
                HStack {
                    Text("label_key_id")
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Spacer()
                    Text(key.keyID)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
                
                HStack {
                    Text("field_name")
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Spacer()
                    Text(key.name)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
                
                HStack {
                    Text("field_email")
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Spacer()
                    Text(key.email)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
            }
            .padding(MoaiyUI.Spacing.md)
            .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.md)
            
            // Error message
            if let error = exportError {
                ErrorBanner(message: error)
            }
            
            // Actions
            VStack(spacing: MoaiyUI.Spacing.md) {
                Button(action: saveToFile) {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("action_save_to_file", systemImage: "doc.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
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
        .padding(MoaiyUI.Spacing.xxxl)
        .background(Color.moaiySurfaceBackground)
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

                try keyData.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

                isExporting = false
                dismiss()
            } catch {
                exportError = UserFacingErrorMapper.message(for: error, context: .exportKey)
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
                exportError = UserFacingErrorMapper.message(for: error, context: .exportKey)
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
        VStack(spacing: MoaiyUI.Spacing.xxl) {
            // Header
            VStack(spacing: MoaiyUI.Spacing.sm) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "trash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.moaiyError)

                Text("action_delete_key")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.moaiyTextPrimary)

                Text("delete_key_select_option")
                    .font(.body)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .multilineTextAlignment(.center)
            }

            // Key info
            VStack(spacing: MoaiyUI.Spacing.sm) {
                HStack {
                    Text("field_name")
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Spacer()
                    Text(key.name)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }

                HStack {
                    Text("field_email")
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Spacer()
                    Text(key.email)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
            }
            .padding(MoaiyUI.Spacing.md)
            .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.md)

            // Delete options
            VStack(spacing: MoaiyUI.Spacing.md) {
                Text(key.isSecret ? "delete_key_has_secret" : "delete_key_public_only")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)

                if key.isSecret {
                    // Option 1: Private key only
                    DeleteOptionRow(
                        title: "delete_option_private",
                        description: "delete_option_private_description",
                        icon: "key.fill",
                        color: Color.moaiyWarning,
                        isSelected: selectedOption == .secretOnly
                    ) {
                        selectedOption = .secretOnly
                    }

                    // Option 2: Public key only
                    DeleteOptionRow(
                        title: "delete_option_public",
                        description: "delete_option_public_description",
                        icon: "key",
                        color: Color.moaiyInfo,
                        isSelected: selectedOption == .publicOnly
                    ) {
                        selectedOption = .publicOnly
                    }

                    // Option 3: Both keys
                    DeleteOptionRow(
                        title: "delete_option_both",
                        description: "delete_option_both_description",
                        icon: "trash.fill",
                        color: Color.moaiyError,
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
                        color: Color.moaiyError,
                        isSelected: true
                    ) { }
                }
            }

            // Warning
            HStack(spacing: MoaiyUI.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.moaiyWarning)
                Text("delete_key_warning")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
            }

            // Actions
            HStack(spacing: MoaiyUI.Spacing.md) {
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
                .tint(Color.moaiyError)
                .controlSize(.large)
                .disabled(isDeleting)
            }
        }
        .padding(MoaiyUI.Spacing.xxxl)
        .background(Color.moaiySurfaceBackground)
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
                deleteError = UserFacingErrorMapper.message(for: error, context: .keyEdit)
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
            HStack(spacing: MoaiyUI.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                }
            }
            .padding(MoaiyUI.Spacing.md)
            .background(isSelected ? color.opacity(0.1) : Color.moaiySurfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: MoaiyUI.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: MoaiyUI.Radius.sm)
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
