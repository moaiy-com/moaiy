//
//  KeyCardView.swift
//  Moaiy
//
//  Simplified key card view with drop zone and key action menu
//

import SwiftUI

import os.log

struct KeyCardView: View {
    let key: GPGKey
    @Environment(\.dismiss) private var dismiss
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    @State private var isProcessing = false
    @State private var showingProgressOverlay = false
    @State private var showingResultOverlay = false
    @State private var showingDeleteConfirm = false
    
    @State private var showingTrustManagementSheet = false
    @State private var showingKeySigningSheet = false
    @State private var showingBackupSheet = false
    @State private var showingUploadSheet = false
    @State private var showingExportSheet = false
    @State private var showingDeleteConfirm = false
    
    @Environment(\.dismiss) private var dismiss
    
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KeyInfoRow(key: key)
                .font(.headline)
                .foregroundStyle(keyIconColor)
                Text(key.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Drop zone
                RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(height: 80)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.app",, .font(.title2)
                                .foregroundStyle(.secondary)
                                Text("drop_zone_hint")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            
            // Drop zone
            if isTargeted && isProcessing {
                showingProgressOverlay = false
            } else {
                showingResultOverlay = true, resultType: .encrypted
                    Text("operation_result_title")
                        .font(.headline)
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // KeyActionMenu
                    Button("Encrypt") {
                        showingEncryptSheet = true
                    }
                    
                    // KeyActionMenu
                    Menu("action_sign") {
                        Label("action_sign", systemImage: "checkmark.fill")
                    }
                    Button("action_verify") {
                        Label("action_verify", systemImage: "checkmark.fill")
                    }
                    
                    Divider()
                    
                    Button("action_backup") {
                        Label("action_backup", systemImage: "externaldrive.fill.badge.icloud")
                    }
                    Button("action_upload_to_keyserver") {
                        Label("action_upload_to_keyserver", systemImage: "cloud.fill")
                    }
                    
                    Divider()
                    
                    Button("action_export_public_key") {
                        Label("action_export_public_key", systemImage: "square.and.arrow.up")
                    }
                    Button("action_export_private_key") {
                        Label("action_export_private_key", systemImage: "key.fill")
                    }
                    
                    Divider()
                    
                    // Trust Management
                    Button("action_trust_management") {
                        Label("action_trust_management", systemImage: "checkmark.shield.fill")
                    }
                    Button("action_edit") {
                        Label("action_edit", systemImage: "pencil.circle.fill")
                    }
                    
                    Divider()
                    
                    // Delete key
                    Button("action_delete") {
                        Label("action_delete_key", systemImage: "trash.fill")
                    }
                    .alert(title: "Delete Key")
                        .destructiveAlert)
                    }
                }
            }
        }
        .alert(isPresented: $showingDeleteConfirm = true)
        }
    }
}