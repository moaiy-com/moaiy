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
            backupFileName: "moaiy-backup.zip",
            keyCount: 6,
            includeSecretKeys: true,
            exportedPublicKeyCount: 6,
            exportedSecretKeyCount: 2,
            failedSecretKeyCount: 1
        )

        #expect(record.backupFileName == "moaiy-backup.zip")
        #expect(record.exportedPublicKeyCount == 6)
        #expect(record.exportedSecretKeyCount == 2)
        #expect(record.failedSecretKeyCount == 1)
    }

    @Test("Backup record decodes legacy location field into file name")
    func backupRecord_decodesLegacyLocation() throws {
        let legacyJSON = """
        {
          "id": "\(UUID().uuidString)",
          "date": 1700000000,
          "location": "file:///tmp/legacy-backup.zip",
          "keyCount": 4,
          "includeSecretKeys": true
        }
        """

        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BackupRecord.self, from: data)

        #expect(decoded.backupFileName == "legacy-backup.zip")
    }
}
