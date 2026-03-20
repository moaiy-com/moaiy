//
//  MoaiyApp.swift
//  Moaiy
//
//  Guard Your Secrets Like Moai
//

import SwiftUI

@main
struct MoaiyApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
