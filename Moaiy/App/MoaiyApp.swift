//
//  MoaiyApp.swift
//  Moaiy
//
//  Guard Your Secrets Like Moai
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.moaiy.app", category: "App")

@main
struct MoaiyApp: App {
    init() {
        logger.notice("========== Moaiy App Starting ==========")
        logger.notice("GPGService.isReady: \(GPGService.shared.isReady)")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    logger.notice("MainView appeared")
                    logger.notice("GPGService.isReady after view appear: \(GPGService.shared.isReady)")
                }
        }
        .windowStyle(.automatic)
        .defaultSize(
            width: Constants.UI.defaultWindowWidth,
            height: Constants.UI.defaultWindowHeight
        )
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
