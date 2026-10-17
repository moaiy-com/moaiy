//
//  StreamingCryptoPipelineTests.swift
//  MoaiyTests
//
//  Unit and real GPG integration tests for the streaming crypto pipeline,
//  dual-queue backpressure, error prioritization, overwrite-safe commitStagedFile,
//  and parity between decryptFile and decryptFileStreaming.
//

import Foundation
import Darwin
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

private func currentProcessResidentMemoryBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard kerr == KERN_SUCCESS else { return 0 }
    return info.resident_size
}

private final class PeakRSSSampler: @unchecked Sendable {
    private let lock = NSLock()
    private let baseline: UInt64
    private var peak: UInt64
    private var timer: DispatchSourceTimer?

    init() {
        let current = currentProcessResidentMemoryBytes()
        self.baseline = current
        self.peak = current
    }

    func start() {
        let queue = DispatchQueue(label: "com.moaiy.tests.rss-sampler", qos: .userInteractive)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(5))
        source.setEventHandler { [weak self] in
            self?.sample()
        }
        self.timer = source
        source.resume()
    }

    func sample() {
        let current = currentProcessResidentMemoryBytes()
        lock.lock()
        if current > peak {
            peak = current
        }
        lock.unlock()
    }

    func stopAndGetPeakDeltaMB() -> Double {
        timer?.cancel()
        timer = nil
        sample()
        lock.lock()
        defer { lock.unlock() }
        guard peak > baseline else { return 0.0 }
        return Double(peak - baseline) / (1024.0 * 1024.0)
    }
}

