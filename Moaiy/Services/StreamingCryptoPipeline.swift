//
//  StreamingCryptoPipeline.swift
//  Moaiy
//
//  Streaming I/O pipeline for file encryption and decryption.
//  Provides constant-memory chunked streaming, pipe deadlock prevention,
//  atomic file replacement, and throttled progress reporting.
//

import Foundation
import Darwin
import os.log

// MARK: - Progress Information

/// Represents progress state during a streaming cryptographic operation
public struct CryptoProgress: Sendable, Equatable {
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let fractionCompleted: Double

    public init(bytesProcessed: Int64, totalBytes: Int64) {
        self.bytesProcessed = max(0, bytesProcessed)
        self.totalBytes = max(1, totalBytes)
        self.fractionCompleted = min(1.0, max(0.0, Double(self.bytesProcessed) / Double(self.totalBytes)))
    }
}

// MARK: - Throttled Progress Reporter

/// Actor for debouncing and throttling progress callback invocations to protect UI rendering loops
public actor StreamingProgressReporter {
    private var lastReportTime: DispatchTime = .now()
    private let throttleIntervalNanoseconds: UInt64
    private let progressHandler: (@Sendable (CryptoProgress) -> Void)?

    public init(intervalSeconds: Double = 0.1, progressHandler: (@Sendable (CryptoProgress) -> Void)? = nil) {
        self.throttleIntervalNanoseconds = UInt64(intervalSeconds * 1_000_000_000)
        self.progressHandler = progressHandler
    }

    public func report(bytesProcessed: Int64, totalBytes: Int64, force: Bool = false) {
        guard let handler = progressHandler else { return }
        let now = DispatchTime.now()
        let elapsed = now.uptimeNanoseconds - lastReportTime.uptimeNanoseconds

        if force || elapsed >= throttleIntervalNanoseconds || bytesProcessed >= totalBytes {
            lastReportTime = now
            let progress = CryptoProgress(bytesProcessed: bytesProcessed, totalBytes: totalBytes)
            handler(progress)
        }
    }
}

// MARK: - Atomic File Replacement Utility

public enum AtomicFileUtility {
    private static let logger = Logger(subsystem: "com.moaiy.app", category: "AtomicFileUtility")

    /// Prepares an isolated hidden temporary file URL residing on the same volume as the target destination
    public static func temporaryDestinationURL(for destinationURL: URL) -> URL {
        let parentDir = destinationURL.deletingLastPathComponent()
        let nonce = UUID().uuidString.prefix(8)
        let tempFileName = ".\(destinationURL.lastPathComponent).moaiy-tmp-\(nonce)"
        return parentDir.appendingPathComponent(String(tempFileName))
    }

