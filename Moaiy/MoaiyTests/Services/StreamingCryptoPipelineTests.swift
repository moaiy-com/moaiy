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

    func append(_ fraction: Double) {
        lock.lock()
        defer { lock.unlock() }
        fractions.append(fraction)
    }

    var recordedFractions: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return fractions
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
            recorder.append(progress.fractionCompleted)
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

    @Test("StreamingCryptoPipeline executes end-to-end data pass-through using cat mock")
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

        // Create a 512KB payload to verify multiple chunks
        var testData = Data()
        for i in 0..<1024 {
            testData.append(Data("Payload block \(i)\n".utf8))
        }
        try testData.write(to: inputFile)

        let catURL = URL(fileURLWithPath: "/bin/cat")
        guard fileManager.isExecutableFile(atPath: catURL.path) else {
            return
        }

        var progressCalls = 0
        let resultURL = try await pipeline.executeStreamingFileOperation(
            executableURL: catURL,
            arguments: [],
            environment: [:],
            gpgHome: nil,
            sourceURL: inputFile,
            destinationURL: outputFile,
            isDecryption: false,
            passphrase: nil
        ) { _ in
            progressCalls += 1
        }

        #expect(resultURL.path == outputFile.path)
        #expect(fileManager.fileExists(atPath: outputFile.path))

        let readBackData = try Data(contentsOf: outputFile)
        #expect(readBackData == testData)
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
}
