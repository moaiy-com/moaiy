import SwiftUI

// MARK: - Main View

struct MainView: View {
    @State private var selectedTab: SidebarTab = .keys
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            switch selectedTab {
            case .keys:
                KeysListView(searchText: searchText)
            case .encrypt:
                EncryptView()
            case .decrypt:
                DecryptView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
        .searchable(text: $searchText, prompt: "Search keys...")
        .navigationTitle("Moaiy")
    }
}

// MARK: - Sidebar

enum SidebarTab: String, CaseIterable {
    case keys = "Keys"
    case encrypt = "Encrypt"
    case decrypt = "Decrypt"
    case history = "History"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .keys: return "key.fill"
        case .encrypt: return "lock.fill"
        case .decrypt: return "lock.open.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    
    var body: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Create new key
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Keys List View

struct KeysListView: View {
    var searchText: String
    
    // Sample data
    let keys: [Key] = [
        Key(name: "Primary Key", email: "alice@example.com", status: .valid),
        Key(name: "Work Key", email: "alice@company.com", status: .expiringSoon),
        Key(name: "Backup Key", email: "backup@example.com", status: .valid)
    ]
    
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
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header Stats
                HStack(spacing: 16) {
                    StatCard(title: "Total Keys", value: "\(keys.count)", icon: "key.fill", color: .securityGreen)
                    StatCard(title: "Valid", value: "\(keys.filter { $0.status == .valid }.count)", icon: "checkmark.shield.fill", color: .moaiSuccess)
                    StatCard(title: "Expiring", value: "\(keys.filter { $0.status == .expiringSoon }.count)", icon: "exclamationmark.triangle.fill", color: .moaiWarning)
                }
                .padding(.bottom, 8)
                
                // Keys List
                ForEach(filteredKeys) { key in
                    KeyCard(
                        key: key,
                        onEncrypt: { print("Encrypt with \(key.name)") },
                        onShare: { print("Share \(key.name)") },
                        onBackup: { print("Backup \(key.name)") },
                        onMore: { print("More options for \(key.name)") }
                    )
                }
                
                // Empty State
                if filteredKeys.isEmpty && !keys.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.moaiTextTertiary)
                        Text("No keys match your search")
                            .font(.headline)
                            .foregroundStyle(.moaiTextSecondary)
                    }
                    .padding(.top, 40)
                }
                
                // Create Key Button
                if keys.isEmpty {
                    EmptyStateCard(
                        icon: "key.slash",
                        title: "No Keys Yet",
                        description: "Create your first encryption key to start protecting your secrets.",
                        actionTitle: "Create Key",
                        action: { print("Create new key") }
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("My Keys")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PrimaryButton("New Key", systemImage: "plus") {
                    print("Create new key")
                }
            }
        }
    }
}

// MARK: - Encrypt View

struct EncryptView: View {
    @State private var selectedKeyType: EncryptType = .text
    @State private var textContent = ""
    @State private var selectedKey: Key?
    @State private var showSuccess = false
    
    enum EncryptType {
        case text
        case file
    }
    
    let sampleKeys = [
        Key(name: "Primary Key", email: "alice@example.com"),
        Key(name: "Work Key", email: "alice@company.com")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Type Picker
                Picker("Type", selection: $selectedKeyType) {
                    Text("Text").tag(EncryptType.text)
                    Text("File").tag(EncryptType.file)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                
                if selectedKeyType == .text {
                    // Text Encryption
                    TextDropZone(
                        text: $textContent,
                        placeholder: "Enter the text you want to encrypt..."
                    )
                } else {
                    // File Encryption
                    FileDropZoneWithPreview { urls in
                        print("Files selected: \(urls)")
                    }
                }
                
                // Key Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encrypt with")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.moaiTextPrimary)
                    
                    Picker("Key", selection: $selectedKey) {
                        Text("Select a key...").tag(nil as Key?)
                        ForEach(sampleKeys) { key in
                            Text("\(key.name) (\(key.email))").tag(key as Key?)
                        }
                    }
                    .frame(maxWidth: 400)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    PrimaryButton("Encrypt", systemImage: "lock.fill") {
                        performEncryption()
                    }
                    .disabled(selectedKeyType == .text ? textContent.isEmpty : false)
                    
                    Button("Clear") {
                        textContent = ""
                    }
                    .buttonStyle(TertiaryButtonStyle())
                }
                
                // Success Message
                if showSuccess {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.moaiSuccess)
                        Text("Content encrypted successfully!")
                            .font(.subheadline)
                            .foregroundStyle(.moaiSuccess)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.moaiSuccess.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
            .padding()
        }
        .navigationTitle("Encrypt")
    }
    
    private func performEncryption() {
        // Simulate encryption
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showSuccess = false
        }
    }
}

