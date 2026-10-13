//
//  SecureMemory.swift
//  Moaiy
//
//  Cryptographic memory zeroization utilities.
//  Guarantees memory buffers containing passphrases and keys are actively
//  cleared using memset_s before deallocation.
//

import Foundation
import Darwin

/// A container for sensitive byte buffers that actively wipes memory using `memset_s` on deallocation.
public final class SecureBytes: @unchecked Sendable {
    private var buffer: [UInt8]
    private let lock = NSLock()
    private var isZeroized: Bool = false

    public init(count: Int) {
        self.buffer = [UInt8](repeating: 0, count: max(0, count))
    }

    public init(bytes: [UInt8]) {
        self.buffer = bytes
    }

    public init(data: Data) {
        self.buffer = [UInt8](data)
    }

    public init(utf8String: String) {
        self.buffer = Array(utf8String.utf8)
    }

    deinit {
        zeroize()
    }

    /// Explicitly zeroizes the underlying buffer using POSIX memset_s to avoid compiler dead-code elimination.
    public func zeroize() {
        lock.lock()
        defer { lock.unlock() }

        guard !isZeroized, !buffer.isEmpty else { return }

        buffer.withUnsafeMutableBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress, rawBuffer.count > 0 {
                memset_s(baseAddress, rsize_t(rawBuffer.count), 0, rsize_t(rawBuffer.count))
            }
        }
        buffer.removeAll(keepingCapacity: false)
        isZeroized = true
    }

    /// Access the underlying bytes within an isolated closure
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try buffer.withUnsafeBytes(body)
    }

    /// Number of bytes in the buffer
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }

    /// Returns a snapshot of Data. Note: caller is responsible for lifecycle of returned Data.
    public func copyData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return Data(buffer)
    }

    /// Returns true if the buffer has been zeroized
    public var isCleaned: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isZeroized
    }
}

/// A wrapper for sensitive strings that clears underlying UTF-8 representation when dismissed.
public final class SecureString: @unchecked Sendable {
    private let secureBytes: SecureBytes

    public init(_ string: String) {
        self.secureBytes = SecureBytes(utf8String: string)
    }

    public func withUnsafeUTF8<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try secureBytes.withUnsafeBytes(body)
    }

    public func revealString() -> String {
        secureBytes.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return "" }
            let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            return String(decoding: UnsafeBufferPointer(start: ptr, count: rawBuffer.count), as: UTF8.self)
        }
    }

    public func zeroize() {
        secureBytes.zeroize()
    }

    public var isCleaned: Bool {
        secureBytes.isCleaned
    }
}
