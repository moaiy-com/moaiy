//
//  GPGFileTypeDetector.swift
//  Moaiy
//
//  Detects GPG file types using hybrid approach:
//  1. Binary signature detection (fast)
//  2. GPG command verification (accurate)
//

import Foundation
import os.log

/// Types of GPG files that can be detected
enum GPGFileType: Equatable {
    case encrypted      // Encrypted message/file - needs decryption
    case publicKey      // Public key block - needs import
    case privateKey     // Private key block - needs import
    case signature      // Signature file - needs verification
    case notGPG         // Not a GPG file - can be encrypted
    case unknown        // Cannot determine
}

/// Actor for detecting GPG file types off the main thread
actor GPGFileTypeDetector {
    
    private let logger = Logger(subsystem: "com.moaiy.app", category: "GPGFileTypeDetector")
    
    // MARK: - ASCII Armor Headers
    
    private static let armorHeaders: [(pattern: String, type: GPGFileType)] = [
        ("-----BEGIN PGP MESSAGE-----", .encrypted),
        ("-----BEGIN PGP PUBLIC KEY BLOCK-----", .publicKey),
        ("-----BEGIN PGP PRIVATE KEY BLOCK-----", .privateKey),
        ("-----BEGIN PGP SIGNATURE-----", .signature),
        ("-----BEGIN PGP ARMORED FILE-----", .encrypted),
        ("-----BEGIN PGP SIGNED MESSAGE-----", .signature)
    ]
    
    // MARK: - OpenPGP Packet Tags
    
    /// Packet tags for encrypted content (new format)
    private static let encryptedPacketTags: Set<UInt8> = [
        1,   // Public-Key Encrypted Session Key (PKESK)
        3,   // Symmetric-Key Encrypted Session Key (SKESK)
        9,   // Symmetrically Encrypted Data (SED)
        18,  // Symmetrically Encrypted Integrity-Protected (SEIP)
        20   // Modification Detection Code (MDC)
    ]
    
    /// Packet tags for key data
    private static let keyPacketTags: Set<UInt8> = [
        5,   // Secret-Key
        6,   // Public-Key
        7,   // Secret-Subkey
        14   // Public-Subkey
    ]
    
    /// Packet tags for signatures
    private static let signaturePacketTags: Set<UInt8> = [
        2,   // Signature
        4    // One-Pass Signature
    ]
    
    // MARK: - Detection
    
    /// Detect the type of a GPG file using hybrid approach
    /// - Parameter url: File URL to detect
    /// - Returns: Detected GPG file type
    func detectFileType(at url: URL) async -> GPGFileType {
        logger.debug("Detecting file type for: \(url.path)")
        
        // Step 1: Quick binary signature detection
        if let quickResult = await quickDetect(at: url) {
            logger.debug("Quick detection result: \(String(describing: quickResult))")
            
            // For encrypted/key files, verify with GPG for accuracy
            switch quickResult {
            case .encrypted, .publicKey, .privateKey:
                let verified = await verifyWithGPG(url: url)
                logger.debug("GPG verification result: \(verified)")
                return verified ? quickResult : .notGPG
            case .signature, .notGPG, .unknown:
                return quickResult
            }
        }
        
        // Step 2: If quick detection failed, try GPG verification
        logger.debug("Quick detection inconclusive, trying GPG verification")
        let verified = await verifyWithGPG(url: url)
        return verified ? .encrypted : .notGPG
    }
    
    /// Quick detection using binary signatures (reads first 100 bytes)
    /// - Parameter url: File URL
    /// - Returns: Detected type or nil if inconclusive
    private func quickDetect(at url: URL) async -> GPGFileType? {
        do {
            // Read first 100 bytes for signature detection
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            
            let headerData = handle.readData(ofLength: 100)
            guard !headerData.isEmpty else { return .notGPG }
            
            // Check ASCII Armored format
            if let headerString = String(data: headerData, encoding: .utf8) {
                for (pattern, type) in Self.armorHeaders {
                    if headerString.contains(pattern) {
                        logger.debug("Found ASCII armor header: \(pattern)")
                        return type
                    }
                }
            }
            
            // Check Binary OpenPGP format
            if let binaryResult = detectBinaryPacket(data: headerData) {
                return binaryResult
            }
            
            return nil
        } catch {
            logger.error("Failed to read file header: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Detect binary OpenPGP packet format
    /// - Parameter data: File header data
    /// - Returns: Detected type or nil if not a valid OpenPGP packet
    private func detectBinaryPacket(data: Data) -> GPGFileType? {
        guard let firstByte = data.first else { return nil }
        
        // Bit 7 must be 1 for OpenPGP packets
        guard (firstByte & 0x80) == 0x80 else {
            logger.debug("Invalid OpenPGP packet: bit 7 not set")
            return nil
        }
        
        // Determine packet format and extract tag
        let isNewFormat = (firstByte & 0x40) == 0x40
        let tag: UInt8
        
        if isNewFormat {
            // New format: tag is in bits 5-0
            tag = firstByte & 0x3F
            logger.debug("New format packet, tag: \(tag)")
        } else {
            // Old format: tag is in bits 5-2
            tag = (firstByte & 0x3C) >> 2
            logger.debug("Old format packet, tag: \(tag)")
        }
        
        // Check packet type
        if Self.encryptedPacketTags.contains(tag) {
            return .encrypted
        }
        if Self.keyPacketTags.contains(tag) {
            // Could be public or private key, need to check further
            // For simplicity, return publicKey (most common for import)
            return .publicKey
        }
        if Self.signaturePacketTags.contains(tag) {
            return .signature
        }
        
        // Valid OpenPGP packet but unknown type
        logger.debug("Valid OpenPGP packet with unknown tag: \(tag)")
        return nil
    }
    
    /// Verify file with GPG command
    /// - Parameter url: File URL
    /// - Returns: True if file is a valid GPG file
    private func verifyWithGPG(url: URL) async -> Bool {
        let isValid = await GPGService.shared.verifyGPGFile(at: url)
        logger.debug("GPG verification for \(url.path): \(isValid ? "valid" : "invalid")")
        return isValid
    }
    
    // MARK: - Batch Detection
    
    /// Detect file types for multiple files
    /// - Parameter urls: File URLs
    /// - Returns: Dictionary mapping URLs to detected types
    func detectFileTypes(urls: [URL]) async -> [URL: GPGFileType] {
        var results: [URL: GPGFileType] = [:]
        
        await withTaskGroup(of: (URL, GPGFileType).self) { group in
            for url in urls {
                group.addTask {
                    let type = await self.detectFileType(at: url)
                    return (url, type)
                }
            }
            
            for await (url, type) in group {
                results[url] = type
            }
        }
        
        return results
    }
}

// MARK: - Convenience Extensions

extension GPGFileType {
    /// Whether this file type requires a key for processing
    var requiresKey: Bool {
        switch self {
        case .encrypted, .publicKey, .privateKey, .signature:
            return true
        case .notGPG, .unknown:
            return false
        }
    }
    
    /// User-friendly description
    var localizedDescription: String {
        switch self {
        case .encrypted:
            return String(localized: "gpg_file_type_encrypted")
        case .publicKey:
            return String(localized: "gpg_file_type_public_key")
        case .privateKey:
            return String(localized: "gpg_file_type_private_key")
        case .signature:
            return String(localized: "gpg_file_type_signature")
        case .notGPG:
            return String(localized: "gpg_file_type_not_gpg")
        case .unknown:
            return String(localized: "gpg_file_type_unknown")
        }
    }
}