    /// Atomically replaces or creates the destination file with the contents of the staged temporary file
    public static func commitTemporaryFile(from stagedTempURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let destinationPath = destinationURL.path
        let stagedPath = stagedTempURL.path

        guard fileManager.fileExists(atPath: stagedPath) else {
            throw GPGError.executionFailed("Staged temporary file was missing before commit: \(stagedPath)")
        }

        if fileManager.fileExists(atPath: destinationPath) {
            // Use system-level atomic replacement
            do {
                _ = try fileManager.replaceItemAt(
                    destinationURL,
                    withItemAt: stagedTempURL,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
                logger.debug("Successfully performed atomic replaceItemAt: \(destinationPath)")
                return
            } catch {
                logger.warning("replaceItemAt failed (\(error.localizedDescription)), falling back to POSIX rename")
            }

            // Fallback: Remove target and rename atomically
            try? fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: stagedTempURL, to: destinationURL)
        logger.debug("Successfully committed temporary file via moveItem to: \(destinationPath)")
    }

    /// Safely cleans up temporary files without throwing unhandled exceptions
    public static func cleanupQuietly(at url: URL?) {
        guard let url = url else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Streaming Process Pipeline Engine

/// Asynchronous streaming manager for running cryptographic processes with constant memory consumption
public actor StreamingCryptoPipeline {
    private static let logger = Logger(subsystem: "com.moaiy.app", category: "StreamingCryptoPipeline")

    /// Default chunk size: 256KB for adaptive throughput and low memory footprint
    public static let defaultChunkSize = 256 * 1024

    public init() {}

    /// Executes a streaming operation connecting an input file to an external process stdin,
    /// draining stdout into an atomic temporary file, and monitoring stderr asynchronously.
    public func executeStreamingFileOperation(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        gpgHome: URL?,
        sourceURL: URL,
        destinationURL: URL,
        passphrase: String? = nil,
        progressHandler: (@Sendable (CryptoProgress) -> Void)? = nil
    ) async throws -> URL {
        let fileManager = FileManager.default

        // Verify source existence and calculate total input size
        let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let totalFileSize = (sourceAttributes[.size] as? NSNumber)?.int64Value ?? 0

        // Prepare atomic temporary output location on the same volume
        let stagedOutputURL = AtomicFileUtility.temporaryDestinationURL(for: destinationURL)

        // Ensure cleanup of staged file if an error occurs
        var commitSuccessful = false
        defer {
            if !commitSuccessful {
                AtomicFileUtility.cleanupQuietly(at: stagedOutputURL)
            }
        }

        // Create empty output file for streaming writes
        fileManager.createFile(atPath: stagedOutputURL.path, contents: nil, attributes: nil)
        let outputHandle = try FileHandle(forWritingTo: stagedOutputURL)
        defer {
            try? outputHandle.close()
        }

        let inputHandle = try FileHandle(forReadingFrom: sourceURL)
        defer {
            try? inputHandle.close()
        }

        let reporter = StreamingProgressReporter(intervalSeconds: 0.1, progressHandler: progressHandler)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        if let gpgHome = gpgHome {
            env["GNUPGHOME"] = gpgHome.path
        }
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Concurrently run input streaming, stdout reading, and stderr accumulation
        return try await withTaskCancellationHandler {
            try process.run()

            let pid = process.processIdentifier

            // Asynchronously accumulate stderr for diagnostics
            let stderrTask = Task<String, Never> {
                var stderrBuffer = Data()
                let stderrHandle = stderrPipe.fileHandleForReading
                while true {
                    let chunk = stderrHandle.availableData
                    if chunk.isEmpty { break }
                    stderrBuffer.append(chunk)
                }
                return String(data: stderrBuffer, encoding: .utf8) ?? ""
            }

            // Asynchronously stream stdout chunks directly into the output FileHandle
            let stdoutTask = Task<Int64, Error> {
                var totalWritten: Int64 = 0
                let stdoutHandle = stdoutPipe.fileHandleForReading
                while true {
                    let chunk = stdoutHandle.availableData
                    if chunk.isEmpty { break }
                    try outputHandle.write(contentsOf: chunk)
                    totalWritten += Int64(chunk.count)
                }
                return totalWritten
            }

            // Stream input file in chunks into stdinPipe to guarantee constant memory
            let stdinTask = Task<Void, Error> {
                let stdinHandle = stdinPipe.fileHandleForWriting

                // If passphrase prefix is required (e.g., loopback pinentry)
                if let passphrase = passphrase {
                    if let passData = (passphrase + "\n").data(using: .utf8) {
                        try stdinHandle.write(contentsOf: passData)
                    }
                }

                var bytesSent: Int64 = 0
                let bufferSize = Self.defaultChunkSize

                while true {
                    try Task.checkCancellation()
                    let chunk = try inputHandle.read(upToCount: bufferSize)
                    guard let chunk = chunk, !chunk.isEmpty else {
                        break
                    }
                    try stdinHandle.write(contentsOf: chunk)
                    bytesSent += Int64(chunk.count)
                    await reporter.report(bytesProcessed: bytesSent, totalBytes: totalFileSize)
                }

                try? stdinHandle.close()
            }

            // Wait for streaming and process termination
            do {
                _ = try await stdinTask.value
            } catch {
                Self.terminateProcess(process, pid: pid)
                throw error
            }

            // Wait for child process exit
            while process.isRunning {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 50_000_000)
            }

            _ = try await stdoutTask.value
            let stderrOutput = await stderrTask.value

            let exitCode = process.terminationStatus
            if exitCode != 0 {
                let sanitizedError = stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                Self.logger.error("Streaming process exited with non-zero code \(exitCode): \(sanitizedError)")
                throw GPGError.executionFailed(sanitizedError.isEmpty ? "Process exited with code \(exitCode)" : sanitizedError)
            }

            // Atomically replace/commit staged output to final destination
            try AtomicFileUtility.commitTemporaryFile(from: stagedOutputURL, to: destinationURL)
            commitSuccessful = true

            // Final 100% progress report
            await reporter.report(bytesProcessed: totalFileSize, totalBytes: totalFileSize, force: true)

            return destinationURL
        } onCancel: {
            Self.terminateProcess(process, pid: process.processIdentifier)
        }
    }

    private static func terminateProcess(_ process: Process, pid: Int32) {
        guard process.isRunning else { return }
        process.terminate()

        // If not terminated gracefully after brief pause, send SIGKILL
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            if process.isRunning && pid > 0 {
                kill(pid, SIGKILL)
            }
        }
    }
}
