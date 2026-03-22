//
//  FileBookmarkManager.swift
//  Moaiy
//
//  Manages security-scoped bookmarks for sandbox file access
//

import Foundation
import AppKit

/// Manages security-scoped bookmarks for file and folder access in sandboxed apps
actor FileBookmarkManager {
    static let shared = FileBookmarkManager()
    
    private let defaults = UserDefaults.standard
    private let bookmarksKey = "com.moaiy.fileBookmarks"
    
    private init() {}
    
    // MARK: - Save Bookmark
    
    /// Save a security-scoped bookmark for a URL
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Whether the bookmark was saved successfully
    @discardableResult
    func saveBookmark(for url: URL) async -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            var bookmarks = loadAllBookmarks()
            bookmarks[url.path] = bookmarkData
            saveBookmarks(bookmarks)
            
            return true
        } catch {
            print("Failed to save bookmark for \(url.path): \(error)")
            return false
        }
    }
    
    // MARK: - Access Bookmark
    
    /// Access a URL from a security-scoped bookmark
    /// - Parameter path: The original path of the URL
    /// - Returns: The URL if accessible, nil otherwise
    func accessBookmark(for path: String) async -> URL? {
        let bookmarks = loadAllBookmarks()
        
        guard let bookmarkData = bookmarks[path] else {
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                // Recreate the bookmark
                await saveBookmark(for: url)
            }
            
            return url
        } catch {
            print("Failed to resolve bookmark for \(path): \(error)")
            return nil
        }
    }
    
    /// Start accessing a security-scoped resource
    /// - Parameter url: The URL to access
    /// - Returns: Whether access was granted
    func startAccessing(url: URL) -> Bool {
        if url.startAccessingSecurityScopedResource() {
            return true
        }
        return false
    }
    
    /// Stop accessing a security-scoped resource
    /// - Parameter url: The URL to stop accessing
    func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    // MARK: - Request Access
    
    /// Request user permission to access a file or folder
    /// - Parameters:
    ///   - isFolder: Whether to select a folder (true) or file (false)
    ///   - allowedTypes: UTTypes allowed for file selection
    /// - Returns: The selected URL, or nil if cancelled
    func requestAccess(isFolder: Bool = false, allowedTypes: [String]? = nil) async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = isFolder
                panel.canChooseFiles = !isFolder
                panel.message = "moaiy needs access to this \(isFolder ? "folder" : "file") for encryption operations"
                
                if let types = allowedTypes {
                    panel.allowedContentTypes = types.compactMap { UTType.fromIdentifier($0) }
                }
                
                if panel.runModal() == .OK, let url = panel.url {
                    Task {
                        await self.saveBookmark(for: url)
                        continuation.resume(returning: url)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadAllBookmarks() -> [String: Data] {
        guard let data = defaults.data(forKey: bookmarksKey) else {
            return [:]
        }
        
        do {
            return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Data] ?? [:]
        } catch {
            print("Failed to load bookmarks: \(error)")
            return [:]
        }
    }
    
    private func saveBookmarks(_ bookmarks: [String: Data]) {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: bookmarks, format: .binary, options: 0)
            defaults.set(data, forKey: bookmarksKey)
        } catch {
            print("Failed to save bookmarks: \(error)")
        }
    }
}

// MARK: - UTType Helper

import UniformTypeIdentifiers

extension UTType {
    static func fromIdentifier(_ identifier: String) -> UTType? {
        UTType(identifier)
    }
}
