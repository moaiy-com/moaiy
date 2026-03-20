//
//  KeyManagementView.swift
//  Moaiy
//
//  Key management main view
//

import SwiftUI

struct KeyManagementView: View {
    @State private var keys: [Key] = []
    @State private var searchText = ""
    @State private var showingCreateKey = false
    
    var body: some View {
        Group {
            if keys.isEmpty {
                EmptyKeysView(onCreateKey: { showingCreateKey = true })
            } else {
                KeyListView(keys: $keys, searchText: $searchText)
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
                Button(action: { }) {
                    Label("Import Key", systemImage: "square.and.arrow.down")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search keys...")
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
    @Binding var keys: [Key]
    @Binding var searchText: String
    
    var filteredKeys: [Key] {
        if searchText.isEmpty {
            return keys
        }
        return keys.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List(filteredKeys) { key in
            KeyCardView(key: key)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.inset)
    }
}

// MARK: - Key Card View
struct KeyCardView: View {
    let key: Key
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(Color.moiayAccent)
                .frame(width: 40, height: 40)
                .background(Color.moiayAccent.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(key.name)
                    .font(.headline)
                
                Text(key.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label(key.type, systemImage: "number")
                    Text("•")
                    Text(key.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button("Encrypt") { }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Button { } label: {
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
}

#Preview("Empty State") {
    EmptyKeysView(onCreateKey: {})
        .frame(width: 800, height: 600)
}

#Preview("Key List") {
    KeyListView(keys: .constant([
        Key(name: "Work Key", email: "work@example.com", type: "RSA-4096"),
        Key(name: "Personal Key", email: "personal@example.com", type: "RSA-4096")
    ]), searchText: .constant(""))
    .frame(width: 800, height: 600)
}