// MARK: - Decrypt View

struct DecryptView: View {
    @State private var encryptedContent = ""
    @State private var decryptedContent = ""
    @State private var password = ""
    @State private var showDecrypted = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Encrypted Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encrypted Content")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.moaiTextPrimary)
                    
                    TextEditor(text: $encryptedContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.moaiSurface)
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.moaiBorder, lineWidth: 1)
                        )
                }
                
                // Password
                MoaiySecureField("Password", text: $password, placeholder: "Enter your key password")
                
                // Decrypt Button
                PrimaryButton("Decrypt", systemImage: "lock.open.fill") {
                    performDecryption()
                }
                .disabled(encryptedContent.isEmpty || password.isEmpty)
                
                // Decrypted Content
                if showDecrypted {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Decrypted Content")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.moaiTextPrimary)
                            
                            Spacer()
                            
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(decryptedContent, forType: .string)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        
                        Text(decryptedContent)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.moaiSuccess.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding()
        }
        .navigationTitle("Decrypt")
    }
    
    private func performDecryption() {
        // Simulate decryption
        decryptedContent = "This is the decrypted content of your message."
        showDecrypted = true
    }
}

// MARK: - History View

struct HistoryView: View {
    struct HistoryItem: Identifiable {
        let id = UUID()
        let action: String
        let date: Date
        let status: String
        
        var formattedDate: String {
            let formatter = RelativeDateTimeFormatter()
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
    
    let historyItems: [HistoryItem] = [
        HistoryItem(action: "Encrypted wallet-backup.txt", date: Date().addingTimeInterval(-3600), status: "Success"),
        HistoryItem(action: "Decrypted message from bob@example.com", date: Date().addingTimeInterval(-7200), status: "Success"),
        HistoryItem(action: "Created new key: Work Key", date: Date().addingTimeInterval(-86400), status: "Success"),
        HistoryItem(action: "Exported public key", date: Date().addingTimeInterval(-172800), status: "Success")
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(historyItems) { item in
                    HStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.moaiSuccess)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.action)
                                .font(.subheadline)
                                .foregroundStyle(.moaiTextPrimary)
                            
                            Text(item.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.moaiTextTertiary)
                        }
                        
                        Spacer()
                        
                        StatusBadge(item.status, type: .success, showIcon: false)
                    }
                    .padding(16)
                    .background(Color.moaiSurface)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.moaiBorder, lineWidth: 1)
                    )
                }
            }
            .padding()
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear History") {
                    print("Clear history")
                }
                .buttonStyle(TertiaryButtonStyle())
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage("backupFrequency") private var backupFrequency = "Weekly"
    @AppStorage("showNotifications") private var showNotifications = true
    
    var body: some View {
        Form {
            Section("Backup") {
                Toggle("Auto Backup", isOn: $autoBackup)
                
                Picker("Backup Frequency", selection: $backupFrequency) {
                    Text("Daily").tag("Daily")
                    Text("Weekly").tag("Weekly")
                    Text("Monthly").tag("Monthly")
                }
                .disabled(!autoBackup)
                
                HStack {
                    Text("Last Backup")
                    Spacer()
                    Text("2 hours ago")
                        .foregroundStyle(.moaiTextSecondary)
                }
            }
            
            Section("Notifications") {
                Toggle("Show Notifications", isOn: $showNotifications)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.moaiTextSecondary)
                }
                
                HStack {
                    Text("License")
                    Spacer()
                    Text("MIT")
                        .foregroundStyle(.moaiTextSecondary)
                }
                
                Link(destination: URL(string: "https://moaiy.com")!) {
                    HStack {
                        Text("Website")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.moaiInfo)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

// MARK: - App Entry Point

@main
struct MoaiyApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Key") {
                    // Create new key
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        
        // Settings Window
        Settings {
            SettingsView()
                .frame(width: 500, height: 400)
        }
    }
}

// MARK: - Preview

#Preview("Main View") {
    MainView()
        .frame(width: 1000, height: 700)
}
