//
//  StreamingCryptoPipelineTests.swift
//  MoaiyTests
//
//  Unit tests for the streaming crypto pipeline and throttled progress reporting.
//

import Foundation
import Testing
@testable import Moaiy

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var fractions: [Double] = []
    private var callCount: Int = 0

    func record(_ fraction: Double) {
        lock.lock()
        defer { lock.unlock() }
        fractions.append(fraction)
        callCount += 1
    }

    var recordedFractions: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return fractions
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return callCount
    }
}

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

    @Test("StreamingProgressReporter debounces and limits reporting frequency")
    func streamingProgressReporter_throttlesReports() async {
        let recorder = ProgressRecorder()
        let reporter = StreamingProgressReporter(intervalSeconds: 0.2) { progress in
            recorder.record(progress.fractionCompleted)
        }

        // Fast successive reports
        await reporter.report(bytesProcessed: 100, totalBytes: 1000)
        await reporter.report(bytesProcessed: 200, totalBytes: 1000)
        await reporter.report(bytesProcessed: 300, totalBytes: 1000)

        // Force report completion
        await reporter.report(bytesProcessed: 1000, totalBytes: 1000, force: true)

        let fractions = recorder.recordedFractions
        #expect(!fractions.isEmpty)
        #expect(fractions.last == 1.0)
    }

    @Test("StreamingCryptoPipeline executes end-to-end data pass-through using cat mock with backpressure")
    func streamingCryptoPipeline_executesEndToEndPassThrough() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input.txt")
        let outputFile = tempDir.appendingPathComponent("output.txt")

        // Create a 2MB payload to verify multiple chunks and streaming backpressure
        let chunkPattern = Data(repeating: 0x41, count: 64 * 1024) // 64KB
        var testData = Data()
        for _ in 0..<32 {
            testData.append(chunkPattern)
        }
        try testData.write(to: inputFile)

        let catURL = URL(fileURLWithPath: "/bin/cat")
        guard fileManager.isExecutableFile(atPath: catURL.path) else {
            return
        }

        let recorder = ProgressRecorder()
        let resultURL = try await pipeline.executeStreamingFileOperation(
            executableURL: catURL,
            arguments: [],
            environment: [:],
            gpgHome: nil,
            sourceURL: inputFile,
            destinationURL: outputFile,
            isDecryption: true,
            passphrase: nil
        ) { progress in
            recorder.record(progress.fractionCompleted)
        }

        #expect(resultURL.path == outputFile.path)
        #expect(fileManager.fileExists(atPath: outputFile.path))

        let readBackData = try Data(contentsOf: outputFile)
        #expect(readBackData.count == testData.count)
        #expect(readBackData == testData)
        #expect(recorder.count > 0)

        // Verify output file permission is 0600 when isDecryption: true
        if let attributes = try? fileManager.attributesOfItem(atPath: outputFile.path),
           let posixPermissions = attributes[.posixPermissions] as? NSNumber {
            #expect(posixPermissions.intValue == 0o600)
        }
    }

    @Test("StreamingCryptoPipeline handles child process early exit with error")
    func streamingCryptoPipeline_handlesEarlyExitWithError() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-err-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input.txt")
        let outputFile = tempDir.appendingPathComponent("output.txt")
        try Data("Short sample".utf8).write(to: inputFile)

        // Using false (which immediately exits with code 1)
        let falseURL = URL(fileURLWithPath: "/usr/bin/false")
        guard fileManager.isExecutableFile(atPath: falseURL.path) else {
            return
        }

        var threwExpectedError = false
        do {
            _ = try await pipeline.executeStreamingFileOperation(
                executableURL: falseURL,
                arguments: [],
                environment: [:],
                gpgHome: nil,
                sourceURL: inputFile,
                destinationURL: outputFile
            )
        } catch {
            threwExpectedError = true
        }

        #expect(threwExpectedError)
        #expect(!fileManager.fileExists(atPath: outputFile.path))
    }

    @Test("StreamingCryptoPipeline respects Task cancellation")
    func streamingCryptoPipeline_respectsTaskCancellation() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-cancel-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input.txt")
        let outputFile = tempDir.appendingPathComponent("output.txt")

        // Create 1MB dummy data
        try Data(repeating: 0x42, count: 1024 * 1024).write(to: inputFile)

        let catURL = URL(fileURLWithPath: "/bin/cat")
        guard fileManager.isExecutableFile(atPath: catURL.path) else {
            return
        }

        let task = Task {
            try await pipeline.executeStreamingFileOperation(
                executableURL: catURL,
                arguments: [],
                environment: [:],
                gpgHome: nil,
                sourceURL: inputFile,
                destinationURL: outputFile
            )
        }

        // Immediately cancel
        task.cancel()

        var caughtCancellation = false
        do {
            _ = try await task.value
        } catch is CancellationError {
            caughtCancellation = true
        } catch GPGError.operationCancelled {
            caughtCancellation = true
        } catch {
            caughtCancellation = true
        }

        #expect(caughtCancellation)
    }
}
