import Foundation
import Testing
@testable import Moaiy

@Suite("Batch Governance Sheet Models Tests")
struct BatchGovernanceSheetTests {
    @Test("Execution request metadata maps operation and targets")
    func executionRequest_metadataMapsExpectedKeys() {
        let request = BatchGovernanceExecutionRequest(
            operation: .ownerTrust,
            targets: ["A", "B"],
            ownerTrust: .full,
            revocationReason: .noLongerUsed,
            revocationDescription: "note",
            passphrase: nil
        )

        #expect(request.metadata["batch.operation"] == "ownerTrust")
        #expect(request.metadata["batch.targets"] == "A\nB")
        #expect(request.metadata["batch.ownerTrust"] == "full")
        #expect(request.metadata["batch.revocationReason"] == "noLongerUsed")
        #expect(request.metadata["batch.revocationDescription"] == "note")
        #expect(request.metadata["batch.passphrase"] == "")
    }

    @Test("Execution receipt parses count metadata")
    func executionReceipt_parsesCountMetadata() {
        let receipt = BatchGovernanceExecutionReceipt(
            titleKey: "pro_batch_governance_title",
            messageKey: "pro_batch_governance_partial_failure_message",
            metadata: [
                "batch.receipt.total": "8",
                "batch.receipt.succeeded": "5",
                "batch.receipt.failed": "3",
                "batch.receipt.artifacts": "2",
                "batch.receipt.outputDirectory": "/tmp/moaiy-batch"
            ]
        )

        #expect(receipt.totalTargets == 8)
        #expect(receipt.succeededTargets == 5)
        #expect(receipt.failedTargets == 3)
        #expect(receipt.artifactCount == 2)
        #expect(receipt.outputDirectoryPath == "/tmp/moaiy-batch")
    }

    @Test("Audit export request metadata maps selected filters")
    func auditExportRequest_metadataMapsExpectedKeys() {
        let dateFrom = Date(timeIntervalSince1970: 1_705_000_000)
        let dateTo = Date(timeIntervalSince1970: 1_706_000_000)
        let request = AuditExportExecutionRequest(
            format: .csv,
            redaction: .strict,
            targets: ["FPR1", "FPR2"],
            operations: [.governance, .trust],
            includeSuccess: true,
            includeFailure: false,
            dateFrom: dateFrom,
            dateTo: dateTo
        )

        #expect(request.metadata["audit.format"] == "csv")
        #expect(request.metadata["audit.redaction"] == "strict")
        #expect(request.metadata["audit.targets"] == "FPR1\nFPR2")
        #expect(request.metadata["audit.operations"]?.contains("governance") == true)
        #expect(request.metadata["audit.operations"]?.contains("trust") == true)
        #expect(request.metadata["audit.includeSuccess"] == "true")
        #expect(request.metadata["audit.includeFailure"] == "false")
        #expect(request.metadata["audit.dateFrom"]?.isEmpty == false)
        #expect(request.metadata["audit.dateTo"]?.isEmpty == false)
    }

    @Test("Audit export receipt parses summary metadata")
    func auditExportReceipt_parsesSummaryMetadata() {
        let receipt = AuditExportExecutionReceipt(
            titleKey: "pro_audit_export_title",
            messageKey: "pro_audit_export_success_message",
            metadata: [
                "audit.receipt.total": "32",
                "audit.receipt.redacted": "20",
                "audit.receipt.format": "json",
                "audit.receipt.outputPath": "/tmp/moaiy-audit/export.json"
            ]
        )

        #expect(receipt.totalRecords == 32)
        #expect(receipt.redactedRecords == 20)
        #expect(receipt.formatRawValue == "json")
        #expect(receipt.outputPath == "/tmp/moaiy-audit/export.json")
    }
}
