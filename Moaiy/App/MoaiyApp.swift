//
//  MoaiyApp.swift
//  Moaiy
//
//  Guard Your Secrets Like Moai
//

import SwiftUI
import os.log
#if os(macOS)
import AppKit
#endif

private let logger = Logger(subsystem: "com.moaiy.app", category: "App")

@main
struct MoaiyApp: App {
    init() {
        SecureTempStorage.cleanupStaleDirectories()
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
        .commands {
            CommandGroup(after: .help) {
                Button("section_how_to") {
                    openHelpPage()
                }
            }
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    #if os(macOS)
    private var helpURL: URL? {
        URL(string: "https://moaiy.com/doc/help")
    }
    #endif

    #if os(macOS)
    private func openHelpPage() {
        guard let helpURL else {
            logger.error("Invalid help URL.")
            return
        }
        NSWorkspace.shared.open(helpURL)
    }
    #endif
}
