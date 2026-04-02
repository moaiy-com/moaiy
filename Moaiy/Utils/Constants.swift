//
//  Constants.swift
//  Moaiy
//
//  Application-wide constants and configuration values
//

import Foundation

/// Application-wide constants
enum Constants {
    
    // MARK: - GPG Configuration
    
    enum GPG {
        /// Bundle name for embedded GPG
        static let bundleName = "gpg.bundle"
        
        /// GPG executable name
        static let executableName = "gpg"
        
        /// Default timeout for GPG operations (in seconds)
        static let defaultTimeout: TimeInterval = 60
        
        /// Maximum retry attempts for GPG operations
        static let maxRetries = 3
        
        /// Initial retry delay in nanoseconds (100ms)
        static let initialRetryDelay: UInt64 = 100_000_000
        
        /// Retry delay multiplier (exponential backoff)
        static let retryDelayMultiplier = 2.0

        /// Internal cipher algorithm preference for OpenPGP encryption operations
        static let defaultCipherAlgorithm = "AES256"
    }
    
    // MARK: - UI Configuration
    
    enum UI {
        /// Maximum number of search history items to keep
        static let maxSearchHistory = 10
        
        /// Maximum number of operation history items to keep
        static let maxOperationHistory = 50
        
        /// Default window width
        static let defaultWindowWidth: CGFloat = 1000
        
        /// Default window height
        static let defaultWindowHeight: CGFloat = 700
        
        /// Minimum sidebar width
        static let minSidebarWidth: CGFloat = 180
        
        /// Ideal sidebar width
        static let idealSidebarWidth: CGFloat = 200
        
        /// Maximum sidebar width
        static let maxSidebarWidth: CGFloat = 250
    }
    
    // MARK: - File Operations
    
    enum File {
        /// Default encrypted file extension used by Moaiy
        static let defaultEncryptedExtension = "moy"
        
        /// ASCII armor file extension
        static let ascExtension = "asc"
        
        /// PGP file extension
        static let pgpExtension = "pgp"

        /// Supported encrypted file extensions
        static let encryptedExtensions: Set<String> = [
            defaultEncryptedExtension,
            "gpg",
            pgpExtension,
            "gpg2",
            "pgp2"
        ]
        
        /// Default file name suffix for decrypted files
        static let decryptedSuffix = ".decrypted"
    }
    
    // MARK: - Storage Keys
    
    enum StorageKeys {
        /// Key for encryption history in UserDefaults
        static let encryptionHistory = "com.moaiy.encryptionHistory"
        
        /// Key for backup history in UserDefaults
        static let backupHistory = "backupHistory"
        
        /// Key for last backup date in UserDefaults
        static let lastBackupDate = "lastBackupDate"
        
        /// Key for file bookmarks in UserDefaults
        static let fileBookmarks = "com.moaiy.fileBookmarks"
        
        /// Key for expiration reminder enabled
        static let expirationReminderEnabled = "expirationReminderEnabled"
        
        /// Key for expiration reminder days
        static let expirationReminderDays = "expirationReminderDays"

        /// Whether the user enabled an external GPG home directory
        static let useExternalGPGHome = "com.moaiy.useExternalGPGHome"

        /// Security-scoped bookmark for external GPG home directory
        static let externalGPGHomeBookmark = "com.moaiy.externalGPGHomeBookmark"

    }
    
    // MARK: - Backup
    
    enum Backup {
        /// Backup manifest file name
        static let manifestFileName = "manifest.json"
        
        /// Backup version
        static let currentVersion = "1.0"
    }
}

enum SecureTempStorage {
    private static let fileManager = FileManager.default
    private static let rootDirectoryName = "com.moaiy.secure-temp"
    static let staleTTL: TimeInterval = 24 * 60 * 60

    static func rootURL() throws -> URL {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw GPGError.fileAccessDenied("Caches directory")
        }

        let rootURL = cachesURL.appendingPathComponent(rootDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
        }
        return rootURL
    }

    static func makeOperationDirectory(prefix: String) throws -> URL {
        let base = try rootURL()
        let dir = base.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        return dir
    }

    static func cleanupStaleDirectories(olderThan ttl: TimeInterval = staleTTL) {
        guard let root = try? rootURL() else { return }

        let expirationDate = Date().addingTimeInterval(-ttl)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in contents {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
                continue
            }
            let modifiedAt = values.contentModificationDate ?? .distantPast
            if modifiedAt < expirationDate {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
