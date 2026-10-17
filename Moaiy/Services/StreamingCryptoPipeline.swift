//
//  StreamingCryptoPipeline.swift
//  Moaiy
//
//  Streaming I/O pipeline for file encryption and decryption.
//  Provides constant-memory chunked streaming, pipe deadlock prevention,
//  non-blocking asynchronous I/O with dual-queue backpressure, and throttled progress reporting.
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
    /// 8MB maximum in-flight stdout buffer before throttling stdin
    public static let maxInFlightOutputBytes: Int64 = 8 * 1024 * 1024

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
        validateCompletion: (@Sendable (_ exitCode: Int, _ stderr: String) throws -> Void)? = nil,
        progressHandler: (@Sendable (CryptoProgress) -> Void)? = nil
    ) async throws -> URL {
        try Task.checkCancellation()

        let fileManager = FileManager.default

        let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let totalFileSize = (sourceAttributes[.size] as? NSNumber)?.int64Value ?? 0

        // Use sandboxed container temporary storage for staging
        let stagingDir = try SecureTempStorage.makeOperationDirectory(prefix: "streaming-op")
        let stagedOutputFile = stagingDir.appendingPathComponent("output.tmp")

        var tempPassphrasePath: String?
        var passphraseByteCount = 0

        defer {
            if let passPath = tempPassphrasePath {
                // Securely scrub the temporary passphrase file with zeros before unlink
                if passphraseByteCount > 0 {
                    let fd = open(passPath, O_WRONLY)
                    if fd >= 0 {
                        var zeroes = [UInt8](repeating: 0, count: passphraseByteCount)
                        _ = zeroes.withUnsafeMutableBytes { buf in
                            write(fd, buf.baseAddress, buf.count)
                        }
                        fsync(fd)
                        close(fd)
                    }
                }
                unlink(passPath)
            }
            SecureTempStorage.removeOperationDirectory(stagingDir)
        }

        // Create staging output file with strict permissions (0600 for plaintext, 0644 for ciphertext)
        let outputPermissions: mode_t = isDecryption ? 0o600 : 0o644
        let stagedFd = open(stagedOutputFile.path, O_CREAT | O_WRONLY | O_TRUNC, outputPermissions)
        guard stagedFd >= 0 else {
            let errCode = errno
            throw GPGError.executionFailed("Failed to create temporary output file: \(String(cString: strerror(errCode)))")
        }
        let outputHandle = FileHandle(fileDescriptor: stagedFd, closeOnDealloc: true)

        let inputHandle = try FileHandle(forReadingFrom: sourceURL)
        defer {
            try? inputHandle.close()
        }

        var processArgs = arguments

        // Handle passphrase via dedicated loopback passphrase file created strictly with 0600
        if let passphrase = passphrase, !passphrase.isCleaned {
            let passFile = stagingDir.appendingPathComponent("passphrase.token")
            tempPassphrasePath = passFile.path

            try passphrase.withUnsafeUTF8 { rawBuffer in
                passphraseByteCount = rawBuffer.count
                let fd = open(passFile.path, O_CREAT | O_WRONLY | O_TRUNC | O_EXCL, 0o600)
                guard fd >= 0 else {
                    let err = errno
                    throw GPGError.executionFailed("Failed to securely open passphrase token file: \(String(cString: strerror(err)))")
                }
                if let base = rawBuffer.baseAddress, rawBuffer.count > 0 {
                    let written = write(fd, base, rawBuffer.count)
                    if written != rawBuffer.count {
                        close(fd)
                        throw GPGError.executionFailed("Failed to complete write to passphrase token file.")
                    }
                }
                fsync(fd)
                close(fd)
            }

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

        // Dedicated independent serial queues for stdin pumping and stdout disk writing
        let stdinQueue = DispatchQueue(label: "com.moaiy.streaming.stdin", qos: .userInitiated)
        let stdoutQueue = DispatchQueue(label: "com.moaiy.streaming.stdout", qos: .userInitiated)

        let state = PipelineExecutionState()

        let pipeGroup = DispatchGroup()
        pipeGroup.enter() // for stdout EOF
        pipeGroup.enter() // for stderr EOF

        // Non-blocking readabilityHandler on stderr: unregister upon EOF
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            autoreleasepool {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    pipeGroup.leave()
                    return
                }
                state.appendStderr(chunk)
            }
        }

        // Non-blocking readabilityHandler on stdout: write to disk via stdoutQueue and unregister on EOF
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            autoreleasepool {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    pipeGroup.leave()
                    return
                }

                let hasError = state.addInFlightBytes(Int64(chunk.count))
                guard !hasError else {
                    state.subtractInFlightBytes(Int64(chunk.count))
                    return
                }

                stdoutQueue.async {
                    autoreleasepool {
                        do {
                            try outputHandle.write(contentsOf: chunk)
                        } catch {
                            state.recordWriteError(error)
                            if process.isRunning {
                                process.terminate()
                            }
                        }
                        state.subtractInFlightBytes(Int64(chunk.count))
                    }
                }
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
            try Task.checkCancellation()

            // Asynchronous continuation on process exit
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { proc in
                    let status = proc.terminationStatus
                    let reason = proc.terminationReason

                    // Drain all remaining pipe reads and stdoutQueue writes before completing
                    pipeGroup.notify(queue: stdoutQueue) {
                        let snapshot = state.snapshot()

                        // Prioritize real I/O errors before checking signal termination,
                        // since write/read failures call process.terminate() which produces SIGTERM.
                        if let writeErr = snapshot.writeError {
                            continuation.resume(throwing: writeErr)
                            return
                        }
                        if let stdinErr = snapshot.stdinError {
                            continuation.resume(throwing: stdinErr)
                            return
                        }
                        if snapshot.isCancelled || (reason == .uncaughtSignal && (status == SIGTERM || status == SIGKILL)) {
                            continuation.resume(throwing: GPGError.operationCancelled)
                            return
                        }

                        if let validateCompletion {
                            do {
                                try validateCompletion(Int(status), snapshot.stderrString)
                                continuation.resume(returning: ())
                            } catch {
                                continuation.resume(throwing: error)
                            }
                            return
                        }

                        if status == 0 {
                            continuation.resume(returning: ())
                        } else {
                            let message = snapshot.stderrString.isEmpty ? "Process exited with code \(status)" : snapshot.stderrString
                            continuation.resume(throwing: GPGError.executionFailed(message))
                        }
                    }
                }

                do {
                    try process.run()
                    try? stdoutPipe.fileHandleForWriting.close()
                    try? stderrPipe.fileHandleForWriting.close()

                    // Stream file chunks into stdin on independent stdinQueue with backpressure
                    stdinQueue.async {
                        var bytesSent: Int64 = 0
                        let bufferSize = Self.defaultChunkSize
                        let stdinFd = stdinPipe.fileHandleForWriting.fileDescriptor
                        let inputFd = inputHandle.fileDescriptor
                        var reusableBuffer = [UInt8](repeating: 0, count: bufferSize)

                        while process.isRunning {
                            var shouldStop = false
                            autoreleasepool {
                                // Backpressure: pause stdin if stdout disk writes are lagging behind
                                while process.isRunning {
                                    let (backlog, hasError) = state.backpressureCheck()
                                    if hasError { break }
                                    if backlog < Self.maxInFlightOutputBytes { break }
                                    usleep(10_000) // 10ms wait
                                }

                                if state.shouldAbortStdin() {
                                    shouldStop = true
                                    return
                                }

                                let bytesRead = reusableBuffer.withUnsafeMutableBytes { rawBuf -> Int in
                                    guard let base = rawBuf.baseAddress else { return -1 }
                                    return read(inputFd, base, bufferSize)
                                }

                                if bytesRead < 0 {
                                    let err = errno
                                    state.recordStdinError(GPGError.executionFailed("Failed reading input file: \(String(cString: strerror(err)))"))
                                    if process.isRunning {
                                        process.terminate()
                                    }
                                    shouldStop = true
                                    return
                                }

                                if bytesRead == 0 {
                                    shouldStop = true
                                    return
                                }

                                var offset = 0
                                while offset < bytesRead {
                                    let written = reusableBuffer.withUnsafeBytes { rawBuf -> Int in
                                        guard let base = rawBuf.baseAddress else { return -1 }
                                        return write(stdinFd, base.advanced(by: offset), bytesRead - offset)
                                    }
                                    if written <= 0 {
                                        // If stdin pipe broke (e.g. child terminated early with failure)
                                        shouldStop = true
                                        return
                                    }
                                    offset += written
                                }

                                bytesSent += Int64(bytesRead)
                                let currentSent = bytesSent
                                Task {
                                    await reporter.report(bytesProcessed: currentSent, totalBytes: totalFileSize)
                                }
                            }
                            if shouldStop { break }
                        }
                        try? stdinPipe.fileHandleForWriting.close()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Sync output file to disk
            try outputHandle.synchronize()

            // Pre-flight check available disk space and commit staged output to final destination
            try SecureTempStorage.commitStagedFile(from: stagedOutputFile, to: destinationURL)
            if isDecryption {
                try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
            }

            // Final progress report
            await reporter.report(bytesProcessed: totalFileSize, totalBytes: totalFileSize, force: true)

            return destinationURL
        } onCancel: {
            state.markCancelled()

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

// MARK: - Thread-Safe Pipeline Execution State

private final class PipelineExecutionState: @unchecked Sendable {
    struct Snapshot {
        let isCancelled: Bool
        let writeError: Error?
        let stdinError: Error?
        let stderrString: String
    }

    private let lock = NSLock()
    private var accumulatedStderr = Data()
    private var ioWriteError: Error?
    private var stdinReadError: Error?
    private var inFlightOutputBytes: Int64 = 0
    private var wasCancelled = false

    func appendStderr(_ chunk: Data) {
        lock.lock()
        accumulatedStderr.append(chunk)
        lock.unlock()
    }

    /// Adds in-flight bytes and returns whether a write error has already occurred.
    func addInFlightBytes(_ count: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        inFlightOutputBytes += count
        return ioWriteError != nil
    }

    func subtractInFlightBytes(_ count: Int64) {
        lock.lock()
        inFlightOutputBytes = max(0, inFlightOutputBytes - count)
        lock.unlock()
    }

    func recordWriteError(_ error: Error) {
        lock.lock()
        if ioWriteError == nil {
            ioWriteError = error
        }
        lock.unlock()
    }

    func recordStdinError(_ error: Error) {
        lock.lock()
        if stdinReadError == nil {
            stdinReadError = error
        }
        lock.unlock()
    }

    func markCancelled() {
        lock.lock()
        wasCancelled = true
        lock.unlock()
    }

    func backpressureCheck() -> (backlog: Int64, hasError: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let hasErr = (ioWriteError != nil || stdinReadError != nil || wasCancelled)
        return (inFlightOutputBytes, hasErr)
    }

    func shouldAbortStdin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ioWriteError != nil || stdinReadError != nil || wasCancelled
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        let errString = String(data: accumulatedStderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Snapshot(
            isCancelled: wasCancelled,
            writeError: ioWriteError,
            stdinError: stdinReadError,
            stderrString: errString
        )
    }
}
