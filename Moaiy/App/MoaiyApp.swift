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
import CoreText
#endif

private let logger = Logger(subsystem: "com.moaiy.app", category: "App")

@main
struct MoaiyApp: App {
    @AppStorage(Constants.StorageKeys.appLanguageCode) private var appLanguageCode = AppLanguageOption.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        SecureTempStorage.cleanupStaleDirectories()
        AppFontRegistrar.registerBundledFonts()
        logger.notice("========== Moaiy App Starting ==========")
        logger.notice("GPGService.isReady: \(GPGService.shared.isReady)")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .id("main-\(appLanguageCode)")
                .frame(
                    minWidth: Constants.UI.minWindowWidth,
                    minHeight: Constants.UI.minWindowHeight
                )
                .environment(\.locale, appLocale)
                .onAppear {
                    logger.notice("MainView appeared")
                    logger.notice("GPGService.isReady after view appear: \(GPGService.shared.isReady)")
                }
                .task {
                    await AppState.shared.proRuntime.refreshEntitlements()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await AppState.shared.proRuntime.refreshEntitlements()
                    }
                }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentMinSize)
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
                .id("settings-\(appLanguageCode)")
                .environment(\.locale, appLocale)
        }
        #endif
    }

    private var appLocale: Locale {
        AppLanguageOption.from(storageValue: appLanguageCode).locale
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

private enum AppFontRegistrar {
    static func registerBundledFonts() {
        registerFont(resourceName: "ScopeOne-Regular", extension: "ttf")
    }

    private static func registerFont(resourceName: String, extension fileExtension: String) {
        guard let fontURL = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            logger.error("Font resource not found: \(resourceName).\(fileExtension)")
            return
        }

        var registrationError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError)
        if registered {
            logger.notice("Registered bundled font: \(resourceName).\(fileExtension)")
            return
        }

        if let error = registrationError?.takeRetainedValue() {
            logger.warning("Font registration skipped or failed for \(resourceName).\(fileExtension): \(error.localizedDescription)")
        }
    }
}
