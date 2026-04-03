//
//  TrustManagementSheet.swift
//  Moaiy
//
//  Trust management interface for keys
//

import SwiftUI

struct TrustManagementSheet: View {
    let key: GPGKey
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTrustLevel: TrustLevel
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var trustDetails: KeyTrustDetails?
    
    init(key: GPGKey) {
        self.key = key
        _selectedTrustLevel = State(initialValue: key.trustLevel)
    }
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("trust_management_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CurrentTrustCard(key: key, trustDetails: trustDetails)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("trust_select_level")
                            .font(.headline)

                        VStack(spacing: 8) {
                            ForEach(TrustLevel.allCases, id: \.self) { level in
                                TrustLevelRow(
                                    level: level,
                                    isSelected: selectedTrustLevel == level,
                                    action: { selectedTrustLevel = level }
                                )
                            }
                        }
                    }

                    if selectedTrustLevel == .ultimate && key.trustLevel != .ultimate {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.moaiyWarning)

                            Text("trust_ultimate_warning")
                                .font(.caption)
                                .foregroundStyle(Color.moaiyTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(MoaiyUI.Spacing.md)
                        .moaiyBannerStyle(tint: Color.moaiyWarning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: updateTrust) {
                    if isUpdating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("action_save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.moaiyAccentV2)
                .disabled(selectedTrustLevel == key.trustLevel || isUpdating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 500, idealWidth: 600, maxWidth: 720, minHeight: 560, idealHeight: 680, maxHeight: 860)
        .task {
            await loadTrustDetails()
        }
        .alert("error_occurred", isPresented: $showError) {
            Button("action_ok") { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func loadTrustDetails() async {
        do {
            trustDetails = try await viewModel.getTrustDetails(for: key)
        } catch {
            // Silently fail, trust details are optional
            print("Failed to load trust details: \(error)")
        }
    }
    
    private func updateTrust() {
        isUpdating = true
        
        Task {
            do {
                try await viewModel.setTrust(for: key, trustLevel: selectedTrustLevel)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isUpdating = false
        }
    }
}

// MARK: - Current Trust Card

struct CurrentTrustCard: View {
    let key: GPGKey
    let trustDetails: KeyTrustDetails?
    
    var body: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            HStack {
                Image(systemName: trustIcon)
                    .font(.title)
                    .foregroundStyle(trustColor)
                    .frame(width: 40, height: 40)
                    .background(trustColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("trust_current_level")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                    Text(key.trustLevel.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                }
                
                Spacer()
            }
            
            if let details = trustDetails {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                    HStack {
                        Text("trust_signatures")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text("\(details.signatureCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    HStack {
                        Text("trust_owner_trust")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text(details.ownerTrust.localizedName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }

                    HStack {
                        Text("trust_calculated_trust")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                        Spacer()
                        Text(details.calculatedTrust.localizedName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyTextPrimary)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle()
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

// MARK: - Trust Level Row

struct TrustLevelRow: View {
    let level: TrustLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.localizedName)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    
                    Text(level.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.moaiyAccentV2)
                }
            }
            .padding(12)
            .background(isSelected ? Color.moaiyAccentV2.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.moaiyAccentV2 : Color.moaiyBorderPrimary.opacity(0.8),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var icon: String {
        switch level {
        case .ultimate: return "checkmark.seal.fill"
        case .full: return "checkmark.circle.fill"
        case .marginal: return "questionmark.circle.fill"
        case .none: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var color: Color {
        switch level {
        case .ultimate: return Color.moaiySuccess
        case .full: return Color.moaiyInfo
        case .marginal: return Color.moaiyWarning
        case .none: return Color.moaiyError
        case .unknown: return Color.moaiyTextSecondary
        }
    }
}

// MARK: - Preview

#Preview("Trust Management") {
    TrustManagementSheet(key: GPGKey(
        id: "1",
        keyID: "ABC12345",
        fingerprint: "1234567890ABCDEF1234567890ABCDEF12345678",
        name: "Test User",
        email: "test@example.com",
        algorithm: "RSA",
        keyLength: 4096,
        isSecret: true,
        createdAt: Date(),
        expiresAt: nil,
        trustLevel: .full
    ))
    .environment(KeyManagementViewModel())
}
