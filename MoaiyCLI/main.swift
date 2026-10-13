//
//  main.swift
//  MoaiyCLI
//
//  Command-line companion tool for Moaiy file encryption client.
//

import Foundation

let versionString = "1.0.0-beta"

struct CLIStatus: Codable {
    let version: String
    let gpgAvailable: Bool
    let gpgPath: String?
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

    EXAMPLES:
        moaiy-cli status --json
        moaiy-cli list-keys
        moaiy-cli encrypt document.pdf -r 4D8B93C4 -o document.pdf.moy
        moaiy-cli decrypt document.pdf.moy -o document.pdf
    """)
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

func checkStatus(jsonOutput: Bool) {
    let gpgPath = findGPGExecutable()
    let isAvailable = gpgPath != nil

    var supportsKyber = false
    if let gpg = gpgPath {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gpg)
        process.arguments = ["--with-colons", "--list-config"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            supportsKyber = output.lowercased().contains("kyber")
        }
    }

    let status = CLIStatus(
        version: versionString,
        gpgAvailable: isAvailable,
        gpgPath: gpgPath,
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
        print("PQC Kyber Support: \(status.supportsKyber ? "Available" : "Standard")")
    }
}

func listKeys(secretOnly: Bool, jsonOutput: Bool) {
    guard let gpgPath = findGPGExecutable() else {
        fputs("Error: GPG executable not found in system paths.\n", stderr)
        exit(1)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: gpgPath)
    process.arguments = secretOnly
        ? ["--list-secret-keys", "--with-colons", "--fixed-list-mode"]
        : ["--list-keys", "--with-colons", "--fixed-list-mode"]

    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        exit(0)
    }

    var keys: [CLIKeyInfo] = []
    var currentID = ""
    var currentFpr = ""
    var currentUserIDs: [String] = []

    for line in output.components(separatedBy: "\n") {
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
        print("Available Keys (\(keys.count)):")
        for key in keys {
            let uids = key.userIDs.joined(separator: ", ")
            print("  - [\(key.id)] \(key.fingerprint) (\(uids))")
        }
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

switch command {
case "status":
    checkStatus(jsonOutput: isJSON)
case "list-keys":
    let isSecret = arguments.contains("--secret")
    listKeys(secretOnly: isSecret, jsonOutput: isJSON)
case "version", "-v", "--version":
    print("moaiy-cli version \(versionString)")
case "help", "-h", "--help":
    printUsage()
default:
    fputs("Unknown command: \(command). Use 'moaiy-cli --help' for usage.\n", stderr)
    exit(1)
}
