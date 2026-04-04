//
//  SecureInputField.swift
//  Moaiy
//
//  Secure text input field with visibility toggle
//

import SwiftUI

struct SecureInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var showVisibilityToggle: Bool = true
    
    @State private var isVisible = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack(spacing: 0) {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                
                if showVisibilityToggle {
                    Button(action: { isVisible.toggle() }) {
                        Image(systemName: isVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.moaiyAccentV2 : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SecureInputField(
            title: "Password",
            placeholder: "Enter password",
            text: .constant("")
        )
        
        SecureInputField(
            title: "",
            placeholder: "Passphrase",
            text: .constant("test123")
        )
    }
    .padding()
    .frame(width: 400)
}
