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
    @State private var showingImportKey = false
    @State private var selectedKey: GPGKey?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.keys.isEmpty {
                ProgressView("status_loading_keys")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.keys.isEmpty {
                EmptyKeysView(onCreateKey: { showingCreateKey = true })
            } else if let key = selectedKey {
                // Show detail view
                KeyDetailView(key: key)
                    .environment(viewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button(action: { selectedKey = nil }) {
                                Label("action_back", systemImage: "chevron.left")
                            }
                        }
                    }
            } else {
                // Show list view
                KeyListView(viewModel: viewModel, selectedKey: $selectedKey)
            }
        }
        .navigationTitle("section_key_management")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateKey = true }) {
                    Label("action_create_key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await viewModel.refresh() } }) {
                    Label("action_refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingImportKey = true }) {
                    Label("action_import_key", systemImage: "square.and.arrow.down")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "prompt_search_keys")
        .sheet(isPresented: $showingCreateKey) {
            CreateKeyView()
        }
        .sheet(isPresented: $showingImportKey) {
            ImportKeySheet()
                .environment(viewModel)
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
            
            Text("empty_keys_title")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("empty_keys_description")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button(action: onCreateKey) {
                Label("action_create_first_key", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Key List View

struct KeyListView: View {
    @Bindable var viewModel: KeyManagementViewModel
    @Binding var selectedKey: GPGKey?
    
    var body: some View {
        List(viewModel.filteredKeys) { key in
            Button(action: { selectedKey = key }) {
                KeyCardView(key: key)
            }
            .buttonStyle(.plain)
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
                    Text(key.isSecret ? "key_type_private" : "key_type_public")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(keyTypeBadgeColor.opacity(0.2))
                        .foregroundStyle(keyTypeBadgeColor)
                        .clipShape(Capsule())
                    
                    // Trust level badge
                    Text(key.trustLevel.localizedName)
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
                Button("action_encrypt") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Menu {
                    Button("action_export_public_key") { }
                    Button("action_copy_fingerprint") { }
                    Divider()
                    Button("action_delete_key", role: .destructive) { }
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
