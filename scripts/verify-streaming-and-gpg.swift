//
//  verify-streaming-and-gpg.swift
//  Moaiy Loop Verification Runner
//
//  Standalone executable test harness compiled directly against Moaiy's Models, Services, Theme, and Utils
//  to execute real streaming I/O, 64MB backpressure & peak RSS verification, error prioritization,
//  overwrite-safe commitStagedFile, and GPG integration tests.
//

import Foundation
import Darwin

private func currentRSSBytes() -> UInt64 {
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

private final class PeakRSSMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private let baseline: UInt64
    private var peak: UInt64
    private var timer: DispatchSourceTimer?

    init() {
        let current = currentRSSBytes()
        self.baseline = current
        self.peak = current
    }

    func start() {
        let queue = DispatchQueue(label: "com.moaiy.test.rss-monitor", qos: .userInteractive)
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(5))
        source.setEventHandler { [weak self] in
            self?.sample()
        }
        self.timer = source
        source.resume()
    }

    func sample() {
        let current = currentRSSBytes()
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

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #fileID, line: Int = #line) throws {
    if !condition() {
        throw NSError(domain: "MoaiyVerificationError", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Assertion failed at \(file):\(line) — \(message)"
        ])
    }
}

@main
struct MoaiyVerificationRunner {
    static func main() async {
        signal(SIGPIPE, SIG_IGN)
        do {
            print("  [1/7] Verifying CryptoProgress & StreamingProgressReporter...")
            try await verifyProgressReporter()

            print("  [2/7] Verifying 64MB cat streaming pass-through, dual-queue backpressure & peak RSS (<32MB delta)...")
            try await verifyLargeStreamingPassThrough64MB()

            print("  [3/7] Verifying passphrase token 0600 permissions & zero-scrub cleanup...")
            try await verifyPassphraseTokenPermissionsAndCleanup()

            print("  [4/7] Verifying normal exit 15 vs signal cancellation & mid-flight Task cancellation...")
            try await verifyCancellationAndExitCode15()

            print("  [5/7] Verifying commitStagedFile net-space accounting & zero-data-loss overwrite protection...")
            try await verifyCommitStagedFileSafetyAndWriteFailure()

            print("  [6/7] Verifying SecureMemory & TransientFileRegistry lifecycle...")
            try verifySecureMemoryAndRegistry()

            print("  [7/7] Verifying GPG integration (encryptFileStreaming, decryptFileStreaming, decryptFile parity, single-pass resolvePrimaryFingerprint)...")
            try await verifyRealGPGIntegration()

            print("✅ All 7 verification suites passed!")
        } catch {
            fputs("❌ Verification failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func verifyProgressReporter() async throws {
        let half = CryptoProgress(bytesProcessed: 500, totalBytes: 1000)
        try assertCondition(half.fractionCompleted == 0.5, "Expected 0.5 fraction")
        let over = CryptoProgress(bytesProcessed: 1500, totalBytes: 1000)
        try assertCondition(over.fractionCompleted == 1.0, "Expected clamped 1.0 fraction")
    }

    static func verifyLargeStreamingPassThrough64MB() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("verify-large64-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let inputFile = tempDir.appendingPathComponent("input-64mb.bin")
        let outputFile = tempDir.appendingPathComponent("output-64mb.bin")

        // Write 64MB (256 * 256KB), which is 8x the 8MB maxInFlightOutputBytes backpressure threshold
        let totalChunks = 256
        let chunkPattern = Data((0..<(256 * 1024)).map { UInt8($0 & 0xFF) })
        _ = fm.createFile(atPath: inputFile.path, contents: nil)
        let writer = try FileHandle(forWritingTo: inputFile)
        for _ in 0..<totalChunks {
            try autoreleasepool {
                try writer.write(contentsOf: chunkPattern)
            }
        }
        try writer.close()

        let monitor = PeakRSSMonitor()
        monitor.start()

        let resultURL = try await pipeline.executeStreamingFileOperation(
            executableURL: URL(fileURLWithPath: "/bin/cat"),
            arguments: [],
            environment: [:],
            gpgHome: nil,
            sourceURL: inputFile,
            destinationURL: outputFile,
            isDecryption: true,
            passphrase: nil,
            progressHandler: { _ in
                monitor.sample()
            }
        )

        let peakDeltaMB = monitor.stopAndGetPeakDeltaMB()
        print(String(format: "        64MB pass-through complete (Peak RSS delta: %.2f MB, limit: < 32.00 MB)", peakDeltaMB))

        try assertCondition(resultURL.path == outputFile.path, "Output URL mismatch")
        let outAttrs = try fm.attributesOfItem(atPath: outputFile.path)
        let outSize = (outAttrs[.size] as? NSNumber)?.intValue ?? 0
        try assertCondition(outSize == totalChunks * 256 * 1024, "Output size mismatch: \(outSize)")
        try assertCondition(peakDeltaMB < 32.0, "Peak RSS delta (\(peakDeltaMB) MB) exceeded 32MB limit for 64MB payload")

        let perms = (outAttrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        try assertCondition(perms == 0o600, "Expected 0600 permissions on decrypted file, got \(String(perms, radix: 8))")
    }

    static func verifyPassphraseTokenPermissionsAndCleanup() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("verify-pass-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let inputFile = tempDir.appendingPathComponent("in.txt")
        let outputFile = tempDir.appendingPathComponent("out.txt")
        let permRecordFile = tempDir.appendingPathComponent("perm.txt")
        let pathRecordFile = tempDir.appendingPathComponent("path.txt")
        try Data("payload".utf8).write(to: inputFile)

        let script = """
        passfile="$4"
        printf "%s" "$passfile" > "\(pathRecordFile.path)"
        stat -f "%Lp" "$passfile" > "\(permRecordFile.path)"
        cat
        """

        let pass = SecureString("token-passphrase-secret")
        _ = try await pipeline.executeStreamingFileOperation(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script, "sh"],
            environment: [:],
            gpgHome: nil,
            sourceURL: inputFile,
            destinationURL: outputFile,
            isDecryption: false,
            passphrase: pass
        )

        let perm = try String(contentsOf: permRecordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenPath = try String(contentsOf: pathRecordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        try assertCondition(perm == "600", "Expected passphrase token permission 600, got \(perm)")
        try assertCondition(!tokenPath.isEmpty && !fm.fileExists(atPath: tokenPath), "Passphrase token file was not cleaned up")
    }

    static func verifyCancellationAndExitCode15() async throws {
        let pipeline = StreamingCryptoPipeline()
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("verify-cancel-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let inputFile = tempDir.appendingPathComponent("in.txt")
        let outputFile = tempDir.appendingPathComponent("out.txt")
        try Data(repeating: 0x41, count: 512 * 1024).write(to: inputFile)

        var exit15WasExecutionFailed = false
        do {
            _ = try await pipeline.executeStreamingFileOperation(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "echo 'error 15' >&2; exit 15"],
                environment: [:],
                gpgHome: nil,
                sourceURL: inputFile,
                destinationURL: outputFile
            )
        } catch GPGError.executionFailed(let msg) {
            exit15WasExecutionFailed = msg.contains("error 15")
        }
        try assertCondition(exit15WasExecutionFailed, "Normal exit code 15 should throw executionFailed, not operationCancelled")

        let readyFlag = tempDir.appendingPathComponent("ready.flag")
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
            if fm.fileExists(atPath: readyFlag.path) { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try assertCondition(fm.fileExists(atPath: readyFlag.path), "Child process did not start before cancellation")

        task.cancel()

        var caughtCancelOnly = false
        var unexpectedError: Error?
        do {
            _ = try await task.value
        } catch is CancellationError {
            caughtCancelOnly = true
        } catch GPGError.operationCancelled {
            caughtCancelOnly = true
        } catch {
            unexpectedError = error
        }
        try assertCondition(caughtCancelOnly && unexpectedError == nil, "Expected operationCancelled, got \(String(describing: unexpectedError))")
    }

    static func verifyCommitStagedFileSafetyAndWriteFailure() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("verify-disk-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let stagedFile = tempDir.appendingPathComponent("staged.tmp")
        let destFile = tempDir.appendingPathComponent("original.dat")
        let originalData = Data("USER_ORIGINAL_FILE_CONTENT_1234567890".utf8)
        try originalData.write(to: destFile)
        try Data(repeating: 0xAA, count: 4096).write(to: stagedFile)

        // 1. Insufficient net space -> throws before touching original file
        var threwInsufficientSpace = false
        do {
            try SecureTempStorage.commitStagedFile(
                from: stagedFile,
                to: destFile,
                availableCapacityOverride: 128
            )
        } catch GPGError.executionFailed(let msg) {
            threwInsufficientSpace = msg.contains("Insufficient disk space")
        }
        try assertCondition(threwInsufficientSpace, "Expected insufficient disk space error")
        let preservedAfterSpaceCheck = try Data(contentsOf: destFile)
        try assertCondition(preservedAfterSpaceCheck == originalData, "Original file was lost when disk space preflight failed")

        // 2. Net space accounting: overwriting a 4096B file with a 4096B staged file requires 0 net bytes
        let equalSizeDest = tempDir.appendingPathComponent("equal-4k.dat")
        try Data(repeating: 0xBB, count: 4096).write(to: equalSizeDest)
        try SecureTempStorage.commitStagedFile(
            from: stagedFile,
            to: equalSizeDest,
            availableCapacityOverride: 128
        )
        let updatedEqual = try Data(contentsOf: equalSizeDest)
        try assertCondition(updatedEqual == Data(repeating: 0xAA, count: 4096), "Net space overwrite of equal-sized file should succeed")

        // 3. Permission failure AFTER space check passes (0400 read-only destination file):
        //    commitStagedFile must NOT delete the existing destination file!
        try fm.setAttributes([.posixPermissions: 0o400], ofItemAtPath: destFile.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destFile.path) }

        var threwWritePermissionError = false
        do {
            try SecureTempStorage.commitStagedFile(
                from: stagedFile,
                to: destFile,
                availableCapacityOverride: 1024 * 1024
            )
        } catch {
            threwWritePermissionError = true
        }
        try assertCondition(threwWritePermissionError, "Expected write error on read-only destination file")
        try assertCondition(fm.fileExists(atPath: destFile.path), "Read-only destination file was deleted on failed overwrite!")
        let preservedAfterPermFailure = try Data(contentsOf: destFile)
        try assertCondition(preservedAfterPermFailure == originalData, "Original file content was corrupted on permission failure!")
    }

    static func verifySecureMemoryAndRegistry() throws {
        let s = SecureString("sensitive-value")
        var initialLen = 0
        s.withUnsafeUTF8 { initialLen = $0.count }
        try assertCondition(initialLen == 15 && !s.isCleaned, "SecureString initial state invalid")
        s.zeroize()
        try assertCondition(s.isCleaned && s.revealString().isEmpty, "SecureString zeroize failed")

        let dir = try SecureTempStorage.makeOperationDirectory(prefix: "reg-test")
        try assertCondition(TransientFileRegistry.shared.trackedCount >= 1, "Directory not registered in TransientFileRegistry")
        SecureTempStorage.removeOperationDirectory(dir)
        try assertCondition(!FileManager.default.fileExists(atPath: dir.path), "Directory not removed")
    }

    @MainActor
    static func verifyRealGPGIntegration() async throws {
        // 7a. Deterministic verification of single-pass matchPrimaryFingerprintsInColonOutput and validateDecryptionOutcome
        let sampleColon = """
        sec:u:255:22:80A9F21258CB1E83:1773379357:::u:::scESCA:::+::ed25519:::0:
        fpr:::::::::50AA1EFC028475CBC64AF04980A9F21258CB1E83:
        uid:u::::1773379357::::::Alice <alice@moaiy.test>:
        ssb:u:255:18:21635FE639C33F67:1773379357::::::e:::+::cv25519::
        fpr:::::::::9DAF4148FF8A9D58E5BF22F7A9491BDF1AEC49B2:
        """
        let primaryFpr = "50AA1EFC028475CBC64AF04980A9F21258CB1E83"
        let subFpr = "9DAF4148FF8A9D58E5BF22F7A9491BDF1AEC49B2"
        try assertCondition(
            GPGService.matchPrimaryFingerprintsInColonOutput(sampleColon, normalizedReference: "58CB1E83") == [primaryFpr],
            "8-char short key ID resolution failed"
        )
        try assertCondition(
            GPGService.matchPrimaryFingerprintsInColonOutput(sampleColon, normalizedReference: "80A9F21258CB1E83") == [primaryFpr],
            "16-char long key ID resolution failed"
        )
        try assertCondition(
            GPGService.matchPrimaryFingerprintsInColonOutput(sampleColon, normalizedReference: subFpr) == [primaryFpr],
            "40-char subkey fingerprint resolution to primary fingerprint failed"
        )
        try assertCondition(
            GPGService.matchPrimaryFingerprintsInColonOutput(sampleColon, normalizedReference: "21635FE639C33F67") == [primaryFpr],
            "Subkey ID resolution to primary fingerprint failed"
        )

        var badPassMapped = false
        do {
            try GPGService.validateDecryptionOutcome(
                exitCode: 2,
                stdout: nil,
                stderr: "[GNUPG:] BAD_PASSPHRASE 80A9F21258CB1E83\ngpg: decryption failed: Bad passphrase",
                preferredSecretKey: primaryFpr,
                normalizedPreferredSecretKey: primaryFpr
            )
        } catch GPGError.invalidPassphrase {
            badPassMapped = true
        }
        try assertCondition(badPassMapped, "validateDecryptionOutcome did not map BAD_PASSPHRASE to .invalidPassphrase")

        var noSecKeyMapped = false
        do {
            try GPGService.validateDecryptionOutcome(
                exitCode: 2,
                stdout: nil,
                stderr: "[GNUPG:] NO_SECKEY 21635FE639C33F67\ngpg: decryption failed: No secret key",
                preferredSecretKey: primaryFpr,
                normalizedPreferredSecretKey: primaryFpr
            )
        } catch GPGError.keyNotFound {
            noSecKeyMapped = true
        }
        try assertCondition(noSecKeyMapped, "validateDecryptionOutcome did not map NO_SECKEY to .keyNotFound")

        var wrongPreferredRejected = false
        do {
            try GPGService.validateDecryptionOutcome(
                exitCode: 0,
                stdout: nil,
                stderr: "[GNUPG:] DECRYPTION_KEY \(subFpr) \(primaryFpr) u\n[GNUPG:] DECRYPTION_OKAY",
                preferredSecretKey: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                normalizedPreferredSecretKey: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
            )
        } catch GPGError.keyNotFound {
            wrongPreferredRejected = true
        }
        try assertCondition(wrongPreferredRejected, "validateDecryptionOutcome did not reject mismatched preferredSecretKey")

        try GPGService.validateDecryptionOutcome(
            exitCode: 0,
            stdout: nil,
            stderr: "[GNUPG:] DECRYPTION_KEY \(subFpr) \(primaryFpr) u\n[GNUPG:] DECRYPTION_OKAY",
            preferredSecretKey: primaryFpr,
            normalizedPreferredSecretKey: primaryFpr
        )

        // 7b. Live gpg-agent E2E verification (runs when host Seatbelt allows Unix domain socket bind())
        let fm = FileManager.default
        let shortId = String(format: "%06x", UInt32.random(in: 0..<0xFFFFFF))
        let tempDir = URL(fileURLWithPath: "/tmp/mgpg-\(shortId)", isDirectory: true)
        let gpgHomeDir = tempDir.appendingPathComponent("g", isDirectory: true)
        try fm.createDirectory(at: gpgHomeDir, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: gpgHomeDir.path)

        let service = GPGService.shared
        for _ in 0..<30 {
            if service.isReady { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        defer {
            try? service.useAppManagedGPGHome()
            try? fm.removeItem(at: tempDir)
        }

        try service.configureExternalGPGHome(gpgHomeDir)

        var emptyRejected = false
        do {
            _ = try await service.resolvePrimaryFingerprint(for: "")
        } catch GPGError.keyNotFound {
            emptyRejected = true
        }
        try assertCondition(emptyRejected, "Empty key reference must throw keyNotFound")

        let passA = "alpha-pass-123"
        let passB = "bravo-pass-456"
        let fprA: String
        let fprB: String
        do {
            fprA = try await service.generateKey(name: "Alice Test", email: "alice@moaiy.test", keyType: .ecc, passphrase: passA)
            fprB = try await service.generateKey(name: "Bravo Test", email: "bravo@moaiy.test", keyType: .ecc, passphrase: passB)
        } catch let error as GPGError {
            if error.localizedDescription.contains("error binding socket") || error.localizedDescription.contains("Operation not permitted") {
                print("        [Sandbox Notice] Host seatbelt blocked gpg-agent Unix domain socket bind(); deterministic GPG status-fd & colon-parser assertions passed (run in standard terminal for live gpg-agent daemon E2E).")
                return
            }
            throw error
        }

        let resolvedShort = try await service.resolvePrimaryFingerprint(for: String(fprA.suffix(8)))
        let resolvedLong = try await service.resolvePrimaryFingerprint(for: String(fprA.suffix(16)))
        try assertCondition(resolvedShort == fprA && resolvedLong == fprA, "Short/long key ID resolution failed")

        let subkeysA = try await service.listSubkeys(primaryKeyID: fprA)
        if let sub = subkeysA.first {
            let resolvedSub = try await service.resolvePrimaryFingerprint(for: sub.fingerprint)
            try assertCondition(resolvedSub == fprA, "40-char subkey fingerprint resolution to primary fingerprint failed (got \(resolvedSub), expected \(fprA))")
        }

        let plainURL = tempDir.appendingPathComponent("plain.txt")
        let cipherURL = tempDir.appendingPathComponent("plain.txt.gpg")
        let streamOutURL = tempDir.appendingPathComponent("stream-out.txt")
        let legacyOutURL = tempDir.appendingPathComponent("legacy-out.txt")
        let payload = Data("Moaiy Real GPG Streaming Verification Payload\n".utf8)
        try payload.write(to: plainURL)

        _ = try await service.encryptFileStreaming(
            sourceURL: plainURL,
            destinationURL: cipherURL,
            recipients: [fprA],
            armor: false,
            allowUntrustedRecipients: true
        )
        try assertCondition(fm.fileExists(atPath: cipherURL.path), "Encrypted file not created")

        var streamWrongPass = false
        do {
            _ = try await service.decryptFileStreaming(
                sourceURL: cipherURL,
                destinationURL: streamOutURL,
                passphrase: SecureString("wrong"),
                preferredSecretKey: fprA
            )
        } catch GPGError.invalidPassphrase {
            streamWrongPass = true
        }
        try assertCondition(streamWrongPass, "decryptFileStreaming did not map wrong passphrase to GPGError.invalidPassphrase")

        var legacyWrongPass = false
        do {
            _ = try await service.decryptFile(
                sourceURL: cipherURL,
                destinationURL: legacyOutURL,
                passphrase: "wrong",
                preferredSecretKey: fprA
            )
        } catch GPGError.invalidPassphrase {
            legacyWrongPass = true
        }
        try assertCondition(legacyWrongPass, "decryptFile did not map wrong passphrase to GPGError.invalidPassphrase")

        var streamWrongKey = false
        do {
            _ = try await service.decryptFileStreaming(
                sourceURL: cipherURL,
                destinationURL: streamOutURL,
                passphrase: SecureString(passA),
                preferredSecretKey: fprB
            )
        } catch GPGError.keyNotFound {
            streamWrongKey = true
        }
        try assertCondition(streamWrongKey && !fm.fileExists(atPath: streamOutURL.path), "decryptFileStreaming did not enforce ensurePreferredDecryptionKey")

        var legacyWrongKey = false
        do {
            _ = try await service.decryptFile(
                sourceURL: cipherURL,
                destinationURL: legacyOutURL,
                passphrase: passA,
                preferredSecretKey: fprB
            )
        } catch GPGError.keyNotFound {
            legacyWrongKey = true
        }
        try assertCondition(legacyWrongKey, "decryptFile did not enforce ensurePreferredDecryptionKey")

        _ = try await service.decryptFileStreaming(
            sourceURL: cipherURL,
            destinationURL: streamOutURL,
            passphrase: SecureString(passA),
            preferredSecretKey: "   "
        )
        let decrypted = try Data(contentsOf: streamOutURL)
        try assertCondition(decrypted == payload, "Decrypted content mismatch")

        _ = try await service.decryptFile(
            sourceURL: cipherURL,
            destinationURL: legacyOutURL,
            passphrase: passA,
            preferredSecretKey: "   "
        )
        let legacyDecrypted = try Data(contentsOf: legacyOutURL)
        try assertCondition(legacyDecrypted == payload, "Legacy decrypted content mismatch")

        let bravoCipherURL = tempDir.appendingPathComponent("bravo.gpg")
        _ = try await service.encryptFileStreaming(
            sourceURL: plainURL,
            destinationURL: bravoCipherURL,
            recipients: [fprB],
            armor: false,
            allowUntrustedRecipients: true
        )
        try await service.deleteKey(keyID: fprB, secret: true)

        var streamMissingKey = false
        do {
            _ = try await service.decryptFileStreaming(
                sourceURL: bravoCipherURL,
                destinationURL: tempDir.appendingPathComponent("b1.txt"),
                passphrase: SecureString(passB),
                preferredSecretKey: nil
            )
        } catch GPGError.keyNotFound {
            streamMissingKey = true
        }
        try assertCondition(streamMissingKey, "decryptFileStreaming did not map missing secret key to GPGError.keyNotFound")

        var legacyMissingKey = false
        do {
            _ = try await service.decryptFile(
                sourceURL: bravoCipherURL,
                destinationURL: tempDir.appendingPathComponent("b2.txt"),
                passphrase: passB,
                preferredSecretKey: nil
            )
        } catch GPGError.keyNotFound {
            legacyMissingKey = true
        }
        try assertCondition(legacyMissingKey, "decryptFile did not map missing secret key to GPGError.keyNotFound")
    }
}
