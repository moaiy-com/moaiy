//
//  BackupExportSummaryTests.swift
//  MoaiyTests
//
//  Unit tests for backup export statistics.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Backup Export Summary Tests")
struct BackupExportSummaryTests {

    @Test("Failed secret export count matches failed fingerprint list")
    func failedSecretExportCount_matchesFailedFingerprintList() {
        let summary = BackupExportSummary(
            exportedPublicKeyCount: 3,
            requestedSecretKeyCount: 2,
            exportedSecretKeyCount: 0,
            failedSecretKeyFingerprints: ["A1", "B2"],
            firstSecretKeyExportError: "Bad passphrase"
        )

        #expect(summary.failedSecretKeyCount == 2)
        #expect(summary.hasSecretExportFailures == true)
        #expect(summary.isSecretExportComplete == false)
    }

    @Test("Secret export summary reports complete when all secrets exported")
    func secretExportSummary_reportsCompleteWhenAllSecretsExported() {
        let summary = BackupExportSummary(
            exportedPublicKeyCount: 4,
            requestedSecretKeyCount: 2,
            exportedSecretKeyCount: 2,
            failedSecretKeyFingerprints: [],
            firstSecretKeyExportError: nil
        )

        #expect(summary.failedSecretKeyCount == 0)
        #expect(summary.hasSecretExportFailures == false)
        #expect(summary.isSecretExportComplete == true)
    }

    @Test("Backup record persists export statistics for history display")
    func backupRecord_persistsExportStatistics() {
        let record = BackupRecord(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            location: URL(fileURLWithPath: "/tmp/moaiy-backup.zip"),
            keyCount: 6,
            includeSecretKeys: true,
            exportedPublicKeyCount: 6,
            exportedSecretKeyCount: 2,
            failedSecretKeyCount: 1
        )

        #expect(record.exportedPublicKeyCount == 6)
        #expect(record.exportedSecretKeyCount == 2)
        #expect(record.failedSecretKeyCount == 1)
    }
}
