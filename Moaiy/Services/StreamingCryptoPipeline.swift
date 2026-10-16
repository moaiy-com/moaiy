//
//  StreamingCryptoPipeline.swift
//  Moaiy
//
//  Streaming I/O pipeline for file encryption and decryption.
//  Provides constant-memory chunked streaming, pipe deadlock prevention,
//  non-blocking asynchronous I/O, and throttled progress reporting.
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

/// Actor for debouncing progress callbacks to avoid overloading SwiftUI rendering
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

// MARK: - Streaming Process Pipeline Engine

/// Asynchronous streaming manager for running cryptographic processes with constant memory consumption
public final class StreamingCryptoPipeline: Sendable {
    private static let logger = Logger(subsystem: "com.moaiy.app", category: "StreamingCryptoPipeline")

    /// 256KB default chunk size for streaming I/O
    public static let defaultChunkSize = 256 * 1024

    public init() {}

    /// Executes a streaming operation connecting an input file to an external process stdin,
    /// draining stdout into a sandboxed staging file, and monitoring stderr asynchronously.
    public func executeStreamingFileOperation(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        gpgHome: URL?,
        sourceURL: URL,
        destinationURL: URL,
        isDecryption: Bool = false,
        passphrase: SecureString? = nil,
        progressHandler: (@Sendable (CryptoProgress) -> Void)? = nil
    ) async throws -> URL {
        let fileManager = FileManager.default

        // Ignore SIGPIPE to avoid app termination if child exits early during streaming
        signal(SIGPIPE, SIG_IGN)

        let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let totalFileSize = (sourceAttributes[.size] as? NSNumber)?.int64Value ?? 0

        // Use sandboxed container temporary storage for staging
        let stagingDir = try SecureTempStorage.makeOperationDirectory(prefix: "streaming-op")
        let stagedOutputFile = stagingDir.appendingPathComponent("output.tmp")

        var tempPassphraseFile: URL?
        defer {
            if let tempPass = tempPassphraseFile {
                // Best-effort overwrite before deletion
                if let handle = try? FileHandle(forWritingTo: tempPass) {
                    let zeroBuffer = [UInt8](repeating: 0, count: 256)
                    try? handle.write(contentsOf: zeroBuffer)
                    try? handle.close()
                }
                try? fileManager.removeItem(at: tempPass)
            }
            SecureTempStorage.removeOperationDirectory(stagingDir)
        }

        // Set secure file permissions: 0600 for decrypted plaintext, 0644 for ciphertext
        let outputPermissions: NSNumber = isDecryption ? 0o600 : 0o644
        fileManager.createFile(
            atPath: stagedOutputFile.path,
            contents: nil,
            attributes: [.posixPermissions: outputPermissions]
        )

        let outputHandle = try FileHandle(forWritingTo: stagedOutputFile)
        defer {
            try? outputHandle.close()
        }

        let inputHandle = try FileHandle(forReadingFrom: sourceURL)
        defer {
            try? inputHandle.close()
        }

        var processArgs = arguments

        // Handle passphrase via dedicated loopback passphrase file to avoid mixing into stdin
        if let passphrase = passphrase, !passphrase.isCleaned {
            let passFile = stagingDir.appendingPathComponent("passphrase.token")
            tempPassphraseFile = passFile
            try passphrase.withUnsafeUTF8 { rawBuffer in
                let data = Data(rawBuffer)
                try data.write(to: passFile, options: .atomic)
            }
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: passFile.path)

            processArgs.append(contentsOf: [
                "--pinentry-mode", "loopback",
                "--passphrase-file", passFile.path
            ])
        }

        let reporter = StreamingProgressReporter(intervalSeconds: 0.1, progressHandler: progressHandler)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = processArgs

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

        let ioQueue = DispatchQueue(label: "com.moaiy.streaming.io", qos: .userInitiated)
        let stderrLock = NSLock()
        var accumulatedStderr = Data()

        // Set up non-blocking readabilityHandlers on dedicated queues
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            stderrLock.lock()
            accumulatedStderr.append(chunk)
            stderrLock.unlock()
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            ioQueue.async {
                try? outputHandle.write(contentsOf: chunk)
            }
        }

        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            try? stdoutPipe.fileHandleForReading.close()
            try? stderrPipe.fileHandleForReading.close()
            try? stdoutPipe.fileHandleForWriting.close()
            try? stderrPipe.fileHandleForWriting.close()
        }

        return try await withTaskCancellationHandler {
            // Asynchronous continuation on process exit
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    let status = proc.terminationStatus
                    if status == 0 {
                        continuation.resume(returning: ())
                    } else {
                        stderrLock.lock()
                        let errString = String(data: accumulatedStderr, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        stderrLock.unlock()
                        let message = errString.isEmpty ? "Process exited with code \(status)" : errString
                        continuation.resume(throwing: GPGError.executionFailed(message))
                    }
                }

                do {
                    try process.run()
                    try? stdoutPipe.fileHandleForWriting.close()
                    try? stderrPipe.fileHandleForWriting.close()

                    // Stream file chunks into stdin on background queue
                    ioQueue.async {
                        var bytesSent: Int64 = 0
                        let bufferSize = Self.defaultChunkSize
                        let stdinHandle = stdinPipe.fileHandleForWriting

                        while process.isRunning {
                            guard let chunk = try? inputHandle.read(upToCount: bufferSize),
                                  let data = chunk, !data.isEmpty else {
                                break
                            }
                            do {
                                try stdinHandle.write(contentsOf: data)
                                bytesSent += Int64(data.count)
                                Task {
                                    await reporter.report(bytesProcessed: bytesSent, totalBytes: totalFileSize)
                                }
                            } catch {
                                break
                            }
                        }
                        try? stdinHandle.close()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Sync output file to disk
            try outputHandle.synchronize()

            // Safely write to destination
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: stagedOutputFile, to: destinationURL)

            // Final progress report
            await reporter.report(bytesProcessed: totalFileSize, totalBytes: totalFileSize, force: true)

            return destinationURL
        } onCancel: {
            if process.isRunning {
                process.terminate()
                let pid = process.processIdentifier
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                    if process.isRunning && pid > 0 {
                        kill(pid, SIGKILL)
                    }
                }
            }
        }
    }
}
