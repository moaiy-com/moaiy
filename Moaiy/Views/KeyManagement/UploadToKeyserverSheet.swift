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
    
    @State private var selectedKeyserver = Constants.GPG.defaultKeyserver
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var errorMessage: String?
    
    private let keyservers = Constants.GPG.supportedKeyservers
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.xxl) {
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
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 400, idealWidth: 480, maxWidth: 620)
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(Color.moaiyAccentV2)

            Text("upload_to_keyserver_title")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.moaiyTextPrimary)

            Text("upload_to_keyserver_description")
                .font(.body)
                .foregroundStyle(Color.moaiyTextSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var keyInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("key_info")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)
            
            HStack {
                Image(systemName: key.isSecret ? "key.fill" : "key")
                    .foregroundStyle(Color.moaiyTextSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.name)
                        .font(.headline)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    
                    Text(key.email)
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                    
                    Text(key.fingerprint)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(Color.moaiyTextSecondary.opacity(0.8))
                }
                
                Spacer()
            }
            .moaiyModalCard()
        }
    }
    
    private var keyserverPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("keyserver_label")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)
            
            Picker("keyserver_label", selection: $selectedKeyserver) {
                ForEach(keyservers, id: \.self) { keyserver in
                    Text(keyserver)
                        .tag(keyserver)
                }
            }
            .pickerStyle(.menu)
            
            Text("keyserver_note")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.moaiyError)
                
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextPrimary)
            }
            .padding(MoaiyUI.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .moaiyBannerStyle(tint: Color.moaiyError, cornerRadius: MoaiyUI.Radius.md)
        }
    }
    
    private var buttonsView: some View {
        HStack(spacing: 12) {
            Button("action_cancel") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isUploading)
            
            Spacer()
            
            Button(action: uploadKey) {
                ZStack {
                    Text("upload_button")
                        .opacity(isUploading ? 0 : 1)

                    if isUploading {
                        UploadingDotsIndicator()
                    }
                }
                .frame(minWidth: 92, minHeight: 20)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.moaiyAccentV2)
            .disabled(isUploading)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.moaiySuccess)
            
            Text("upload_success_title")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.moaiyTextPrimary)
            
            Text("upload_success_message")
                .font(.body)
                .foregroundStyle(Color.moaiyTextSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Image(systemName: "envelope.badge")
                    .foregroundStyle(Color.moaiyInfo)
                Text("upload_success_verification_hint")
                    .font(.caption)
                    .foregroundStyle(Color.moaiyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MoaiyUI.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .moaiyBannerStyle(tint: Color.moaiyInfo, cornerRadius: MoaiyUI.Radius.md)
            
            Button("action_ok") {
                onSuccess()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
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
                    errorMessage = UserFacingErrorMapper.message(for: error, context: .keyserverUpload)
                }
            }
        }
    }
}

private struct UploadingDotsIndicator: View {
    @State private var activeIndex = 0
    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(activeIndex == index ? 1.0 : 0.35)
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
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
