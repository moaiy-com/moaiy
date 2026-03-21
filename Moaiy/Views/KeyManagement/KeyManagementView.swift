//
//  KeyManagementView.swift
//  Moaiy
//
//  Key management main view
//

import SwiftUI

struct KeyManagementView: View {
    @State private var viewModel = KeyManagementViewModel()
    @State private var showingCreateKey = false
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.keys.isEmpty {
                ProgressView("Loading keys...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.keys.isEmpty {
                EmptyKeysView(onCreateKey: { showingCreateKey = true })
            } else {
                KeyListView(viewModel: viewModel)
            }
        }
        .navigationTitle("Key Management")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateKey = true }) {
                    Label("Create Key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await viewModel.refresh() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { }) {
                    Label("Import Key", systemImage: "square.and.arrow.down")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search keys...")
        .sheet(isPresented: $showingCreateKey) {
            CreateKeyView()
        }
    }
}

// MARK: - Empty State View

struct EmptyKeysView: View {
    let onCreateKey: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Keys Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first GPG key to start encrypting and decrypting your secrets.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button(action: onCreateKey) {
                Label("Create Your First Key", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Key List View

struct KeyListView: View {
    var viewModel: KeyManagementViewModel
    
    var body: some View {
        List(viewModel.filteredKeys) { key in
            KeyCardView(key: key)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.inset)
    }
}

// MARK: - Key Card View

struct KeyCardView: View {
    let key: GPGKey
    
    var body: some View {
        HStack(spacing: 16) {
            // Key icon with color based on key type
            Image(systemName: key.isSecret ? "key.fill" : "key")
                .font(.title2)
                .foregroundStyle(keyIconColor)
                .frame(width: 40, height: 40)
                .background(keyIconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(key.name)
                        .font(.headline)
                    
                    // Key type badge: Private Key or Public Key
                    Text(key.isSecret ? "Private Key" : "Public Key")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(keyTypeBadgeColor.opacity(0.2))
                        .foregroundStyle(keyTypeBadgeColor)
                        .clipShape(Capsule())
                    
                    // Trust level badge
                    Text(key.trustLevel.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trustLevelColor.opacity(0.2))
                        .foregroundStyle(trustLevelColor)
                        .clipShape(Capsule())
                }
                
                Text(key.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label(key.displayKeyType, systemImage: "number")
                    if let createdAt = key.createdAt {
                        Text("•")
                        Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Encrypt") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Menu {
                    Button("Export Public Key") { }
                    Button("Copy Fingerprint") { }
                    Divider()
                    Button("Delete Key", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    
    // MARK: - Color Computed Properties
    
    private var keyIconColor: Color {
        key.isSecret ? Color.moiayAccent : .secondary
    }
    
    private var keyTypeBadgeColor: Color {
        key.isSecret ? Color.moiayAccent : .blue
    }
    
    private var trustLevelColor: Color {
        switch key.trustLevel {
        case .ultimate:
            return .green
        case .full:
            return .blue
        case .marginal:
            return .orange
        case .none:
            return .red
        case .unknown:
            return .secondary
        }
    }
}

#Preview("Empty State") {
    EmptyKeysView(onCreateKey: {})
        .frame(width: 800, height: 600)
}
