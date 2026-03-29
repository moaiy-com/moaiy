//
//  PasswordInputSheet.swift
//  Moaiy
//
//  Sheet for password input when decrypting files
//

import SwiftUI

struct PasswordInputSheet: View {
    let fileName: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var password = ""
    @State private var showError = false
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            headerView
            fileInfoView
            passwordField
            errorView
            buttonsView
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            isPasswordFocused = true
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("password_required_title")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("password_required_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var fileInfoView: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(.secondary)
            
            Text(fileName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)
            
            Image(systemName: "lock.open.fill")
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("password_field_label")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            SecureField("password_field_placeholder", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isPasswordFocused)
                .onSubmit {
                    if !password.isEmpty {
                        onConfirm(password)
                    } else {
                        showError = true
                    }
                }
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        if showError {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text("password_empty_error")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .transition(.opacity)
        }
    }
    
    private var buttonsView: some View {
        HStack(spacing: 12) {
            Button("action_cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
            
            Button("decrypt_button") {
                if password.isEmpty {
                    withAnimation {
                        showError = true
                    }
                } else {
                    onConfirm(password)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}

#Preview {
    PasswordInputSheet(
        fileName: "secret_document.pdf.gpg",
        onConfirm: { _ in },
        onCancel: {}
    )
}
