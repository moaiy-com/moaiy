//
//  MainView.swift
//  Moaiy
//
//  Main view with sidebar navigation
//

import SwiftUI

struct MainView: View {
    @State private var selectedSection: Section? = .keyManagement
    
    enum Section: String, CaseIterable, Identifiable {
        case keyManagement
        case encryption
        case settings
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .keyManagement: return "key.fill"
            case .encryption: return "lock.shield.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var title: LocalizedStringKey {
            switch self {
            case .keyManagement: return "section_key_management"
            case .encryption: return "section_encryption"
            case .settings: return "section_settings"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Moaiy")
            .navigationSplitViewColumnWidth(
                min: Constants.UI.minSidebarWidth,
                ideal: Constants.UI.idealSidebarWidth,
                max: Constants.UI.maxSidebarWidth
            )
        } detail: {
            if let section = selectedSection {
                switch section {
                case .keyManagement:
                    KeyManagementView()
                case .encryption:
                    EncryptionView()
                case .settings:
                    SettingsView()
                }
            } else {
                Text("placeholder_select_section")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    MainView()
        .frame(width: 1000, height: 700)
}
