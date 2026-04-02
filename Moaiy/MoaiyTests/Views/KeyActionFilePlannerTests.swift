//
//  KeyActionFilePlannerTests.swift
//  MoaiyTests
//
//  Unit tests for key action file planning logic.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Action File Planner Tests")
struct KeyActionFilePlannerTests {

    @Test("Encrypt output appends .moy extension")
    func encryptedOutputURL_appendsMOYExtension() {
        let sourceURL = URL(fileURLWithPath: "/tmp/document.txt")

        let outputURL = KeyActionFilePlanner.encryptedOutputURL(for: sourceURL)

        #expect(outputURL.lastPathComponent == "document.txt.moy")
    }

    @Test("Decrypt output removes extension when present")
    func decryptedOutputURL_removesLastExtensionWhenPresent() {
        let sourceURL = URL(fileURLWithPath: "/tmp/archive.tar.moy")

        let outputURL = KeyActionFilePlanner.decryptedOutputURL(for: sourceURL)

        #expect(outputURL.lastPathComponent == "archive.tar")
    }

    @Test("Decrypt output appends .decrypted when no extension")
    func decryptedOutputURL_appendsDecryptedWhenNoExtension() {
        let sourceURL = URL(fileURLWithPath: "/tmp/ciphertext")

        let outputURL = KeyActionFilePlanner.decryptedOutputURL(for: sourceURL)

        #expect(outputURL.lastPathComponent == "ciphertext.decrypted")
    }

    @Test("Public export filename sanitizes spaces")
    func defaultPublicFileName_sanitizesSpaces() {
        let fileName = KeyActionFilePlanner.defaultPublicFileName(for: "Alice Bob")

        #expect(fileName == "Alice_Bob_public.asc")
    }

    @Test("Private export filename sanitizes spaces")
    func defaultPrivateFileName_sanitizesSpaces() {
        let fileName = KeyActionFilePlanner.defaultPrivateFileName(for: "Alice Bob")

        #expect(fileName == "Alice_Bob_private.asc")
    }

    @Test("Conflict planner appends numeric suffix")
    func nonConflictingURL_appendsNumericSuffix() throws {
        let fileManager = FileManager.default
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("moaiy-planner-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let existingURL = tempDirectory.appendingPathComponent("output.moy")
        try Data().write(to: existingURL)

        let candidate = KeyActionFilePlanner.nonConflictingURL(for: existingURL)

        #expect(candidate.lastPathComponent == "output (1).moy")
    }
}
