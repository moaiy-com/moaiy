//
//  KeyActionMenu.swift
//  Moaiy
//
//  Menu component for key actions (encrypt, decrypt, sign, verify, backup, upload, delete)
//

import SwiftUI

struct KeyActionMenu: View {
    let key: GPGKey
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    @State private var showingUploadSheet = false
    
    var body: some View {
        Menu {
            Section("Operations") {
                Button {
                    Label("action_encrypt", systemImage: "lock.fill")
                }
                Button {
                    Label("action_decrypt", systemImage: "lock.open.fill")
                }
                Button {
                    Label("action_sign", systemImage: "signature")
                }
                Button {
                    Label("action_verify", systemImage: "checkmark.seal")
                }
            }
            
            Divider()
            
            Section("Advanced") {
                Button {
                    Label("action_upload_to_keyserver", systemImage: "cloud.fill")
                    showingUploadSheet = true
                }
                Button {
                    Label("action_backup", systemImage: "externaldrive.fill")
                }
            }
            
            Divider()
            
            Section {
                Button {
                    Label("action_export_public_key", systemImage: "square.and.arrow.up")
                }
                if key.isSecret {
                    Button {
                        Label("action_export_private_key", systemImage: "key.fill")
                    }
                }
            }
            
            Divider()
            
            Section {
                Button(role: .destructive) {
                    Label("action_delete_key", systemImage: "trash.fill")
                }
            }
        }
        .sheet(isPresented: $showingUploadSheet) {
            UploadToKeyserverSheet(
                key: key,
                onDismiss: {
                    showingUploadSheet = false
                },
                onSuccess: {
                    showingUploadSheet = false
                }
            )
        }
    }
}

#Preview {
    KeyActionMenu(key: GPGKey(
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
    ))
}
