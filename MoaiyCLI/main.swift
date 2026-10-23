//
//  main.swift
//  MoaiyCLI
//
//  Command-line companion tool for Moaiy file encryption client.
//

import Foundation
import Darwin

signal(SIGPIPE, SIG_IGN)

let versionString = "1.0.1"

struct CLIStatus: Codable {
    let version: String
    let gpgAvailable: Bool
    let gpgPath: String?
    let gpgHome: String?
    let supportsKyber: Bool
}

struct CLIKeyInfo: Codable {
    let id: String
    let fingerprint: String
    let userIDs: [String]
}

func printUsage() {
    print("""
    Moaiy CLI - Native File Encryption Companion (v\(versionString))

    USAGE:
        moaiy-cli <subcommand> [options]

    SUBCOMMANDS:
        status       Check cryptographic backend status and PQC/Kyber capability
        list-keys    List available keys in the keyring
        encrypt      Encrypt a file for designated recipient(s)
        decrypt      Decrypt a ciphertext file
        help         Show this help message
        version      Print Moaiy CLI version

    OPTIONS:
        -h, --help       Show help information
        -v, --version    Show version
        --json           Output results in JSON format
        -r, --recipient  Recipient key ID / fingerprint (for encryption)
        -o, --output     Custom output destination path
        --armor          Output ASCII armored ciphertext
        --secret         Only list secret/private keys (for list-keys)
        --gpg-home       Override GPG home directory path

    NOTES & LIMITATIONS:
        - Non-interactive execution: Commands run in --batch mode. Existing output files
          at the destination will be overwritten (--yes).
        - Passphrase caching: Decrypting passphrase-protected keys in batch mode requires
          the passphrase to be active in the gpg-agent daemon cache.
        - Standalone tool: moaiy-cli is designed for scripting and automation. For hardware
          Touch ID prompts and interactive key management, use the Moaiy desktop app.

    EXAMPLES:
        moaiy-cli status --json
        moaiy-cli list-keys --secret
        moaiy-cli encrypt document.pdf -r 4D8B93C4 -o document.pdf.moy
        moaiy-cli decrypt document.pdf.moy -o document.pdf
    """)
}

func resolveGPGHome(customPath: String?) -> URL {
    if let customPath = customPath {
        return URL(fileURLWithPath: customPath)
    }
    let fileManager = FileManager.default

    // 1. Check Moaiy App Sandbox Container path first
    let containerHome = fileManager.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/com.moaiy.app/Data/Library/gnupg", isDirectory: true)
    if fileManager.fileExists(atPath: containerHome.path) {
        return containerHome
    }

    // 2. Check Moaiy App direct Library path (~/Library/gnupg)
    if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
        let appHome = libraryURL.appendingPathComponent("gnupg", isDirectory: true)
        if fileManager.fileExists(atPath: appHome.path) {
            return appHome
        }
    }

    // 3. Fallback to standard ~/.gnupg
    return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".gnupg", isDirectory: true)
}

func findGPGExecutable() -> String? {
    let searchPaths = [
        "/opt/homebrew/bin/gpg",
        "/usr/local/bin/gpg",
        "/usr/bin/gpg"
    ]
    for path in searchPaths {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }
    return nil
}

/// Robust pipe execution that avoids deadlocks by reading stdout/stderr asynchronously
func runProcessSafe(executable: String, arguments: [String], environment: [String: String]) -> (exitCode: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    var env = ProcessInfo.processInfo.environment
    for (k, v) in environment {
        env[k] = v
    }
    process.environment = env

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let queue = DispatchQueue(label: "com.moaiy.cli.pipe", attributes: .concurrent)
    var stdoutData = Data()
    var stderrData = Data()
    let group = DispatchGroup()

    group.enter()
    queue.async {
        stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }

    group.enter()
    queue.async {
        stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        group.leave()
    }

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return (-1, "", error.localizedDescription)
    }

    group.wait()

    let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
    return (process.terminationStatus, stdoutStr, stderrStr)
}

