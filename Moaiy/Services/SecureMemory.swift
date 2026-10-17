//
//  SecureMemory.swift
//  Moaiy
//
//  Cryptographic memory zeroization utilities (best-effort).
//  Provides internal byte buffer clearing via POSIX memset_s to reduce
//  passphrase memory residency duration.
//

import Foundation
import Darwin

/// A container for sensitive byte buffers that attempts to clear its internal memory using `memset_s` on deallocation.
/// Note: This provides best-effort clearing of its own internal buffer. Any prior Swift String/Data allocations
/// from which this buffer was initialized may still linger in heap/autorelease pools outside this class's control.
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

    /// Best-effort zeroizes the internal buffer using POSIX memset_s to reduce memory residency.
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

    /// Access the underlying bytes within an isolated closure without extra copies
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

    /// Returns a copy of Data. Warning: The returned Data allocation is managed by Foundation and is not zeroized.
    public func copyData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return Data(buffer)
    }

    /// Returns true if the internal buffer has been zeroized
    public var isCleaned: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isZeroized
    }
}

/// A wrapper for sensitive strings that clears its internal representation when dismissed.
/// Note: Calling `revealString()` creates an immutable Swift String in autoreleased memory that cannot be zeroized.
public final class SecureString: @unchecked Sendable {
    private let secureBytes: SecureBytes

    public init(_ string: String) {
        self.secureBytes = SecureBytes(utf8String: string)
    }

    public func withUnsafeUTF8<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try secureBytes.withUnsafeBytes(body)
    }

    /// Warning: Exposing as Swift String creates an immutable heap copy that cannot be zeroized.
    /// Prefer `withUnsafeUTF8` whenever possible.
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
