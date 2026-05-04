//
//  GPGProcessExecutorTests.swift
//  MoaiyTests
//
//  Unit tests for subprocess cancellation and timeout cleanup.
//

import Darwin
import Foundation
import Testing
@testable import Moaiy

@Suite("GPG Process Executor Tests")
struct GPGProcessExecutorTests {

    @Test("Cancellation terminates subprocess without leaving residue")
    func cancellation_terminatesSubprocess() async throws {
        let executor = GPGProcessExecutor()
        let pidRecorder = PIDRecorder()

        let task = Task {
            try await executor.execute(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"],
                environment: [:],
                gpgHome: nil,
                input: nil,
                timeout: 60,
                onLaunch: { pid in
                    pidRecorder.set(pid)
                }
            )
        }

        let pid = try await waitForPID(pidRecorder, timeout: 3)
        #expect(processExists(pid) == true)

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation error")
        } catch let error as GPGError {
            switch error {
            case .operationCancelled:
                break
            default:
                Issue.record("Unexpected GPGError: \(error)")
            }
        } catch is CancellationError {
            // Accept cancellation propagated before mapping.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let terminated = try await waitForProcessExit(pid, timeout: 3)
        #expect(terminated == true)
    }

    @Test("Timeout terminates subprocess without leaving residue")
    func timeout_terminatesSubprocess() async throws {
        let executor = GPGProcessExecutor()
        let pidRecorder = PIDRecorder()

        let task = Task {
            try await executor.execute(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"],
                environment: [:],
                gpgHome: nil,
                input: nil,
                timeout: 0.5,
                onLaunch: { pid in
                    pidRecorder.set(pid)
                }
            )
        }

        let pid = try await waitForPID(pidRecorder, timeout: 3)
        #expect(processExists(pid) == true)

        do {
            _ = try await task.value
            Issue.record("Expected timeout error")
        } catch let error as GPGError {
            switch error {
            case .executionFailed:
                break
            default:
                Issue.record("Unexpected GPGError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let terminated = try await waitForProcessExit(pid, timeout: 3)
        #expect(terminated == true)
    }

    @Test("Executor returns when parent exits even if grandchild keeps stdout open")
    func parentExit_withGrandchildHoldingStdout_doesNotHang() async throws {
        let executor = GPGProcessExecutor()
        let pidRecorder = PIDRecorder()

        let script = "sleep 5 & printf 'done\\n'"

        let result = try await executor.execute(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script],
            environment: [:],
            gpgHome: nil,
            input: nil,
            timeout: 5,
            onLaunch: { pid in
                pidRecorder.set(pid)
            }
        )

        #expect(result.exitCode == 0)
        #expect((result.stdout ?? "").contains("done"))

        if let pid = pidRecorder.pid, pid > 0 {
            let terminated = try await waitForProcessExit(pid, timeout: 2)
            #expect(terminated == true)
        } else {
            Issue.record("Expected launched PID to be recorded")
        }
    }

    private func waitForPID(_ recorder: PIDRecorder, timeout: TimeInterval) async throws -> Int32 {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let pid = recorder.pid, pid > 0 {
                return pid
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(
            domain: "GPGProcessExecutorTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for launched PID"]
        )
    }

    private func waitForProcessExit(_ pid: Int32, timeout: TimeInterval) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !processExists(pid) {
                return true
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return !processExists(pid)
    }

    private func processExists(_ pid: Int32) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno != ESRCH
    }
}

private final class PIDRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _pid: Int32?

    var pid: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return _pid
    }

    func set(_ pid: Int32) {
        lock.lock()
        _pid = pid
        lock.unlock()
    }
}
