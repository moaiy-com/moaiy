//
//  RecipientKeyPicker.swift
//  Moaiy
//
//  Component for selecting recipient keys for encryption
//

import SwiftUI

struct RecipientKeyPicker: View {
    @Bindable var viewModel: EncryptionViewModel
    @State private var searchText = ""
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Color.moaiyAccent)
                    
                    Text("recipient_keys_title")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !viewModel.selectedRecipientKeys.isEmpty {
                        Text("\(viewModel.selectedRecipientKeys.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.moaiyAccent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Search and quick actions
                    HStack {
                        TextField("prompt_search_keys", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                        
                        Spacer()
                        
                        Button("action_select_all") {
                            viewModel.selectAllRecipients()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .disabled(viewModel.availableRecipientKeys.isEmpty)
                        
                        Button("action_clear") {
                            viewModel.clearAllRecipients()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .disabled(viewModel.selectedRecipientKeys.isEmpty)
                    }
                    
                    Divider()
                    
                    // Key list
                    if filteredKeys.isEmpty {
                        if viewModel.availableRecipientKeys.isEmpty {
                            Text("no_keys_available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            Text("no_keys_match_search")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(filteredKeys) { key in
                                    RecipientKeyRow(
                                        key: key,
                                        isSelected: viewModel.selectedRecipientKeys.contains(key.fingerprint)
                                    ) {
                                        viewModel.toggleRecipientKey(key)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var filteredKeys: [GPGKey] {
        if searchText.isEmpty {
            return viewModel.availableRecipientKeys
        }
        return viewModel.availableRecipientKeys.filter { key in
            key.name.localizedCaseInsensitiveContains(searchText) ||
            key.email.localizedCaseInsensitiveContains(searchText) ||
            key.fingerprint.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Recipient Key Row

struct RecipientKeyRow: View {
    let key: GPGKey
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.moaiyAccent : .secondary)
                    .font(.title3)
                
                // Key info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(key.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        if key.isExpired {
                            Text("status_expired")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(key.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Key type
                Text(key.displayKeyType)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.moaiyAccent.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let vm = EncryptionViewModel()
    
    return VStack {
        RecipientKeyPicker(viewModel: vm)
            .padding()
    }
    .frame(width: 500)
}
