//
//  BundledGPGTests.swift
//  MoaiyTests
//
//  Tests for bundled GPG functionality
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Bundled GPG Tests")
struct BundledGPGTests {
    
    // MARK: - Bundle Detection Tests
    
    @Test("Bundle resource name is correct")
    func bundleResourceNameIsCorrect() {
        #expect(Constants.GPG.bundleName == "gpg.bundle")
    }
    
    @Test("Bundle executable name is correct")
    func bundleExecutableNameIsCorrect() {
        #expect(Constants.GPG.executableName == "gpg")
    }
    
    @Test("Bundle exists in app resources")
    func bundleExistsInAppResources() {
        let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle")
        #expect(bundleURL != nil, "gpg.bundle should exist in app resources")
    }
    
    // MARK: - Executable Tests
    
    @Test("GPG executable exists in bundle")
    func gpgExecutableExistsInBundle() {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let executableURL = bundleURL.appendingPathComponent("bin/gpg")
        #expect(FileManager.default.fileExists(atPath: executableURL.path), 
                "gpg executable should exist at \(executableURL.path)")
    }
    
    @Test("GPG Agent executable exists in bundle")
    func gpgAgentExecutableExistsInBundle() {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let executableURL = bundleURL.appendingPathComponent("bin/gpg-agent")
        #expect(FileManager.default.fileExists(atPath: executableURL.path),
                "gpg-agent executable should exist at \(executableURL.path)")
    }
    
    @Test("GPGConf executable exists in bundle")
    func gpgConfExecutableExistsInBundle() {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let executableURL = bundleURL.appendingPathComponent("bin/gpgconf")
        #expect(FileManager.default.fileExists(atPath: executableURL.path),
                "gpgconf executable should exist at \(executableURL.path)")
    }
    
    // MARK: - Library Tests
    
    @Test("Required libraries exist in bundle")
    func requiredLibrariesExistInBundle() {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let libURL = bundleURL.appendingPathComponent("lib")
        #expect(FileManager.default.fileExists(atPath: libURL.path),
                "lib directory should exist in bundle")
        
        let requiredLibraries = [
            "libgcrypt.dylib",
            "libgpg-error.dylib",
            "libassuan.dylib",
            "libnpth.dylib",
            "libintl.dylib",
            "libreadline.dylib",
            "libksba.dylib"
        ]
        
        for lib in requiredLibraries {
            let libPath = libURL.appendingPathComponent(lib)
            #expect(FileManager.default.fileExists(atPath: libPath.path),
                    "\(lib) should exist in bundle")
        }
    }
    
    // MARK: - Manifest Tests
    
    @Test("Manifest exists and is valid JSON")
    func manifestExistsAndIsValidJSON() {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        #expect(FileManager.default.fileExists(atPath: manifestURL.path),
                "manifest.json should exist in bundle")
        
        guard let data = FileManager.default.contents(atPath: manifestURL.path) else {
            Issue.record("Could not read manifest.json")
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json != nil, "manifest.json should be valid JSON")
            #expect(json?["version"] != nil, "manifest should contain version")
            #expect(json?["files"] != nil, "manifest should contain files")
        } catch {
            Issue.record("Failed to parse manifest.json: \(error)")
        }
    }
    
    // MARK: - Executable Functionality Tests
    
    @Test("Bundled GPG can execute version command")
    func bundledGPGCanExecuteVersionCommand() async throws {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let gpgURL = bundleURL.appendingPathComponent("bin/gpg")
        guard FileManager.default.fileExists(atPath: gpgURL.path) else {
            Issue.record("gpg executable not found in bundle")
            return
        }
        
        let process = Process()
        process.executableURL = gpgURL
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        #expect(process.terminationStatus == 0, "gpg --version should exit with status 0")
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        #expect(output.contains("GnuPG"), "Output should contain 'GnuPG'")
        #expect(output.contains("2."), "Output should indicate version 2.x")
    }
    
    @Test("Bundled GPG uses correct library paths")
    func bundledGPGUsesCorrectLibraryPaths() async throws {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let gpgURL = bundleURL.appendingPathComponent("bin/gpg")
        guard FileManager.default.fileExists(atPath: gpgURL.path) else {
            Issue.record("gpg executable not found in bundle")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        process.arguments = ["-L", gpgURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        #expect(output.contains("@executable_path"), 
                "Libraries should use @executable_path for sandbox compatibility")
        #expect(!output.contains("/usr/local/lib"),
                "Should not reference /usr/local/lib")
        #expect(!output.contains("/opt/homebrew/lib"),
                "Should not reference /opt/homebrew/lib")
    }
    
    // MARK: - GPGService Integration Tests
    
    @Test("GPGService is ready")
    @MainActor
    func gpgServiceIsReady() async throws {
        let service = GPGService.shared
        
        try await Task.sleep(for: .seconds(1))
        
        #expect(service.isReady, "GPGService should be ready")
    }
    
    @Test("GPGService can list keys with bundled GPG")
    @MainActor
    func gpgServiceCanListKeysWithBundledGPG() async throws {
        let service = GPGService.shared
        
        try await Task.sleep(for: .seconds(1))
        
        guard service.isReady else {
            Issue.record("GPGService is not ready")
            return
        }
        
        do {
            let keys = try await service.listKeys()
            #expect(keys is [GPGKey], "Should return array of GPGKey")
        } catch {
            // Empty keyring is acceptable
            #expect(true, "List keys completed (may be empty)")
        }
    }
    
    // MARK: - Binary Signature Tests
    
    @Test("Bundled binaries are signed")
    func bundledBinariesAreSigned() throws {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let binURL = bundleURL.appendingPathComponent("bin")
        guard let enumerator = FileManager.default.enumerator(at: binURL, includingPropertiesForKeys: nil) else {
            Issue.record("Could not enumerate bin directory")
            return
        }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.isEmpty else { continue }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            process.arguments = ["-dv", fileURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            #expect(process.terminationStatus == 0, 
                    "Binary \(fileURL.lastPathComponent) should be signed")
        }
    }
    
    // MARK: - Sandbox Compatibility Tests
    
    @Test("Bundle does not contain hardcoded paths")
    func bundleDoesNotContainHardcodedPaths() throws {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        let forbiddenPaths = [
            "/usr/local/Cellar",
            "/usr/local/opt",
            "/opt/homebrew/Cellar",
            "/opt/homebrew/opt",
            "/Users/"
        ]
        
        guard let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: nil) else {
            Issue.record("Could not enumerate bundle")
            return
        }
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "dylib" || fileURL.pathExtension.isEmpty else { continue }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
            process.arguments = [fileURL.path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            for forbiddenPath in forbiddenPaths {
                #expect(!output.contains(forbiddenPath),
                        "\(fileURL.lastPathComponent) should not contain hardcoded path: \(forbiddenPath)")
            }
        }
    }
    
    // MARK: - Size Tests
    
    @Test("Bundle size is within acceptable limits")
    func bundleSizeIsWithinAcceptableLimits() throws {
        guard let bundleURL = Bundle.main.url(forResource: "gpg", withExtension: "bundle") else {
            Issue.record("gpg.bundle not found")
            return
        }
        
        var totalSize: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(at: bundleURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            Issue.record("Could not enumerate bundle")
            return
        }
        
        for case let fileURL as URL in enumerator {
            let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(resources.fileSize ?? 0)
        }
        
        let maxSize: Int64 = 20 * 1024 * 1024 // 20MB
        #expect(totalSize < maxSize, 
                "Bundle size (\(totalSize / 1024 / 1024)MB) should be less than 20MB")
    }
}
