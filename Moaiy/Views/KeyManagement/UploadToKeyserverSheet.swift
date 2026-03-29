//
//  UploadToKeyserverSheet.swift
//  Moaiy
//
//  Sheet for uploading public keys to a keyserver
//

import SwiftUI

struct UploadToKeyserverSheet: View {
    let key: GPGKey
    let onDismiss: () -> Void
    let onSuccess: () -> Void
    
    @State private var selectedKeyserver = "keys.openpgp.org"
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var errorMessage: String?
    
    private let keyservers = [
        "keys.openpgp.org",
        "keyserver.ubuntu.com",
        "pgp.mit.edu"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            headerView
            
            if uploadSuccess {
                successView
            } else {
                keyInfoView
                keyserverPicker
                errorMessageView
                buttonsView
            }
        }
        .padding(24)
        .frame(width: 450)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("upload_to_keyserver_title")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("upload_to_keyserver_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var keyInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("key_info")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: key.isSecret ? "key.fill" : "key")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.name)
                        .font(.headline)
                    
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(key.fingerprint)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var keyserverPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("keyserver_label")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("keyserver_label", selection: $selectedKeyserver) {
                ForEach(keyservers, id: \.self) { keyserver in
                    Text(keyserver)
                        .tag(keyserver)
                }
            }
            .pickerStyle(.menu)
            
            Text("keyserver_note")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var buttonsView: some View {
        HStack(spacing: 12) {
            Button("action_cancel") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .disabled(isUploading)
            
            Spacer()
            
            Button(action: uploadKey) {
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("upload_button")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUploading)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("upload_success_title")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("upload_success_message")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("done") {
                onSuccess()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func uploadKey() {
        isUploading = true
        errorMessage = nil
        
        Task {
            do {
                try await GPGService.shared.uploadToKeyserver(
                    keyID: key.fingerprint,
                    keyserver: selectedKeyserver
                )
                
                await MainActor.run {
                    isUploading = false
                    uploadSuccess = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    UploadToKeyserverSheet(
        key: GPGKey(
            id: "test",
            keyID: "ABC123",
            fingerprint: "1234 5678 90AB CDEF 1234 5678 90AB CDEF 1234 5678",
            name: "Test User",
            email: "test@example.com",
            algorithm: "RSA",
            keyLength: 4096,
            isSecret: false,
            createdAt: Date(),
            expiresAt: nil,
            trustLevel: .full
        ),
        onDismiss: {},
        onSuccess: {}
    )
}
