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
        /// GPG file extension
        static let gpgExtension = "gpg"
        
        /// ASCII armor file extension
        static let ascExtension = "asc"
        
        /// PGP file extension
        static let pgpExtension = "pgp"
        
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
    }
    
    // MARK: - Backup
    
    enum Backup {
        /// Backup manifest file name
        static let manifestFileName = "manifest.json"
        
        /// Backup version
        static let currentVersion = "1.0"
    }
}
