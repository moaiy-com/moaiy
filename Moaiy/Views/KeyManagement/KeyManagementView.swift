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
    @State private var showingFilters = false
    @State private var keyToDelete: GPGKey?
    @FocusState private var isListFocused: Bool

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.keys.isEmpty {
                // Skeleton loading
                KeyListSkeleton(count: 5)
            } else if let error = viewModel.errorMessage, viewModel.keys.isEmpty {
                // Error state with retry
                ErrorView(message: error) {
                    Task { await viewModel.refresh() }
                }
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
                            .keyboardShortcut(.escape, modifiers: [])
                        }
                    }
            } else {
                // Show list view
                KeyListView(viewModel: viewModel, selectedKey: $selectedKey, keyToDelete: $keyToDelete)
                    .focused($isListFocused)
                    .onKeyPress(.delete) {
                        if let key = selectedKey {
                            keyToDelete = key
                            return .handled
                        }
                        return .ignored
                    }
            }
        }
        .navigationTitle("section_key_management")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateKey = true }) {
                    Label("action_create_key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await viewModel.refresh() } }) {
                    Label("action_refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingImportKey = true }) {
                    Label("action_import_key", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingFilters = true }) {
                    Label("action_filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .badge(viewModel.hasActiveFilters ? "!" : nil)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "prompt_search_keys")
        .onSubmit(of: .search) {
            viewModel.addToSearchHistory(viewModel.searchText)
        }
        .sheet(isPresented: $showingCreateKey) {
            CreateKeyView()
                .environment(viewModel)
        }
        .sheet(isPresented: $showingImportKey) {
            ImportKeySheet()
                .environment(viewModel)
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "confirm_delete_key_title",
            isPresented: .init(
                get: { keyToDelete != nil },
                set: { if !$0 { keyToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("action_delete", role: .destructive) {
                if let key = keyToDelete {
                    Task {
                        do {
                            try await viewModel.deleteKey(key)
                            selectedKey = nil
                        } catch {
                            // Error will be handled by viewModel.errorMessage
                        }
                    }
                }
                keyToDelete = nil
            }
            Button("action_cancel", role: .cancel) {
                keyToDelete = nil
            }
        } message: {
            if let key = keyToDelete {
                Text("confirm_delete_key_message \(key.name)")
            }
        }
        .alert("error_occurred", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("action_retry") {
                Task { await viewModel.refresh() }
            }
            Button("action_cancel", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
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
    @Binding var keyToDelete: GPGKey?

    var body: some View {
        List(viewModel.filteredKeys) { key in
            Button(action: { selectedKey = key }) {
                KeyCardView(key: key, onDelete: { keyToDelete = key })
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        }
        .listStyle(.inset)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Key Card View

struct KeyCardView: View {
    let key: GPGKey
    var onDelete: (() -> Void)? = nil
    @Environment(\.controlActiveState) private var controlActiveState

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

                    // Expired badge
                    if key.isExpired {
                        Text("status_expired")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
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
                    Button("action_copy_fingerprint") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(key.fingerprint, forType: .string)
                    }
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
        .contextMenu {
            Button(action: { }) {
                Label("action_encrypt", systemImage: "lock.fill")
            }

            Button(action: { }) {
                Label("action_decrypt", systemImage: "lock.open.fill")
            }

            Divider()

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(key.fingerprint, forType: .string)
            }) {
                Label("action_copy_fingerprint", systemImage: "doc.on.doc")
            }

            Button(action: { }) {
                Label("action_export_public_key", systemImage: "square.and.arrow.up")
            }

            if key.isSecret {
                Button(action: { }) {
                    Label("action_export_private_key", systemImage: "key.fill")
                }
            }

            Divider()

            Button(role: .destructive, action: {
                onDelete?()
            }) {
                Label("action_delete_key", systemImage: "trash.fill")
            }
        }
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

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Bindable var viewModel: KeyManagementViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("filter_title")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if viewModel.hasActiveFilters {
                    Button("action_reset") {
                        viewModel.resetFilters()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Filter options
            Form {
                Section("filter_key_type") {
                    Picker("", selection: $viewModel.filterKeyType) {
                        ForEach(KeyTypeFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("filter_trust_level") {
                    Picker("", selection: $viewModel.filterTrustLevel) {
                        Text("filter_all_trust_levels").tag(nil as TrustLevel?)
                        ForEach(TrustLevel.allCases, id: \.self) { level in
                            Text(level.localizedName).tag(level as TrustLevel?)
                        }
                    }
                }

                Section("filter_algorithm") {
                    Picker("", selection: $viewModel.filterAlgorithm) {
                        Text("filter_all_algorithms").tag(nil as String?)
                        ForEach(viewModel.availableAlgorithms, id: \.self) { algorithm in
                            Text(algorithm).tag(algorithm as String?)
                        }
                    }
                }

                Section("filter_other_options") {
                    Toggle("filter_show_expired_keys", isOn: $viewModel.showExpiredKeys)
                }
            }
            .formStyle(.grouped)

            // Apply button
            Button("action_apply") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(32)
        .frame(width: 450)
    }
}

#Preview("Empty State") {
    EmptyKeysView(onCreateKey: {})
        .frame(width: 800, height: 600)
}
