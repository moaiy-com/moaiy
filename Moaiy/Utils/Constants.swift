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

        /// Default public keyserver host.
        static let defaultKeyserver = "keys.openpgp.org"

        /// Supported public keyserver hosts in UI pickers (HKPS/TLS only).
        static let supportedKeyservers: [String] = [
            defaultKeyserver,
            "keyserver.ubuntu.com"
        ]
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

        /// Minimum window width to keep key cards fully visible
        static let minWindowWidth: CGFloat = 880

        /// Minimum window height for core key management layout
        static let minWindowHeight: CGFloat = 620
        
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

        /// App language preference
        static let appLanguageCode = "appLanguageCode"

        /// Feature toggle for exposing key-signing action in key menu
        static let enableKeySigningMenu = "enableKeySigningMenu"

        /// Last successful Pro entitlement refresh timestamp (seconds since 1970).
        static let proEntitlementLastRefresh = "proEntitlementLastRefresh"

    }
    
    // MARK: - Backup
    
    enum Backup {
        /// Backup manifest file name
        static let manifestFileName = "manifest.json"
        
        /// Backup version
        static let currentVersion = "1.1"

        /// Maximum accepted backup key file size during restore (10 MB)
        static let maxImportFileSizeBytes = 10 * 1024 * 1024
    }

    // MARK: - Pro / Commercial

    enum Pro {
        /// Semantic version for the open Pro contracts surface.
        static let contractsSemanticVersion = "1.3.0"

        /// App Store product IDs for Pro feature unlocks.
        static let featureToProductID: [ProFeature: String] = [
            .hardwareKeyAdvanced: "com.moaiy.pro.hardware_key_advanced",
            .batchGovernance: "com.moaiy.pro.batch_governance",
            .auditExport: "com.moaiy.pro.audit_export",
            .teamPolicyTemplates: "com.moaiy.pro.team_policy_templates"
        ]

        static let productToFeatureMap: [String: ProFeature] = Dictionary(
            uniqueKeysWithValues: featureToProductID.map { ($1, $0) }
        )
    }
}

enum AppLanguageOption: String, CaseIterable {
    case system
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case spanish = "es"
    case portugueseBrazil = "pt-BR"
    case hindi = "hi"
    case arabic = "ar"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"

    private struct Metadata {
        let localeIdentifier: String?
        let settingsDisplayKey: String
    }

    static func from(storageValue: String) -> AppLanguageOption {
        AppLanguageOption(rawValue: storageValue) ?? .system
    }

    var settingsDisplayKey: String {
        metadata.settingsDisplayKey
    }

    var localizationCode: String? {
        metadata.localeIdentifier
    }

    var locale: Locale {
        guard let localeIdentifier = metadata.localeIdentifier else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: localeIdentifier)
    }

    private var metadata: Metadata {
        switch self {
        case .system:
            return Metadata(localeIdentifier: nil, settingsDisplayKey: "setting_language_option_system")
        case .english:
            return Metadata(localeIdentifier: "en", settingsDisplayKey: "setting_language_option_english")
        case .chineseSimplified:
            return Metadata(localeIdentifier: "zh-Hans", settingsDisplayKey: "setting_language_option_chinese_simplified")
        case .spanish:
            return Metadata(localeIdentifier: "es", settingsDisplayKey: "setting_language_option_spanish")
        case .portugueseBrazil:
            return Metadata(localeIdentifier: "pt-BR", settingsDisplayKey: "setting_language_option_portuguese_brazil")
        case .hindi:
            return Metadata(localeIdentifier: "hi", settingsDisplayKey: "setting_language_option_hindi")
        case .arabic:
            return Metadata(localeIdentifier: "ar", settingsDisplayKey: "setting_language_option_arabic")
        case .french:
            return Metadata(localeIdentifier: "fr", settingsDisplayKey: "setting_language_option_french")
        case .german:
            return Metadata(localeIdentifier: "de", settingsDisplayKey: "setting_language_option_german")
        case .japanese:
            return Metadata(localeIdentifier: "ja", settingsDisplayKey: "setting_language_option_japanese")
        case .korean:
            return Metadata(localeIdentifier: "ko", settingsDisplayKey: "setting_language_option_korean")
        case .russian:
            return Metadata(localeIdentifier: "ru", settingsDisplayKey: "setting_language_option_russian")
        }
    }
}

