//
//  StreamingCryptoPipelineTests.swift
//  MoaiyTests
//
//  Unit tests for the streaming crypto pipeline, atomic file replacement,
//  and throttled progress reporting.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Streaming Crypto Pipeline Tests")
struct StreamingCryptoPipelineTests {

    @Test("CryptoProgress computes accurate completion fraction and clamps bounds")
    func cryptoProgress_computesFraction_andClampsBounds() {
        let initial = CryptoProgress(bytesProcessed: 0, totalBytes: 1000)
        #expect(initial.fractionCompleted == 0.0)
        #expect(initial.bytesProcessed == 0)
        #expect(initial.totalBytes == 1000)

        let half = CryptoProgress(bytesProcessed: 500, totalBytes: 1000)
        #expect(half.fractionCompleted == 0.5)

        let full = CryptoProgress(bytesProcessed: 1000, totalBytes: 1000)
        #expect(full.fractionCompleted == 1.0)

        let over = CryptoProgress(bytesProcessed: 1500, totalBytes: 1000)
        #expect(over.fractionCompleted == 1.0)

        let zeroTotal = CryptoProgress(bytesProcessed: 50, totalBytes: 0)
        #expect(zeroTotal.fractionCompleted == 1.0)
    }

    @Test("AtomicFileUtility creates isolated temporary file URL on target volume")
    func atomicFileUtility_temporaryURL_namingConventions() {
        let destination = URL(fileURLWithPath: "/tmp/sample_target.moy")
        let tempURL = AtomicFileUtility.temporaryDestinationURL(for: destination)

        #expect(tempURL.deletingLastPathComponent().path == destination.deletingLastPathComponent().path)
        #expect(tempURL.lastPathComponent.hasPrefix(".sample_target.moy.moaiy-tmp-"))
    }

    @Test("AtomicFileUtility commits staged temporary file atomically over existing destination")
    func atomicFileUtility_commitsAtomically() throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("moaiy-atomic-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let destinationURL = tempDir.appendingPathComponent("final_output.txt")
        let initialData = Data("Initial old content".utf8)
        try initialData.write(to: destinationURL)

        let stagedTempURL = AtomicFileUtility.temporaryDestinationURL(for: destinationURL)
        let newContent = Data("New atomic content \(UUID().uuidString)".utf8)
        try newContent.write(to: stagedTempURL)

        #expect(fileManager.fileExists(atPath: stagedTempURL.path))
        #expect(fileManager.fileExists(atPath: destinationURL.path))

        try AtomicFileUtility.commitTemporaryFile(from: stagedTempURL, to: destinationURL)

        // Staged temp file should now be moved/removed
        #expect(!fileManager.fileExists(atPath: stagedTempURL.path))
        #expect(fileManager.fileExists(atPath: destinationURL.path))

        let readData = try Data(contentsOf: destinationURL)
        #expect(readData == newContent)
    }

    @Test("AtomicFileUtility cleans up temporary files quietly")
    func atomicFileUtility_cleanupQuietly() throws {
        let fileManager = FileManager.default
        let tempFile = fileManager.temporaryDirectory.appendingPathComponent("quiet_cleanup_\(UUID().uuidString).tmp")
        try Data("test".utf8).write(to: tempFile)
        #expect(fileManager.fileExists(atPath: tempFile.path))

        AtomicFileUtility.cleanupQuietly(at: tempFile)
        #expect(!fileManager.fileExists(atPath: tempFile.path))

        // Subsequent cleanup on non-existent file should not throw or crash
        AtomicFileUtility.cleanupQuietly(at: tempFile)
    }
}
