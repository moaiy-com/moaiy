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
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("trust_management_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Current trust display
            CurrentTrustCard(key: key, trustDetails: trustDetails)
            
            // Trust level selection
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
            
            // Warning for ultimate trust
            if selectedTrustLevel == .ultimate && key.trustLevel != .ultimate {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text("trust_ultimate_warning")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(action: updateTrust) {
                    if isUpdating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("action_save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTrustLevel == key.trustLevel || isUpdating)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500, height: 600)
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
        VStack(alignment: .leading, spacing: 12) {
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
                        .foregroundStyle(.secondary)
                    Text(key.trustLevel.localizedName)
                        .font(.headline)
                }
                
                Spacer()
            }
            
            if let details = trustDetails {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("trust_signatures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(details.signatureCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("trust_owner_trust")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(details.ownerTrust.localizedName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("trust_calculated_trust")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(details.calculatedTrust.localizedName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
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
                        .foregroundStyle(.primary)
                    
                    Text(level.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.moaiyAccent)
                }
            }
            .padding(12)
            .background(isSelected ? Color.moaiyAccent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.moaiyAccent : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
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
        case .ultimate: return .green
        case .full: return .blue
        case .marginal: return .orange
        case .none: return .red
        case .unknown: return .secondary
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
