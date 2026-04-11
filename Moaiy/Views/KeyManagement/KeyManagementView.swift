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
    @State private var promptAlert: PromptAlertContent?

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
        .navigationTitle("app_name_moaiy")
        .background {
            Color.moaiySurfaceBackground.ignoresSafeArea()
            brandBackgroundView
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateKey = true }) {
                    Label("action_create_key", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: MoaiyUI.Radius.md))
                .tint(Color.moaiyAccentV2)
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { Task { await viewModel.refresh() } }) {
                    Label("action_refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: MoaiyUI.Radius.md))
                .tint(Color.moaiyAccentV2)
                .keyboardShortcut("r", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingImportKey = true }) {
                    Label("action_import_key", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: MoaiyUI.Radius.md))
                .tint(Color.moaiyAccentV2)
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
        .moaiyPromptAlertHost(alert: $promptAlert)
        .onAppear {
            syncPromptIfNeeded()
        }
        .onChange(of: keyToDelete) { _, _ in
            syncPromptIfNeeded()
        }
        .onChange(of: viewModel.errorMessage) { _, _ in
            syncPromptIfNeeded()
        }
        .onChange(of: viewModel.errorContext) { _, _ in
            syncPromptIfNeeded()
        }
    }

    private func syncPromptIfNeeded() {
        if let key = keyToDelete {
            promptAlert = makeDeleteConfirmationPrompt(for: key)
            return
        }

        updateErrorPromptIfNeeded()
    }

    private func makeDeleteConfirmationPrompt(for key: GPGKey) -> PromptAlertContent {
        PromptAlertContent.destructiveConfirmation(
            title: "confirm_delete_key_title",
            message: String(
                format: String(localized: "confirm_delete_key_message"),
                locale: Locale.current,
                key.name
            ),
            confirmTitle: "action_delete",
            onConfirm: {
                keyToDelete = nil
                Task {
                    do {
                        try await viewModel.deleteKey(key)
                    } catch {
                        // Error will be handled by viewModel.errorMessage
                    }
                }
            },
            onCancel: {
                keyToDelete = nil
            },
            onDismiss: {
                keyToDelete = nil
            }
        )
    }

    private func updateErrorPromptIfNeeded() {
        guard let message = viewModel.errorMessage else {
            promptAlert = nil
            return
        }

        promptAlert = PromptAlertContent.retryableFailure(
            title: LocalizedStringKey(UserFacingErrorMapper.alertTitleKey(for: viewModel.errorContext)),
            message: message,
            onRetry: {
                viewModel.clearError()
                Task { await viewModel.refresh() }
            },
            onCancel: {
                viewModel.clearError()
            },
            onDismiss: {
                viewModel.clearError()
            }
        )
    }

    private var brandBackgroundView: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72.8)
                    .accessibilityHidden(true)

                Text("brand_tagline_drag_and_drop")
                    .font(.custom("ScopeOne-Regular", size: 13))
                    .foregroundStyle(Color(red: 196.0 / 255.0, green: 196.0 / 255.0, blue: 196.0 / 255.0))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            .opacity(0.92)
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Empty State View

struct EmptyKeysView: View {
    let onCreateKey: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.moaiyTextSecondary)
            
            Text("empty_keys_title")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.moaiyTextPrimary)
            
            Text("empty_keys_description")
                .font(.body)
                .foregroundStyle(Color.moaiyTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button(action: onCreateKey) {
                Label("action_create_first_key", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: MoaiyUI.Radius.md))
            .tint(Color.moaiyAccentV2)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.moaiySurfaceBackground)
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
            .listRowBackground(Color.clear)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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
