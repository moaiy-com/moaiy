import Foundation
import AppKit

/// Sandbox compatibility test runner for Moaiy
/// Tests GPG functionality in macOS App Sandbox environment
@MainActor
class SandboxTestRunner: ObservableObject {
    
    // MARK: - Published Properties
    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    @Published var currentTest = ""
    
    // MARK: - Test Result Model
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let expected: Bool
        let actual: Bool
        let passed: Bool
        let message: String
        let timestamp = Date()
        
        var status: String {
            passed ? "✅ PASS" : "❌ FAIL"
        }
    }
    
    // MARK: - Test Runner
    
    /// Run all sandbox compatibility tests
    func runAllTests() async {
        guard !isRunning else { return }
        
        isRunning = true
        testResults.removeAll()
        
        print("=" * 60)
        print("🧪 Moaiy Sandbox Compatibility Tests")
        print("=" * 60)
        print("")
        
        // Test 1: System GPG (Expected to fail)
        await runTest(
            name: "System GPG Call",
            expected: false,
            test: testSystemGPG
        )
        
        // Test 2: Bundled GPG (Expected to pass)
        await runTest(
            name: "Bundled GPG Call",
            expected: true,
            test: testBundledGPG
        )
        
        // Test 3: File Access Without Auth (Expected to fail)
        await runTest(
            name: "File Access (No Auth)",
            expected: false,
            test: testFileAccessWithoutAuth
        )
        
        // Test 4: Container Directory (Expected to pass)
        await runTest(
            name: "Container Directory",
            expected: true,
            test: testContainerDirectory
        )
        
        // Test 5: Network Access (Expected to pass)
        await runTest(
            name: "Network Access",
            expected: true,
            test: testNetworkAccess
        )
        
        // Manual tests (require user interaction)
        print("")
        print("⚠️  Manual Tests Required:")
        print("   - Test 4: File Access With Auth (requires NSOpenPanel)")
        print("   - Test 5: Security-Scoped Bookmarks (requires NSOpenPanel)")
        print("   - Test 6: GPG Encryption/Decryption (requires GPG binary)")
        print("")
        
        // Summary
        printSummary()
        
        isRunning = false
    }
    
    // MARK: - Individual Tests
    
    /// Test 1: Try to call system GPG (should fail in sandbox)
    private func testSystemGPG() async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/gpg")
        process.arguments = ["--version"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return true  // Success means sandbox is NOT working (unexpected)
        } catch {
            print("   Expected failure: \(error.localizedDescription)")
            return false  // Failure means sandbox is working correctly
        }
    }
    
    /// Test 2: Try to call bundled GPG (should succeed)
    private func testBundledGPG() async throws -> Bool {
        // Check if bundled GPG exists
        guard let bundledGPG = Bundle.main.url(forResource: "gpg", withExtension: nil, subdirectory: "Resources/bin") else {
            print("   ⚠️  Bundled GPG not found - skipping test")
            print("   To test this, add GPG binary to Resources/bin/gpg")
            return false
        }
        
        let process = Process()
        process.executableURL = bundledGPG
        process.arguments = ["--version"]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("   ✅ Bundled GPG executed successfully")
                return true
            } else {
                print("   ❌ Bundled GPG exited with status: \(process.terminationStatus)")
                return false
            }
        } catch {
            print("   ❌ Failed to execute bundled GPG: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Test 3: Try to access file without authorization (should fail)
    private func testFileAccessWithoutAuth() async throws -> Bool {
        // Try to access a file that user hasn't authorized
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let testFile = homeURL.deletingLastPathComponent()
            .appendingPathComponent("Shared")
            .appendingPathComponent("test_sandbox_\(UUID().uuidString).txt")
        
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            
            // If we got here, sandbox is NOT working
            print("   ⚠️  Unexpected: File write succeeded (sandbox may be disabled)")
            
            // Cleanup
            try? FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            print("   Expected failure: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Test 4: Access app container directory (should succeed)
    private func testContainerDirectory() async throws -> Bool {
        let containerURL = FileManager.default.homeDirectoryForCurrentUser
        
        do {
            // Try to create a file in container
            let testFile = containerURL.appendingPathComponent("sandbox_test.txt")
            try "test content".write(to: testFile, atomically: true, encoding: .utf8)
            
            // Try to read it back
            let content = try String(contentsOf: testFile)
            
            // Cleanup
            try FileManager.default.removeItem(at: testFile)
            
            if content == "test content" {
                print("   ✅ Container directory access works")
                return true
            } else {
                return false
            }
        } catch {
            print("   ❌ Container access failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Test 5: Network access (for key servers)
    private func testNetworkAccess() async throws -> Bool {
        // Simple network test - try to connect to a key server
        let url = URL(string: "https://keys.openpgp.org")!
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200..<300).contains(httpResponse.statusCode)
                if success {
                    print("   ✅ Network access works")
                } else {
                    print("   ⚠️  Network request returned: \(httpResponse.statusCode)")
                }
                return success
            }
            return false
        } catch {
            print("   ❌ Network access failed: \(error.localizedDescription)")
            print("   Note: This may fail if com.apple.security.network.client entitlement is missing")
            return false
        }
    }
    
    // MARK: - Manual Tests (Require User Interaction)
    
    /// Test: File access with NSOpenPanel authorization
    /// Call this manually from UI
    func testFileAccessWithAuth(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Moaiy Sandbox Test: Please select any file to test authorized access"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                print("   ❌ User cancelled")
                completion(false)
                return
            }
            
            // Access with security scope
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let data = try Data(contentsOf: url)
                print("   ✅ Authorized file access works (read \(data.count) bytes)")
                completion(true)
            } catch {
                print("   ❌ Failed to read authorized file: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    /// Test: Security-scoped bookmark
    /// Call this manually from UI
    func testSecurityScopedBookmark(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Moaiy Sandbox Test: Please select a file to test bookmark persistence"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                print("   ❌ User cancelled")
                completion(false)
                return
            }
            
            // Create bookmark
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                // Try to resolve bookmark
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    print("   ⚠️  Bookmark is stale")
                }
                
                // Try to access resolved URL
                let resolvedAccessing = resolvedURL.startAccessingSecurityScopedResource()
                defer {
                    if resolvedAccessing {
                        resolvedURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                let data = try Data(contentsOf: resolvedURL)
                print("   ✅ Security-scoped bookmark works (read \(data.count) bytes)")
                completion(true)
                
            } catch {
                print("   ❌ Bookmark test failed: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func runTest(name: String, expected: Bool, test: () async throws -> Bool) async {
        currentTest = name
        print("\n📋 Test: \(name)")
        print("   Expected: \(expected ? "PASS" : "FAIL")")
        
        do {
            let actual = try await test()
            let passed = (actual == expected)
            
            let result = TestResult(
                name: name,
                expected: expected,
                actual: actual,
                passed: passed,
                message: passed ? "Test passed" : "Test failed"
            )
            
            testResults.append(result)
            print("   Result: \(result.status)")
            
        } catch {
            let result = TestResult(
                name: name,
                expected: expected,
                actual: false,
                passed: !expected,  // If we expected failure, error is success
                message: "Error: \(error.localizedDescription)"
            )
            
            testResults.append(result)
            print("   Result: \(result.status) (error)")
        }
    }
    
    private func printSummary() {
        print("\n" + "=" * 60)
        print("📊 Test Summary")
        print("=" * 60)
        
        let passed = testResults.filter { $0.passed }.count
        let total = testResults.count
        
        for result in testResults {
            print("\(result.status) - \(result.name)")
        }
        
        print("")
        print("Passed: \(passed)/\(total)")
        
        if passed == total {
            print("\n🎉 All automated tests passed!")
        } else {
            print("\n⚠️  Some tests failed - review results above")
        }
        
        print("\n" + "=" * 60)
    }
}

// MARK: - String Extension

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - Usage Example

/*
 // In your SwiftUI view:
 
 struct ContentView: View {
     @StateObject private var testRunner = SandboxTestRunner()
     
     var body: some View {
         VStack(spacing: 20) {
             Text("Moaiy Sandbox Tests")
                 .font(.title)
             
             if testRunner.isRunning {
                 ProgressView("Running: \(testRunner.currentTest)")
             } else {
                 Button("Run Automated Tests") {
                     Task {
                         await testRunner.runAllTests()
                     }
                 }
             }
             
             List(testRunner.testResults) { result in
                 HStack {
                     Text(result.status)
                     Text(result.name)
                     Spacer()
                     Text(result.passed ? "✅" : "❌")
                 }
             }
             
             HStack {
                 Button("Test File Auth") {
                     testRunner.testFileAccessWithAuth { success in
                         print("File auth test: \(success ? "PASS" : "FAIL")")
                     }
                 }
                 
                 Button("Test Bookmarks") {
                     testRunner.testSecurityScopedBookmark { success in
                         print("Bookmark test: \(success ? "PASS" : "FAIL")")
                     }
                 }
             }
         }
         .padding()
         .frame(width: 600, height: 500)
     }
 }
 */
