//
//  MainView.swift
//  Moaiy
//
//  Main view with sidebar navigation
//

import SwiftUI

struct MainView: View {
    @State private var selectedSection: Section = .keyManagement
    
    enum Section: String, CaseIterable, Identifiable {
        case keyManagement = "Key Management"
        case encryption = "Encryption"
        case settings = "Settings"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .keyManagement: return "key.fill"
            case .encryption: return "lock.shield.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var localizedName: String {
            switch self {
            case .keyManagement: return String(localized: "section_key_management")
            case .encryption: return String(localized: "section_encryption")
            case .settings: return String(localized: "section_settings")
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(Section.allCases, selection: $selectedSection) { section in
                Label(section.localizedName, systemImage: section.icon)
            }
            .navigationTitle("Moaiy")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            // Detail view
            switch selectedSection {
            case .keyManagement:
                KeyManagementView()
            case .encryption:
                EncryptionView()
            case .settings:
                SettingsView()
            }
        }
    }
}

#Preview {
    MainView()
        .frame(width: 1000, height: 700)
}
