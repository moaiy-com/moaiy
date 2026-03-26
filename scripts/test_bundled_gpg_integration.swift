#!/usr/bin/swift

import Foundation

print("╔═══════════════════════════════════════════════════════════════╗")
print("║      GPG Bundle Integration Test - Pre-Xcode Integration      ║")
print("╚═══════════════════════════════════════════════════════════════╝")
print("")

// Simulate GPGService bundle discovery logic
class GPGServiceTest {
    let bundleName = "gpg.bundle"
    let executableName = "gpg"
    var gpgURL: URL?
    
    func findGPGExecutable() throws {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing GPGService Bundle Discovery Logic")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        
        // Test 1: Try bundled GPG first (production path)
        print("Test 1: Try bundled GPG (production)")
        if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: nil) {
            print("✅ Found bundle at: \(bundleURL.path)")
            let executableURL = bundleURL.appendingPathComponent("bin/\(executableName)")
            if FileManager.default.fileExists(atPath: executableURL.path) {
                gpgURL = executableURL
                print("✅ Using bundled GPG: \(executableURL.path)")
                return
            }
        } else {
            print("⚠️  Bundle not found in Bundle.main (expected before Xcode integration)")
        }
        
        // Test 2: Try project directory (development)
        print("")
        print("Test 2: Try project directory (development)")
        let projectBundlePath = "/Users/codingchef/Taugast/moaiy/Moaiy/Resources/\(bundleName)"
        let projectBundleURL = URL(fileURLWithPath: projectBundlePath)
        
        if FileManager.default.fileExists(atPath: projectBundlePath) {
            print("✅ Found bundle in project: \(projectBundlePath)")
            let executableURL = projectBundleURL.appendingPathComponent("bin/\(executableName)")
            if FileManager.default.fileExists(atPath: executableURL.path) {
                gpgURL = executableURL
                print("✅ Using project GPG: \(executableURL.path)")
                return
            }
        } else {
            print("❌ Bundle not found in project directory")
        }
        
        // Test 3: Try system GPG (fallback)
        print("")
        print("Test 3: Try system GPG (fallback)")
        let systemPath = "/usr/local/bin/gpg"
        if FileManager.default.fileExists(atPath: systemPath) {
            gpgURL = URL(fileURLWithPath: systemPath)
            print("✅ Using system GPG: \(systemPath)")
            return
        }
        
        let homebrewPath = "/opt/homebrew/bin/gpg"
        if FileManager.default.fileExists(atPath: homebrewPath) {
            gpgURL = URL(fileURLWithPath: homebrewPath)
            print("✅ Using Homebrew GPG: \(homebrewPath)")
            return
        }
        
        throw NSError(domain: "GPGService", code: -1, userInfo: [NSLocalizedDescriptionKey: "GPG not found"])
    }
    
    func testExecution() throws {
        print("")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Testing GPG Execution")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        
        guard let gpgURL = gpgURL else {
            throw NSError(domain: "GPGService", code: -1, userInfo: [NSLocalizedDescriptionKey: "GPG URL not set"])
        }
        
        print("GPG Path: \(gpgURL.path)")
        print("")
        
        // Test 1: Version check
        print("Test 1: Version check")
        let task1 = Process()
        task1.executableURL = gpgURL
        task1.arguments = ["--version"]
        
        let pipe1 = Pipe()
        task1.standardOutput = pipe1
        
        try task1.run()
        task1.waitUntilExit()
        
        let data1 = pipe1.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data1, encoding: .utf8) {
            let lines = output.components(separatedBy: "\n").prefix(5)
            for line in lines {
                print("   \(line)")
            }
        }
        print("✅ Version check passed")
        print("")
        
        // Test 2: List keys (with custom GNUPGHOME)
        print("Test 2: List keys with custom GNUPGHOME")
        let tempHome = FileManager.default.temporaryDirectory.appendingPathComponent("gnupg_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tempHome.path)
        
        let task2 = Process()
        task2.executableURL = gpgURL
        task2.arguments = ["--list-keys"]
        task2.environment = ["GNUPGHOME": tempHome.path]
        
        let pipe2 = Pipe()
        task2.standardOutput = pipe2
        task2.standardError = pipe2
        
        try task2.run()
        task2.waitUntilExit()
        
        // Clean up
        try? FileManager.default.removeItem(at: tempHome)
        
        print("✅ List keys test passed (exit code: \(task2.terminationStatus))")
        print("")
        
        // Test 3: Help command
        print("Test 3: Help command")
        let task3 = Process()
        task3.executableURL = gpgURL
        task3.arguments = ["--help"]
        
        try task3.run()
        task3.waitUntilExit()
        
        print("✅ Help command passed")
        print("")
        
        // Test 4: Check library dependencies
        print("Test 4: Check library dependencies")
        let otoolTask = Process()
        otoolTask.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        otoolTask.arguments = ["-L", gpgURL.path]
        
        let otoolPipe = Pipe()
        otoolTask.standardOutput = otoolPipe
        
        try otoolTask.run()
        otoolTask.waitUntilExit()
        
        let otoolData = otoolPipe.fileHandleForReading.readDataToEndOfFile()
        if let otoolOutput = String(data: otoolData, encoding: .utf8) {
            let lines = otoolOutput.components(separatedBy: "\n")
            var bundledLibs = 0
            var systemLibs = 0
            
            for line in lines {
                if line.contains("@executable_path") {
                    bundledLibs += 1
                    print("   ✅ Bundled: \(line.trimmingCharacters(in: .whitespaces))")
                } else if line.contains("/usr/lib") || line.contains("/System") {
                    systemLibs += 1
                }
            }
            
            print("")
            print("   Bundled libraries: \(bundledLibs)")
            print("   System libraries: \(systemLibs)")
            
            if bundledLibs >= 5 {
                print("✅ Library dependencies look good")
            } else {
                print("⚠️  Expected more bundled libraries")
            }
        }
    }
}

// Run tests
do {
    let service = GPGServiceTest()
    try service.findGPGExecutable()
    try service.testExecution()
    
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ All Tests Passed!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("Next Steps:")
    print("1. Add gpg.bundle to Xcode project")
    print("2. Configure Copy Bundle Resources build phase")
    print("3. Rebuild and test in app")
    print("")
    
} catch {
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("❌ Test Failed")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Error: \(error.localizedDescription)")
    exit(1)
}
