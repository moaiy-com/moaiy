//
//  BackupArchiveService.swift
//  Moaiy
//
//  Non-blocking ZIP archive creation and extraction service using /usr/bin/ditto.
//  Drains stdout/stderr asynchronously via readabilityHandler to prevent 64KB pipe deadlocks.
//

import Foundation
import Darwin

enum BackupArchiveError: Error, Equatable {
    case commandFailed(exitCode: Int, stderr: String?)
    case timedOut
}

private final class ArchivePipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var snapshot: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

actor BackupArchiveService {
    static let shared = BackupArchiveService()

    private let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")

    func createZipArchive(
        from sourceDirectory: URL,
        to destinationZipURL: URL,
        timeout: TimeInterval = Constants.GPG.defaultTimeout
    ) async throws {
        try await runDitto(
            arguments: [
                "-c",
                "-k",
                "--sequesterRsrc",
                "--keepParent",
                "--",
                sourceDirectory.path,
                destinationZipURL.path
            ],
            timeout: timeout
        )
    }

    func extractZipArchive(
        from zipURL: URL,
        to destinationDirectory: URL,
        timeout: TimeInterval = Constants.GPG.defaultTimeout
    ) async throws {
        try await runDitto(
            arguments: [
                "-x",
                "-k",
                "--",
                zipURL.path,
                destinationDirectory.path
            ],
            timeout: timeout
        )
    }

    private func runDitto(arguments: [String], timeout: TimeInterval) async throws {
        let process = Process()
        process.executableURL = dittoURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBuffer = ArchivePipeBuffer()
        let stderrBuffer = ArchivePipeBuffer()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            autoreleasepool {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stdoutBuffer.append(chunk)
                }
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            autoreleasepool {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    stderrBuffer.append(chunk)
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

        try await withTaskCancellationHandler {
            try process.run()
            try? stdoutPipe.fileHandleForWriting.close()
            try? stderrPipe.fileHandleForWriting.close()

            let deadline = Date().addingTimeInterval(timeout)
            do {
                while process.isRunning && Date() < deadline {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
            } catch is CancellationError {
                Self.forceStopProcess(process)
                throw GPGError.operationCancelled
            }

            if process.isRunning {
                Self.forceStopProcess(process)
                throw BackupArchiveError.timedOut
            }

            let exitCode = Int(process.terminationStatus)
            guard exitCode == 0 else {
                let stderrText = String(data: stderrBuffer.snapshot, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw BackupArchiveError.commandFailed(
                    exitCode: exitCode,
                    stderr: stderrText?.isEmpty == false ? stderrText : nil
                )
            }
        } onCancel: {
            Self.forceStopProcess(process)
        }
    }

    nonisolated private static func forceStopProcess(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        if process.isRunning {
            let pid = process.processIdentifier
            if pid > 0 {
                kill(pid, SIGKILL)
            }
        }
    }
}
