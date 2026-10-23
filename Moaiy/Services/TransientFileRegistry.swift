//
//  TransientFileRegistry.swift
//  Moaiy
//
//  Registry for tracking and wiping in-flight temporary files and directories.
//  Hooks into macOS application termination notifications to prevent sensitive
//  plaintext or staging fragments from lingering on disk after crashes or exits.
//

import Foundation
import AppKit
import os.log

public final class TransientFileRegistry: @unchecked Sendable {
    public static let shared = TransientFileRegistry()

    private let logger = Logger(subsystem: "com.moaiy.app", category: "TransientFileRegistry")
    private let lock = NSLock()
    private var registeredURLs = Set<URL>()
    private var exitHooks: [@Sendable () -> Void] = []
    private var isHooked = false

    private init() {}

    /// Registers a transient file or directory URL to be tracked and wiped if abruptly terminated.
    public func register(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        registeredURLs.insert(url)
    }

    /// Registers a synchronous cleanup callback to run when the application terminates (e.g. stopping gpg-agent).
    public func registerExitHook(_ hook: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        exitHooks.append(hook)
    }

    /// Unregisters an item once it has been successfully committed or cleaned up normally.
    public func unregister(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        registeredURLs.remove(url)
    }

    /// Synchronously purges all currently registered transient items from the file system.
    @discardableResult
    public func cleanupAll() -> Int {
        lock.lock()
        let urlsToClean = Array(registeredURLs)
        let hooksToRun = exitHooks
        registeredURLs.removeAll()
        lock.unlock()

        let fileManager = FileManager.default
        var cleanedCount = 0

        for url in urlsToClean {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    cleanedCount += 1
                    logger.debug("Cleaned transient item on exit: \(url.path)")
                } catch {
                    logger.error("Failed to remove transient item \(url.path): \(error.localizedDescription)")
                }
            }
        }

        for hook in hooksToRun {
            hook()
        }

        return cleanedCount
    }

    /// Sets up notification observers for application termination.
    public func setupLifecycleHooks() {
        lock.lock()
        guard !isHooked else {
            lock.unlock()
            return
        }
        isHooked = true
        lock.unlock()

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logger.notice("NSApplication willTerminate received. Initiating transient file purge...")
            _ = self?.cleanupAll()
        }

        logger.info("TransientFileRegistry lifecycle hooks successfully established.")
    }

    /// Returns currently tracked URLs count
    public var trackedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return registeredURLs.count
    }
}
