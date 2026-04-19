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
}
