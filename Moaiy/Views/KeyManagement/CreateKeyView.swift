//
//  CreateKeyView.swift
//  Moaiy
//
//  Create new key wizard
//

import SwiftUI

struct CreateKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedKeyType: KeyType = .rsa4096
    @State private var currentStep = 0
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var createdKeyFingerprint: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("wizard_create_key_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("wizard_create_key_subtitle")
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
                .disabled(isCreating)
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
                            .fill(currentStep > step ? Color.moaiyAccent : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)

            Divider()

            // Content
            Group {
                if isCreating {
                    CreatingKeyView()
                } else if showSuccess {
                    SuccessView(fingerprint: createdKeyFingerprint ?? "") {
                        dismiss()
                    }
                } else {
                    switch currentStep {
                    case 0:
                        Step1BasicInfo(name: $name, email: $email)
                    case 1:
                        Step2KeyType(selectedKeyType: $selectedKeyType)
                    case 2:
                        Step3Password(
                            password: $password,
                            confirmPassword: $confirmPassword,
                            errorMessage: $errorMessage
                        )
                    default:
                        EmptyView()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Footer
            if !isCreating && !showSuccess {
                HStack {
                    if currentStep > 0 {
                        Button("action_back") {
                            withAnimation { currentStep -= 1 }
                            errorMessage = nil
                        }
                    }

                    Spacer()

                    if currentStep < 2 {
                        Button("action_next") {
                            withAnimation { currentStep += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceed)
                    } else {
                        Button("action_create_key") {
                            createKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canProceed || isCreating)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 480)
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
        case 0: return !name.isEmpty && !email.isEmpty && isValidEmail(email)
        case 1: return true
        case 2:
            // Password can be empty (no password protection)
            // Only validate that they match if both are filled
            if password.isEmpty && confirmPassword.isEmpty {
                return true
            }
            return !password.isEmpty && password == confirmPassword
        default: return false
        }
    }

    private func createKey() {
        isCreating = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let passphrase = password.isEmpty ? nil : password
                let fingerprint = try await viewModel.generateKey(
                    name: name,
                    email: email,
                    keyType: selectedKeyType,
                    passphrase: passphrase
                )

                createdKeyFingerprint = fingerprint
                isCreating = false
                withAnimation {
                    showSuccess = true
                }
            } catch {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Basic email validation regex
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailPattern, options: .regularExpression) != nil
    }
}

// MARK: - Creating Key View

struct CreatingKeyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("wizard_creating_key")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("wizard_creating_key_description")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Success View

struct SuccessView: View {
    let fingerprint: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("wizard_key_created")
                .font(.title2)
                .fontWeight(.semibold)

            Text("wizard_key_created_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Fingerprint display
            VStack(spacing: 8) {
                Text("wizard_fingerprint")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatFingerprint(fingerprint))
                    .font(.system(.caption, design: .monospaced))
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button("action_done") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func formatFingerprint(_ fp: String) -> String {
        // Format fingerprint in groups of 4 characters
        var result = ""
        for (index, char) in fp.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
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
                    .fill(isActive ? Color.moaiyAccent : Color.secondary.opacity(0.3))
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
                    TextField(String(localized: "field_key_name"), text: $name)
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
    @Binding var selectedKeyType: KeyType

    var body: some View {
        VStack(spacing: 20) {
            Text("wizard_key_type_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                KeyTypeOption(
                    title: "RSA-4096",
                    description: String(localized: "key_type_rsa_description"),
                    recommended: true,
                    isSelected: selectedKeyType == .rsa4096
                ) { selectedKeyType = .rsa4096 }

                KeyTypeOption(
                    title: "RSA-2048",
                    description: String(localized: "key_type_rsa2048_description"),
                    recommended: false,
                    isSelected: selectedKeyType == .rsa2048
                ) { selectedKeyType = .rsa2048 }

                KeyTypeOption(
                    title: "ECC (Curve25519)",
                    description: String(localized: "key_type_ecc_description"),
                    recommended: false,
                    isSelected: selectedKeyType == .ecc
                ) { selectedKeyType = .ecc }
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
                    .foregroundStyle(isSelected ? Color.moaiyAccent : .secondary)
                
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
            .background(isSelected ? Color.moaiyAccent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.moaiyAccent : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Password

struct Step3Password: View {
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("wizard_password_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Form {
                Section {
                    SecureField("field_password", text: $password)
                    SecureField("field_confirm_password", text: $confirmPassword)
                } footer: {
                    if !password.isEmpty && password != confirmPassword {
                        Text("error_password_mismatch")
                            .foregroundStyle(.red)
                    } else if password.isEmpty {
                        Text("wizard_password_optional")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            // Error message
            if let error = errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

#Preview {
    CreateKeyView()
}
