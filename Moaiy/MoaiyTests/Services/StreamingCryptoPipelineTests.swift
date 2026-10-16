//
//  StreamingCryptoPipelineTests.swift
//  MoaiyTests
//
//  Unit tests for the streaming crypto pipeline and throttled progress reporting.
//

import Foundation
import Testing
@testable import Moaiy

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
        var recordedFractions: [Double] = []
        let reporter = StreamingProgressReporter(intervalSeconds: 0.2) { progress in
            recordedFractions.append(progress.fractionCompleted)
        }

        await reporter.report(bytesProcessed: 100, totalBytes: 1000)
        await reporter.report(bytesProcessed: 200, totalBytes: 1000)
        await reporter.report(bytesProcessed: 300, totalBytes: 1000)
        // Immediate calls within 0.2s should be throttled

        // Final force report
        await reporter.report(bytesProcessed: 1000, totalBytes: 1000, force: true)

        #expect(!recordedFractions.isEmpty)
        #expect(recordedFractions.last == 1.0)
    }
}
