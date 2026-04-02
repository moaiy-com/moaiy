//
//  KeyManagementView.swift
//  Moaiy
//
//  Key management main view
//

import SwiftUI

struct KeyManagementView: View {
    @State private var viewModel: KeyManagementViewModel
    @State private var showingCreateKey = false
    @State private var showingImportKey = false
    @State private var keyToDelete: GPGKey?

    init(viewModel: KeyManagementViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? AppState.shared.keyManagement)
    }

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
            } else {
                // Show list view
                KeyListView(viewModel: viewModel, keyToDelete: $keyToDelete)
            }
        }
        .navigationTitle("Moaiy")
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
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingImportKey = true }) {
                    Label("action_import_key", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("i", modifiers: .command)
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
                Text(
                    String(
                        format: String(localized: "confirm_delete_key_message"),
                        locale: Locale.current,
                        key.name
                    )
                )
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
        .safeAreaInset(edge: .bottom) {
            Text("Protect what matters with drag and drop.")
                .font(.footnote)
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
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
    @Binding var keyToDelete: GPGKey?

    var body: some View {
        List(viewModel.filteredKeys) { key in
            KeyCardView(key: key, onDelete: { keyToDelete = key })
            .environment(viewModel)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        }
        .listStyle(.inset)
        .refreshable {
            await viewModel.refresh()
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

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

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

            HStack(spacing: 12) {
                Button("action_cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("action_apply") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .moaiyModalAdaptiveSize(minWidth: 400, idealWidth: 480, maxWidth: 620)
    }
}

#Preview("Empty State") {
    EmptyKeysView(onCreateKey: {})
        .frame(width: 800, height: 600)
}
