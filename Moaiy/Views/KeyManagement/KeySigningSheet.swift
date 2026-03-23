//
//  KeySigningSheet.swift
//  Moaiy
//
//  Key signing interface for signing other keys
//

import SwiftUI

struct KeySigningSheet: View {
    let keyToSign: GPGKey
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSignerKey: GPGKey?
    @State private var passphrase = ""
    @State private var setTrustAfterSigning = true
    @State private var selectedTrustLevel: TrustLevel = .marginal
    @State private var isSigning = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("sign_key_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("sign_key_subtitle")
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
            
            // Key to sign info
            KeyInfoCard(key: keyToSign)
            
            // Signer key selection
            VStack(alignment: .leading, spacing: 12) {
                Text("sign_select_signer")
                    .font(.headline)
                
                if viewModel.secretKeys.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("sign_no_secret_keys")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Picker("", selection: $selectedSignerKey) {
                        Text("sign_default_key").tag(nil as GPGKey?)
                        ForEach(viewModel.secretKeys) { key in
                            HStack {
                                Text(key.name)
                                Text("<\(key.email)>").foregroundStyle(.secondary)
                            }
                            .tag(key as GPGKey?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            // Passphrase input
            VStack(alignment: .leading, spacing: 8) {
                Text("sign_passphrase")
                    .font(.headline)
                
                SecureField("sign_passphrase_placeholder", text: $passphrase)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Trust level after signing
            VStack(alignment: .leading, spacing: 12) {
                Toggle("sign_set_trust", isOn: $setTrustAfterSigning)
                    .font(.headline)
                
                if setTrustAfterSigning {
                    HStack(spacing: 8) {
                        ForEach([TrustLevel.marginal, .full, .ultimate], id: \.self) { level in
                            Button(action: { selectedTrustLevel = level }) {
                                VStack(spacing: 4) {
                                    Image(systemName: trustIcon(for: level))
                                        .font(.title3)
                                    Text(level.localizedName)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedTrustLevel == level ? Color.moaiyAccent.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedTrustLevel == level ? Color.moaiyAccent : Color.secondary.opacity(0.3), lineWidth: selectedTrustLevel == level ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selectedTrustLevel == level ? Color.moaiyAccent : .primary)
                        }
                    }
                }
            }
            
            // Info text
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                
                Text("sign_info_text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(action: signKey) {
                    if isSigning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("sign_action")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(passphrase.isEmpty || isSigning || viewModel.secretKeys.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 550, height: 650)
        .onAppear {
            selectedSignerKey = viewModel.secretKeys.first
        }
        .alert("sign_success_title", isPresented: $showSuccess) {
            Button("action_ok") { dismiss() }
        } message: {
            Text("sign_success_message")
        }
        .alert("error_occurred", isPresented: $showError) {
            Button("action_ok") { }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func signKey() {
        isSigning = true
        
        Task {
            do {
                try await viewModel.signKey(
                    keyToSign: keyToSign,
                    signerKey: selectedSignerKey,
                    passphrase: passphrase,
                    trustLevel: setTrustAfterSigning ? selectedTrustLevel : nil
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSigning = false
        }
    }
    
    private func trustIcon(for level: TrustLevel) -> String {
        switch level {
        case .marginal: return "questionmark.circle.fill"
        case .full: return "checkmark.circle.fill"
        case .ultimate: return "checkmark.seal.fill"
        default: return "circle"
        }
    }
}

// MARK: - Key Info Card

struct KeyInfoCard: View {
    let key: GPGKey
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.title)
                .foregroundStyle(Color.moaiyAccent)
                .frame(width: 48, height: 48)
                .background(Color.moaiyAccent.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(key.name)
                    .font(.headline)
                
                Text(key.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(key.fingerprint.formattedFingerprint())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(key.trustLevel.localizedName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(trustColor.opacity(0.2))
                    .foregroundStyle(trustColor)
                    .clipShape(Capsule())
                
                Text(key.displayKeyType)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Fingerprint Formatting Extension

extension String {
    func formattedFingerprint() -> String {
        let clean = self.replacingOccurrences(of: " ", with: "")
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}

// MARK: - Preview

#Preview("Key Signing") {
    KeySigningSheet(keyToSign: GPGKey(
        id: "1",
        keyID: "ABC12345",
        fingerprint: "1234567890ABCDEF1234567890ABCDEF12345678",
        name: "Test User",
        email: "test@example.com",
        algorithm: "RSA",
        keyLength: 4096,
        isSecret: false,
        createdAt: Date(),
        expiresAt: nil,
        trustLevel: .marginal
    ))
    .environment(KeyManagementViewModel())
}