enum AppLocalization {
    static var selectedLanguage: AppLanguageOption {
        let storedLanguage = UserDefaults.standard.string(forKey: Constants.StorageKeys.appLanguageCode)
            ?? AppLanguageOption.system.rawValue
        return AppLanguageOption.from(storageValue: storedLanguage)
    }

    static var locale: Locale {
        selectedLanguage.locale
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: localizedBundle, locale: locale)
    }

    static func localizedString(forKey key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private static var localizedBundle: Bundle {
        guard let languageCode = selectedLanguage.localizationCode else {
            return .main
        }

        return bundle(for: languageCode)
            ?? fallbackBundle(for: languageCode)
            ?? .main
    }

    private static func bundle(for languageIdentifier: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: languageIdentifier, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    private static func fallbackBundle(for languageIdentifier: String) -> Bundle? {
        let normalizedLanguageIdentifier = languageIdentifier.replacingOccurrences(of: "_", with: "-")
        let parts = normalizedLanguageIdentifier.split(separator: "-")
        guard parts.count > 1, let baseLanguageCode = parts.first else {
            return nil
        }
        return bundle(for: String(baseLanguageCode))
    }
}

enum SecureTempStorage {
    private static var fileManager: FileManager { FileManager.default }
    private static let rootDirectoryName = "com.moaiy.secure-temp"
    static let staleTTL: TimeInterval = 24 * 60 * 60

    static func rootURL() throws -> URL {
        if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let candidateURL = cachesURL.appendingPathComponent(rootDirectoryName, isDirectory: true)
            if fileManager.fileExists(atPath: candidateURL.path) {
                if fileManager.isWritableFile(atPath: candidateURL.path) {
                    return candidateURL
                }
            } else if (try? fileManager.createDirectory(at: candidateURL, withIntermediateDirectories: true)) != nil {
                try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: candidateURL.path)
                return candidateURL
            }
        }

        // Fallback to temporaryDirectory when running in CLI/CI test sandboxes where ~/Library/Caches is restricted
        let fallbackURL = fileManager.temporaryDirectory.appendingPathComponent(rootDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: fallbackURL.path) {
            try fileManager.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fallbackURL.path)
        }
        return fallbackURL
    }

    static func makeOperationDirectory(prefix: String) throws -> URL {
        let base = try rootURL()
        let dir = base.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        TransientFileRegistry.shared.register(url: dir)
        return dir
    }

    static func removeOperationDirectory(_ url: URL) {
        TransientFileRegistry.shared.unregister(url: url)
        zeroScrubDirectoryContents(at: url)
        try? fileManager.removeItem(at: url)
    }

    /// Best-effort zero-overwrites regular files inside a temporary operation directory prior to unlink.
    private static func zeroScrubDirectoryContents(at directoryURL: URL) {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else {
            return
        }

        let zeroChunk = [UInt8](repeating: 0, count: 64 * 1024)
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            let size = max(0, values.fileSize ?? 0)
            guard size > 0 else { continue }
            let fd = open(fileURL.path, O_WRONLY)
            guard fd >= 0 else { continue }
            var remaining = size
            zeroChunk.withUnsafeBytes { rawBuf in
                guard let base = rawBuf.baseAddress else { return }
                while remaining > 0 {
                    let toWrite = min(remaining, zeroChunk.count)
                    let written = write(fd, base, toWrite)
                    if written <= 0 { break }
                    remaining -= written
                }
            }
            _ = fsync(fd)
            _ = close(fd)
        }
    }

    /// Commits a staged temporary file to the user-selected destination after checking net available volume space.
    /// When overwriting an existing file, updates the inode in place with a container-backed rollback backup
    /// so original data is never lost on permission/sandbox/I/O failure and NSSavePanel authorization is preserved.
    static func commitStagedFile(
        from stagedURL: URL,
        to destinationURL: URL,
        availableCapacityOverride: Int64? = nil
    ) throws {
        let stagedSize = (try? fileManager.attributesOfItem(atPath: stagedURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        let existingExists = fileManager.fileExists(atPath: destinationURL.path)
        let existingSize: Int64 = existingExists
            ? ((try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0)
            : 0
        let netRequiredBytes = max(0, stagedSize - existingSize)

        let parentDir = destinationURL.deletingLastPathComponent()
        let available: Int64?
        if let availableCapacityOverride {
            available = availableCapacityOverride
        } else {
            var statBuf = statfs()
            if statfs(parentDir.path, &statBuf) == 0 {
                available = Int64(statBuf.f_bavail) * Int64(statBuf.f_bsize)
            } else if let values = try? parentDir.resourceValues(forKeys: [
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ]) {
                if let stdCap = values.volumeAvailableCapacity, stdCap > 0 {
                    available = Int64(stdCap)
                } else if let impCap = values.volumeAvailableCapacityForImportantUsage, impCap > 0 {
                    available = impCap
                } else {
                    available = nil
                }
            } else {
                available = nil
            }
        }

        if let available, available < netRequiredBytes {
            throw GPGError.executionFailed("Insufficient disk space on destination volume (\(netRequiredBytes) net bytes required, \(available) bytes available)")
        }

        guard existingExists else {
            try fileManager.copyItem(at: stagedURL, to: destinationURL)
            return
        }

        let backupDir = try makeOperationDirectory(prefix: "commit-rollback")
        defer { removeOperationDirectory(backupDir) }
        let rollbackURL = backupDir.appendingPathComponent("original.bak")
        try fileManager.copyItem(at: destinationURL, to: rollbackURL)

        // Open O_WRONLY without O_TRUNC first so permission or sandbox denial fails before modifying original bytes
        let destFd = open(destinationURL.path, O_WRONLY)
        guard destFd >= 0 else {
            let err = errno
            throw GPGError.executionFailed("Failed to open destination file for writing: \(String(cString: strerror(err)))")
        }
        defer { close(destFd) }

        let srcFd = open(stagedURL.path, O_RDONLY)
        guard srcFd >= 0 else {
            let err = errno
            throw GPGError.executionFailed("Failed to open staged file for reading: \(String(cString: strerror(err)))")
        }
        defer { close(srcFd) }

        do {
            guard ftruncate(destFd, 0) == 0 else {
                throw GPGError.executionFailed("Failed to truncate destination file: \(String(cString: strerror(errno)))")
            }
            try copyDescriptorContents(from: srcFd, to: destFd)
            guard fsync(destFd) == 0 else {
                throw GPGError.executionFailed("Failed to sync destination file: \(String(cString: strerror(errno)))")
            }
        } catch {
            let rbFd = open(rollbackURL.path, O_RDONLY)
            if rbFd >= 0 {
                defer { close(rbFd) }
                _ = lseek(destFd, 0, SEEK_SET)
                _ = ftruncate(destFd, 0)
                try? copyDescriptorContents(from: rbFd, to: destFd)
                _ = fsync(destFd)
            }
            throw error
        }
    }

    private static func copyDescriptorContents(from srcFd: Int32, to destFd: Int32) throws {
        let bufferSize = 256 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while true {
            let bytesRead = buffer.withUnsafeMutableBytes { rawBuf -> Int in
                guard let base = rawBuf.baseAddress else { return -1 }
                return read(srcFd, base, bufferSize)
            }
            if bytesRead == 0 { break }
            if bytesRead < 0 {
                throw GPGError.executionFailed("Read error while committing file: \(String(cString: strerror(errno)))")
            }
            var offset = 0
            while offset < bytesRead {
                let bytesWritten = buffer.withUnsafeBytes { rawBuf -> Int in
                    guard let base = rawBuf.baseAddress else { return -1 }
                    return write(destFd, base.advanced(by: offset), bytesRead - offset)
                }
                if bytesWritten <= 0 {
                    throw GPGError.executionFailed("Write error while committing file: \(String(cString: strerror(errno)))")
                }
                offset += bytesWritten
            }
        }
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
