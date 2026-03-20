//
//  CreateKeyView.swift
//  Moaiy
//
//  Create new key wizard
//

import SwiftUI

struct CreateKeyView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var keyType = 0
    @State private var currentStep = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "wizard_create_key_title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(String(localized: "wizard_create_key_subtitle"))
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
            .padding()
            
            Divider()
            
            // Steps indicator
            HStack(spacing: 0) {
                ForEach(0..<3) { step in
                    StepIndicator(
                        step: step + 1,
                        title: stepTitle(step),
                        isActive: currentStep >= step,
                        isCurrent: currentStep == step
                    )
                    if step < 2 {
                        Rectangle()
                            .fill(currentStep > step ? Color.moiayAccent : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            
            Divider()
            
            // Content
            Group {
                switch currentStep {
                case 0:
                    Step1BasicInfo(name: $name, email: $email)
                case 1:
                    Step2KeyType(keyType: $keyType)
                case 2:
                    Step3Password(password: $password, confirmPassword: $confirmPassword)
                default:
                    EmptyView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Footer
            HStack {
                if currentStep > 0 {
                    Button(String(localized: "action_back")) {
                        withAnimation { currentStep -= 1 }
                    }
                }
                
                Spacer()
                
                if currentStep < 2 {
                    Button(String(localized: "action_next")) {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                } else {
                    Button(String(localized: "action_create_key")) {
                        createKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }
    
    // MARK: - Helpers
    
    private func stepTitle(_ step: Int) -> String {
        switch step {
        case 0: return String(localized: "wizard_step_basic_info")
        case 1: return String(localized: "wizard_step_key_type")
        case 2: return String(localized: "wizard_step_password")
        default: return ""
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !email.isEmpty && email.contains("@")
        case 1: return true
        case 2: return password == confirmPassword
        default: return false
        }
    }
    
    private func createKey() {
        // TODO: Implement key creation
        dismiss()
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let step: Int
    let title: String
    let isActive: Bool
    let isCurrent: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.moiayAccent : Color.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                if isActive && !isCurrent {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                } else {
                    Text("\(step)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 1: Basic Info

struct Step1BasicInfo: View {
    @Binding var name: String
    @Binding var email: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "wizard_basic_info_description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Form {
                Section {
                    TextField(String(localized: "field_name"), text: $name)
                        .textContentType(.name)
                    
                    TextField(String(localized: "field_email"), text: $email)
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .autocorrectionDisabled()
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Step 2: Key Type

struct Step2KeyType: View {
    @Binding var keyType: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "wizard_key_type_description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                KeyTypeOption(
                    title: "RSA-4096",
                    description: String(localized: "key_type_rsa_description"),
                    recommended: true,
                    isSelected: keyType == 0
                ) { keyType = 0 }
                
                KeyTypeOption(
                    title: "ECC (Curve25519)",
                    description: String(localized: "key_type_ecc_description"),
                    recommended: false,
                    isSelected: keyType == 2
                ) { keyType = 2 }
            }
        }
    }
}

struct KeyTypeOption: View {
    let title: String
    let description: String
    let recommended: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.moiayAccent : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if recommended {
                            Text(String(localized: "badge_recommended"))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.moiayAccent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.moiayAccent : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Password

struct Step3Password: View {
    @Binding var password: String
    @Binding var confirmPassword: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "wizard_password_description"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Form {
                Section {
                    SecureField(String(localized: "field_password"), text: $password)
                    SecureField(String(localized: "field_confirm_password"), text: $confirmPassword)
                } footer: {
                    if !password.isEmpty && password != confirmPassword {
                        Text(String(localized: "error_password_mismatch"))
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    CreateKeyView()
}