func checkStatus(gpgHomeURL: URL, jsonOutput: Bool) {
    let gpgPath = findGPGExecutable()
    let isAvailable = gpgPath != nil

    var supportsKyber = false
    if let gpg = gpgPath {
        let result = runProcessSafe(
            executable: gpg,
            arguments: ["--with-colons", "--list-config"],
            environment: ["GNUPGHOME": gpgHomeURL.path]
        )
        if result.exitCode == 0 {
            // Precise parser checking algorithm ID 8 or pubkey name containing kyber
            for rawLine in result.stdout.split(whereSeparator: \.isNewline) {
                let fields = rawLine.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                guard fields.count >= 3, fields[0] == "cfg" else { continue }
                let key = fields[1].lowercased()
                let val = fields[2].lowercased()
                if (key == "pubkey" && val.split(separator: ";").contains("8")) ||
                   (key == "pubkeyname" && val.contains("kyber")) {
                    supportsKyber = true
                    break
                }
            }
        }
    }

    let status = CLIStatus(
        version: versionString,
        gpgAvailable: isAvailable,
        gpgPath: gpgPath,
        gpgHome: gpgHomeURL.path,
        supportsKyber: supportsKyber
    )

    if jsonOutput {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(status), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        print("Moaiy CLI Version: \(status.version)")
        print("GPG Engine Ready:  \(status.gpgAvailable ? "YES (\(status.gpgPath ?? ""))" : "NO")")
        print("GPG Home Path:     \(status.gpgHome ?? "none")")
        print("PQC Kyber Support: \(status.supportsKyber ? "Available" : "Standard")")
    }
}

func listKeys(gpgHomeURL: URL, secretOnly: Bool, jsonOutput: Bool) {
    guard let gpgPath = findGPGExecutable() else {
        fputs("Error: GPG executable not found in system paths.\n", stderr)
        exit(1)
    }

    let args = secretOnly
        ? ["--list-secret-keys", "--with-colons", "--fixed-list-mode"]
        : ["--list-keys", "--with-colons", "--fixed-list-mode"]

    let result = runProcessSafe(
        executable: gpgPath,
        arguments: args,
        environment: ["GNUPGHOME": gpgHomeURL.path]
    )

    guard result.exitCode == 0 else {
        fputs("Error listing keys: \(result.stderr)\n", stderr)
        exit(1)
    }

    var keys: [CLIKeyInfo] = []
    var currentID = ""
    var currentFpr = ""
    var currentUserIDs: [String] = []

    for line in result.stdout.components(separatedBy: "\n") {
        let fields = line.components(separatedBy: ":")
        guard !fields.isEmpty else { continue }

        let type = fields[0]
        if type == "pub" || type == "sec" {
            if !currentFpr.isEmpty {
                keys.append(CLIKeyInfo(id: currentID, fingerprint: currentFpr, userIDs: currentUserIDs))
                currentUserIDs.removeAll()
            }
            currentID = fields.count > 4 ? fields[4] : ""
            currentFpr = ""
        } else if type == "fpr" {
            if currentFpr.isEmpty, fields.count > 9 {
                currentFpr = fields[9]
            }
        } else if type == "uid" {
            if fields.count > 9 {
                currentUserIDs.append(fields[9])
            }
        }
    }

    if !currentFpr.isEmpty {
        keys.append(CLIKeyInfo(id: currentID, fingerprint: currentFpr, userIDs: currentUserIDs))
    }

    if jsonOutput {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(keys), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        print("Available Keys (\(keys.count)) [\(gpgHomeURL.path)]:")
        for key in keys {
            let uids = key.userIDs.joined(separator: ", ")
            print("  - [\(key.id)] \(key.fingerprint) (\(uids))")
        }
    }
}

func encryptFile(gpgHomeURL: URL, inputPath: String, recipient: String?, outputPath: String?, armor: Bool) {
    guard let gpgPath = findGPGExecutable() else {
        fputs("Error: GPG executable not found in system paths.\n", stderr)
        exit(1)
    }
    guard let recipient = recipient, !recipient.isEmpty else {
        fputs("Error: --recipient <keyID> is required for encryption.\n", stderr)
        exit(1)
    }
    guard FileManager.default.fileExists(atPath: inputPath) else {
        fputs("Error: Input file does not exist: \(inputPath)\n", stderr)
        exit(1)
    }

    let defaultOutput = armor ? "\(inputPath).asc" : "\(inputPath).moy"
    let finalOutput = outputPath ?? defaultOutput

    var args = [
        "--encrypt",
        "--batch",
        "--yes",
        "--trust-model", "always",
        "--recipient", recipient,
        "--output", finalOutput
    ]
    if armor {
        args.append("--armor")
    }
    args.append(inputPath)

    print("Encrypting \(inputPath) for \(recipient)...")
    let result = runProcessSafe(
        executable: gpgPath,
        arguments: args,
        environment: ["GNUPGHOME": gpgHomeURL.path]
    )

    if result.exitCode == 0 {
        print("Successfully encrypted to: \(finalOutput)")
    } else {
        fputs("Encryption failed: \(result.stderr)\n", stderr)
        exit(1)
    }
}