@Suite("Streaming Crypto Pipeline Tests", .serialized)
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

        await reporter.report(bytesProcessed: 100, totalBytes: 1000)
        await reporter.report(bytesProcessed: 200, totalBytes: 1000)
        await reporter.report(bytesProcessed: 300, totalBytes: 1000)
        await reporter.report(bytesProcessed: 1000, totalBytes: 1000, force: true)

        let fractions = recorder.recordedFractions
        #expect(!fractions.isEmpty)
        #expect(fractions.last == 1.0)
    }

    @Test("StreamingCryptoPipeline executes 64MB pass-through with dual-queue backpressure and peak RSS delta < 32MB")
    func streamingCryptoPipeline_executes64MBPassThroughWithBoundedPeakRSS() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input-64mb.bin")
        let outputFile = tempDir.appendingPathComponent("output-64mb.bin")

        // Create a 64MB file (8x the 8MB maxInFlightOutputBytes threshold) streamed to disk in 256KB blocks
        let totalChunks = 256 // 256 * 256KB = 64MB
        let chunkPattern = Data((0..<(256 * 1024)).map { UInt8($0 & 0xFF) })
        _ = fileManager.createFile(atPath: inputFile.path, contents: nil)
        let writer = try FileHandle(forWritingTo: inputFile)
        for _ in 0..<totalChunks {
            try writer.write(contentsOf: chunkPattern)
        }
        try writer.close()

        let catURL = URL(fileURLWithPath: "/bin/cat")
        let recorder = ProgressRecorder()
        let rssSampler = PeakRSSSampler()
        rssSampler.start()

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
            rssSampler.sample()
            recorder.record(progress.fractionCompleted)
        }

        let peakDeltaMB = rssSampler.stopAndGetPeakDeltaMB()

        #expect(resultURL.path == outputFile.path)
        #expect(fileManager.fileExists(atPath: outputFile.path))

        let outAttrs = try fileManager.attributesOfItem(atPath: outputFile.path)
        let outSize = (outAttrs[.size] as? NSNumber)?.intValue ?? 0
        #expect(outSize == totalChunks * 256 * 1024)
        #expect(recorder.count > 0)
        // Peak RSS delta must remain well below half the 64MB file size (< 32MB)
        #expect(peakDeltaMB < 32.0)

        if let posixPermissions = outAttrs[.posixPermissions] as? NSNumber {
            #expect(posixPermissions.intValue == 0o600)
        }
    }

    @Test("StreamingCryptoPipeline verifies passphrase token file 0600 permissions and post-run cleanup")
    func streamingCryptoPipeline_verifiesPassphraseTokenPermissionsAndCleanup() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-pass-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input.txt")
        let outputFile = tempDir.appendingPathComponent("output.txt")
        let permRecordFile = tempDir.appendingPathComponent("perm.txt")
        let pathRecordFile = tempDir.appendingPathComponent("token_path.txt")
        try Data("secret payload".utf8).write(to: inputFile)

        let script = """
        passfile="$4"
        printf "%s" "$passfile" > "\(pathRecordFile.path)"
        stat -f "%Lp" "$passfile" > "\(permRecordFile.path)"
        cat
        """

        let securePass = SecureString("super-secret-passphrase-123")
        _ = try await pipeline.executeStreamingFileOperation(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script, "sh"],
            environment: [:],
            gpgHome: nil,
            sourceURL: inputFile,
            destinationURL: outputFile,
            isDecryption: false,
            passphrase: securePass
        )

        let recordedPerm = try String(contentsOf: permRecordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let recordedPath = try String(contentsOf: pathRecordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(recordedPerm == "600")
        #expect(!recordedPath.isEmpty)
        #expect(!fileManager.fileExists(atPath: recordedPath))
    }

    @Test("StreamingCryptoPipeline does not misclassify normal exit code 15 as operationCancelled")
    func streamingCryptoPipeline_normalExit15IsExecutionFailedNotCancelled() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-exit15-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input.txt")
        let outputFile = tempDir.appendingPathComponent("output.txt")
        try Data("sample".utf8).write(to: inputFile)

        var caughtExecutionFailed = false
        var caughtCancelled = false
        do {
            _ = try await pipeline.executeStreamingFileOperation(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "echo 'gpg fatal error 15' >&2; exit 15"],
                environment: [:],
                gpgHome: nil,
                sourceURL: inputFile,
                destinationURL: outputFile
            )
        } catch GPGError.operationCancelled {
            caughtCancelled = true
        } catch GPGError.executionFailed(let msg) {
            caughtExecutionFailed = msg.contains("gpg fatal error 15")
        } catch {
            // Unexpected error type
        }

        #expect(caughtExecutionFailed)
        #expect(!caughtCancelled)
        #expect(!fileManager.fileExists(atPath: outputFile.path))
    }

    @Test("StreamingCryptoPipeline terminates running child process on mid-flight Task cancellation")
    func streamingCryptoPipeline_cancelsRunningChildProcess() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("streaming-cancel-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let inputFile = tempDir.appendingPathComponent("input.txt")
        let outputFile = tempDir.appendingPathComponent("output.txt")
        let readyFlag = tempDir.appendingPathComponent("started.flag")
        try Data(repeating: 0x42, count: 1024 * 1024).write(to: inputFile)

        let task = Task {
            try await pipeline.executeStreamingFileOperation(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "touch '\(readyFlag.path)'; sleep 10"],
                environment: [:],
                gpgHome: nil,
                sourceURL: inputFile,
                destinationURL: outputFile
            )
        }

        for _ in 0..<50 {
            if fileManager.fileExists(atPath: readyFlag.path) {
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(fileManager.fileExists(atPath: readyFlag.path))

        task.cancel()

        var caughtCancellationOnly = false
        var caughtOtherError: Error?
        do {
            _ = try await task.value
        } catch is CancellationError {
            caughtCancellationOnly = true
        } catch GPGError.operationCancelled {
            caughtCancellationOnly = true
        } catch {
            caughtOtherError = error
        }

        #expect(caughtCancellationOnly)
        #expect(caughtOtherError == nil)
        #expect(!fileManager.fileExists(atPath: outputFile.path))
    }

    @Test("SecureTempStorage.commitStagedFile accounts for overwritten file space and preserves original file on space or permission failure")
    func commitStagedFile_accountsForNetSpaceAndPreservesOriginalOnFailure() throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("commit-space-test-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        let stagedFile = tempDir.appendingPathComponent("staged.tmp")
        let destinationFile = tempDir.appendingPathComponent("user-original.dat")

        let originalContent = Data("ORIGINAL_USER_DATA_MUST_NOT_BE_LOST".utf8)
        let newStagedContent = Data(repeating: 0x5A, count: 4096)

        try originalContent.write(to: destinationFile)
        try newStagedContent.write(to: stagedFile)

        // 1. Insufficient net space -> throws before modifying destinationFile
        var threwInsufficientSpace = false
        do {
            try SecureTempStorage.commitStagedFile(
                from: stagedFile,
                to: destinationFile,
                availableCapacityOverride: 512
            )
        } catch GPGError.executionFailed(let message) {
            threwInsufficientSpace = message.contains("Insufficient disk space")
        }
        #expect(threwInsufficientSpace)
        let preservedData = try Data(contentsOf: destinationFile)
        #expect(preservedData == originalContent)

        // 2. Net space accounting: overwriting a 4096-byte existing file with a 4096-byte staged file requires 0 net bytes
        let equalDest = tempDir.appendingPathComponent("equal-size.dat")
        try Data(repeating: 0x11, count: 4096).write(to: equalDest)
        try SecureTempStorage.commitStagedFile(
            from: stagedFile,
            to: equalDest,
            availableCapacityOverride: 128
        )
        #expect((try Data(contentsOf: equalDest)) == newStagedContent)

        // 3. Permission failure AFTER space check passes (0400 read-only destination file):
        //    original file must NOT be deleted or corrupted
        try fileManager.setAttributes([.posixPermissions: 0o400], ofItemAtPath: destinationFile.path)
        defer { try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationFile.path) }

        var threwWriteError = false
        do {
            try SecureTempStorage.commitStagedFile(
                from: stagedFile,
                to: destinationFile,
                availableCapacityOverride: 1024 * 1024
            )
        } catch {
            threwWriteError = true
        }
        #expect(threwWriteError)
        #expect(fileManager.fileExists(atPath: destinationFile.path))
        #expect((try Data(contentsOf: destinationFile)) == originalContent)
    }

    @Test("Real GPG integration: encryptFileStreaming, decryptFileStreaming, decryptFile parity, and single-pass resolvePrimaryFingerprint")
    @MainActor
    func realGPG_streamingAndNonStreamingParityChecks() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("moaiy-gpg-int-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let service = GPGService.shared
        let timeoutNanoseconds: UInt64 = 30_000_000_000
        let stepNanoseconds: UInt64 = 200_000_000
        var elapsed: UInt64 = 0
        while !service.isReady && elapsed < timeoutNanoseconds {
            try await Task.sleep(nanoseconds: stepNanoseconds)
            elapsed += stepNanoseconds
        }
        #expect(service.isReady == true)

        var generatedFingerprints: [String] = []
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        do {
            let passA = "alpha-passphrase-123"
            let passB = "bravo-passphrase-456"
            let fprA = try await service.generateKey(
                name: "Alice Streaming",
                email: "alice-\(UUID().uuidString.prefix(8))@moaiy.test",
                keyType: .ecc,
                passphrase: passA
            )
            generatedFingerprints.append(fprA)

            let fprB = try await service.generateKey(
                name: "Bravo Streaming",
                email: "bravo-\(UUID().uuidString.prefix(8))@moaiy.test",
                keyType: .ecc,
                passphrase: passB
            )
            generatedFingerprints.append(fprB)

            var emptyThrewKeyNotFound = false
            do {
                _ = try await service.resolvePrimaryFingerprint(for: "   ")
            } catch GPGError.keyNotFound {
                emptyThrewKeyNotFound = true
            }
            #expect(emptyThrewKeyNotFound)

            let resolvedFull = try await service.resolvePrimaryFingerprint(for: fprA)
            let resolvedLongID = try await service.resolvePrimaryFingerprint(for: String(fprA.suffix(16)))
            let resolvedShortID = try await service.resolvePrimaryFingerprint(for: String(fprA.suffix(8)))
            #expect(resolvedFull == fprA)
            #expect(resolvedLongID == fprA)
            #expect(resolvedShortID == fprA)

            let subkeysA = try await service.listSubkeys(primaryKeyID: fprA)
            if let firstSubkey = subkeysA.first {
                let resolvedSubkey = try await service.resolvePrimaryFingerprint(for: firstSubkey.fingerprint)
                #expect(resolvedSubkey == fprA)
            }

            let plaintextURL = tempDir.appendingPathComponent("secret-document.txt")
            let encryptedURL = tempDir.appendingPathComponent("secret-document.txt.gpg")
            let decryptedStreamURL = tempDir.appendingPathComponent("decrypted-stream.txt")
            let decryptedLegacyURL = tempDir.appendingPathComponent("decrypted-legacy.txt")

            let originalPayload = Data("Moaiy v1.0 Real GPG Streaming Integration Payload\n".utf8)
            try originalPayload.write(to: plaintextURL)

            _ = try await service.encryptFileStreaming(
                sourceURL: plaintextURL,
                destinationURL: encryptedURL,
                recipients: [fprA],
                armor: false,
                allowUntrustedRecipients: true
            )
            #expect(fileManager.fileExists(atPath: encryptedURL.path))

            // Wrong passphrase -> both decryptFile and decryptFileStreaming must throw GPGError.invalidPassphrase
            var streamWrongPassThrewInvalid = false
            do {
                _ = try await service.decryptFileStreaming(
                    sourceURL: encryptedURL,
                    destinationURL: decryptedStreamURL,
                    passphrase: SecureString("wrong-passphrase-xyz"),
                    preferredSecretKey: fprA
                )
            } catch GPGError.invalidPassphrase {
                streamWrongPassThrewInvalid = true
            }
            #expect(streamWrongPassThrewInvalid)
            #expect(!fileManager.fileExists(atPath: decryptedStreamURL.path))

            var legacyWrongPassThrewInvalid = false
            do {
                _ = try await service.decryptFile(
                    sourceURL: encryptedURL,
                    destinationURL: decryptedLegacyURL,
                    passphrase: "wrong-passphrase-xyz",
                    preferredSecretKey: fprA
                )
            } catch GPGError.invalidPassphrase {
                legacyWrongPassThrewInvalid = true
            }
            #expect(legacyWrongPassThrewInvalid)

            // Wrong preferredSecretKey -> throws GPGError.keyNotFound
            var streamWrongKeyThrewNotFound = false
            do {
                _ = try await service.decryptFileStreaming(
                    sourceURL: encryptedURL,
                    destinationURL: decryptedStreamURL,
                    passphrase: SecureString(passA),
                    preferredSecretKey: fprB
                )
            } catch GPGError.keyNotFound {
                streamWrongKeyThrewNotFound = true
            }
            #expect(streamWrongKeyThrewNotFound)
            #expect(!fileManager.fileExists(atPath: decryptedStreamURL.path))

            var legacyWrongKeyThrewNotFound = false
            do {
                _ = try await service.decryptFile(
                    sourceURL: encryptedURL,
                    destinationURL: decryptedLegacyURL,
                    passphrase: passA,
                    preferredSecretKey: fprB
                )
            } catch GPGError.keyNotFound {
                legacyWrongKeyThrewNotFound = true
            }
            #expect(legacyWrongKeyThrewNotFound)

            // Whitespace/invalid preferredSecretKey ("   ") is ignored before decryption (legacy parity) and succeeds with valid passphrase
            _ = try await service.decryptFileStreaming(
                sourceURL: encryptedURL,
                destinationURL: decryptedStreamURL,
                passphrase: SecureString(passA),
                preferredSecretKey: "   "
            )
            let decryptedData = try Data(contentsOf: decryptedStreamURL)
            #expect(decryptedData == originalPayload)

            let decAttrs = try fileManager.attributesOfItem(atPath: decryptedStreamURL.path)
            if let perms = decAttrs[.posixPermissions] as? NSNumber {
                #expect(perms.intValue == 0o600)
            }
        } catch {
            for fpr in generatedFingerprints {
                try? await service.deleteKey(keyID: fpr, secret: true)
                try? await service.deleteKey(keyID: fpr, secret: false)
            }
            throw error
        }

        for fpr in generatedFingerprints {
            try? await service.deleteKey(keyID: fpr, secret: true)
            try? await service.deleteKey(keyID: fpr, secret: false)
        }
    }
}
