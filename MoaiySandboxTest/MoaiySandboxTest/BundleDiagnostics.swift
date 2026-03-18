import Foundation

struct BundleDiagnostics {
    static func printBundleInfo() {
        print("=== Bundle Diagnostics ===")
        print("Bundle path: \(Bundle.main.bundlePath)")
        print("Bundle resource path: \(Bundle.main.resourcePath ?? "nil")")
        print("Bundle executable path: \(Bundle.main.executablePath ?? "nil")")
        print("")
        
        // List all files in Resources directory
        if let resourcePath = Bundle.main.resourcePath {
            print("Files in Resources:")
            if let files = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                for file in files {
                    print("  - \(file)")
                }
            } else {
                print("  Error reading Resources directory")
            }
        }
        
        // Try to find gpg
        let possibleNames = ["gpg", "gpg2", "gpg2.2"]
        for name in possibleNames {
            if let url = Bundle.main.url(forResource: name, withExtension: nil) {
                print("Found \(name) at: \(url.path)")
            }
        }
    }
}