func decryptFile(gpgHomeURL: URL, inputPath: String, outputPath: String?) {
    guard let gpgPath = findGPGExecutable() else {
        fputs("Error: GPG executable not found in system paths.\n", stderr)
        exit(1)
    }
    guard FileManager.default.fileExists(atPath: inputPath) else {
        fputs("Error: Input file does not exist: \(inputPath)\n", stderr)
        exit(1)
    }

    let defaultOutput: String
    if inputPath.hasSuffix(".moy") {
        defaultOutput = String(inputPath.dropLast(4))
    } else if inputPath.hasSuffix(".asc") || inputPath.hasSuffix(".gpg") {
        defaultOutput = String(inputPath.dropLast(4))
    } else {
        defaultOutput = "\(inputPath).decrypted"
    }
    let finalOutput = outputPath ?? defaultOutput

    let args = [
        "--decrypt",
        "--batch",
        "--yes",
        "--output", finalOutput,
        inputPath
    ]

    print("Decrypting \(inputPath)...")
    let result = runProcessSafe(
        executable: gpgPath,
        arguments: args,
        environment: ["GNUPGHOME": gpgHomeURL.path]
    )

    if result.exitCode == 0 {
        print("Successfully decrypted to: \(finalOutput)")
    } else {
        fputs("Decryption failed: \(result.stderr)\n", stderr)
        exit(1)
    }
}

// Entrypoint dispatch
let arguments = CommandLine.arguments

guard arguments.count > 1 else {
    printUsage()
    exit(0)
}

let command = arguments[1]
let isJSON = arguments.contains("--json")

var customGPGHome: String?
if let idx = arguments.firstIndex(of: "--gpg-home"), idx + 1 < arguments.count {
    customGPGHome = arguments[idx + 1]
}
let gpgHomeURL = resolveGPGHome(customPath: customGPGHome)

switch command {
case "status":
    checkStatus(gpgHomeURL: gpgHomeURL, jsonOutput: isJSON)
case "list-keys":
    let isSecret = arguments.contains("--secret")
    listKeys(gpgHomeURL: gpgHomeURL, secretOnly: isSecret, jsonOutput: isJSON)
case "encrypt":
    var recipient: String?
    if let idx = arguments.firstIndex(of: "-r") ?? arguments.firstIndex(of: "--recipient"), idx + 1 < arguments.count {
        recipient = arguments[idx + 1]
    }
    var output: String?
    if let idx = arguments.firstIndex(of: "-o") ?? arguments.firstIndex(of: "--output"), idx + 1 < arguments.count {
        output = arguments[idx + 1]
    }
    let isArmor = arguments.contains("--armor")
    guard arguments.count >= 3 else {
        fputs("Usage: moaiy-cli encrypt <file> -r <recipient> [-o <output>]\n", stderr)
        exit(1)
    }
    let inputFile = arguments[2]
    encryptFile(gpgHomeURL: gpgHomeURL, inputPath: inputFile, recipient: recipient, outputPath: output, armor: isArmor)
case "decrypt":
    var output: String?
    if let idx = arguments.firstIndex(of: "-o") ?? arguments.firstIndex(of: "--output"), idx + 1 < arguments.count {
        output = arguments[idx + 1]
    }
    guard arguments.count >= 3 else {
        fputs("Usage: moaiy-cli decrypt <file> [-o <output>]\n", stderr)
        exit(1)
    }
    let inputFile = arguments[2]
    decryptFile(gpgHomeURL: gpgHomeURL, inputPath: inputFile, outputPath: output)
case "version", "-v", "--version":
    print("moaiy-cli version \(versionString)")
case "help", "-h", "--help":
    printUsage()
default:
    fputs("Unknown command: \(command). Use 'moaiy-cli --help' for usage.\n", stderr)
    exit(1)
}
