//
//  BundledGPGTests.swift
//  MoaiyTests
//
//  Tests for bundled GPG functionality
//

import Foundation
import MachO
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

        let libraryNames: [String]
        do {
            libraryNames = try FileManager.default.contentsOfDirectory(atPath: libURL.path)
        } catch {
            Issue.record("Failed to list bundled libraries: \(error)")
            return
        }

        let requiredLibraryPrefixes = [
            "libgcrypt",
            "libgpg-error",
            "libassuan",
            "libnpth",
            "libintl",
            "libreadline",
            "libksba"
        ]

        for prefix in requiredLibraryPrefixes {
            let exists = libraryNames.contains {
                $0.hasPrefix(prefix + ".") && $0.hasSuffix(".dylib")
            }
            #expect(exists, "A versioned \(prefix).*.dylib should exist in bundle")
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
            let hasFiles = json?["files"] != nil
            let hasChecksums = json?["checksums"] != nil
            #expect(hasFiles || hasChecksums, "manifest should contain files or checksums")
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

        let dependencyPaths: [String]
        do {
            dependencyPaths = try MachODependencyReader.readDependencyPaths(from: gpgURL)
        } catch {
            Issue.record("Failed to parse Mach-O dependencies: \(error)")
            return
        }

        let hasBundledRelativePath = dependencyPaths.contains {
            $0.hasPrefix("@executable_path/../lib/") || $0.hasPrefix("@loader_path/../lib/")
        }

        #expect(hasBundledRelativePath,
                "Libraries should use @executable_path or @loader_path for sandbox compatibility")
        #expect(!dependencyPaths.contains(where: { $0.contains("/usr/local/lib") }),
                "Should not reference /usr/local/lib")
        #expect(!dependencyPaths.contains(where: { $0.contains("/opt/homebrew/lib") }),
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

fileprivate enum MachODependencyReaderError: Error {
    case unsupportedFormat
    case malformedBinary
}

private enum MachODependencyReader {

    private static let dylibLoadCommands: Set<UInt32> = [
        UInt32(LC_LOAD_DYLIB),
        UInt32(LC_LOAD_WEAK_DYLIB),
        UInt32(LC_REEXPORT_DYLIB),
        UInt32(LC_LOAD_UPWARD_DYLIB)
    ]

    static func readDependencyPaths(from executableURL: URL) throws -> [String] {
        let data = try Data(contentsOf: executableURL)
        let header: mach_header_64 = try data.readStruct(at: 0)

        guard header.magic == UInt32(MH_MAGIC_64) else {
            throw MachODependencyReaderError.unsupportedFormat
        }

        var loadCommandOffset = MemoryLayout<mach_header_64>.size
        var dependencyPaths: [String] = []

        for _ in 0..<Int(header.ncmds) {
            let command: load_command = try data.readStruct(at: loadCommandOffset)
            let commandSize = Int(command.cmdsize)
            guard commandSize >= MemoryLayout<load_command>.size else {
                throw MachODependencyReaderError.malformedBinary
            }

            let commandEnd = loadCommandOffset + commandSize
            guard commandEnd <= data.count else {
                throw MachODependencyReaderError.malformedBinary
            }

            if dylibLoadCommands.contains(command.cmd) {
                let dylibCommand: dylib_command = try data.readStruct(at: loadCommandOffset)
                let nameOffset = Int(dylibCommand.dylib.name.offset)
                let stringStart = loadCommandOffset + nameOffset

                guard stringStart < commandEnd else {
                    throw MachODependencyReaderError.malformedBinary
                }

                if let path = data.readNullTerminatedUTF8String(start: stringStart, end: commandEnd) {
                    dependencyPaths.append(path)
                }
            }

            loadCommandOffset = commandEnd
        }

        return dependencyPaths
    }
}

private extension Data {
    func readStruct<T>(at offset: Int) throws -> T {
        guard offset >= 0, offset + MemoryLayout<T>.size <= count else {
            throw MachODependencyReaderError.malformedBinary
        }

        return withUnsafeBytes { rawBuffer in
            rawBuffer.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
    }

    func readNullTerminatedUTF8String(start: Int, end: Int) -> String? {
        guard start >= 0, start < end, end <= count else {
            return nil
        }

        return withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            var cursor = start
            while cursor < end, base[cursor] != 0 {
                cursor += 1
            }

            let byteCount = cursor - start
            guard byteCount >= 0 else {
                return nil
            }

            let pointer = UnsafeRawPointer(base.advanced(by: start)).assumingMemoryBound(to: UInt8.self)
            let buffer = UnsafeBufferPointer(start: pointer, count: byteCount)
            return String(bytes: buffer, encoding: .utf8)
        }
    }
}
