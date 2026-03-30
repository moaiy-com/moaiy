//
//  KeyActionBatchResultPlannerTests.swift
//  MoaiyTests
//
//  Unit tests for key action batch-result planning.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Action Batch Result Planner Tests")
struct KeyActionBatchResultPlannerTests {

    @Test("No processed files produces no alert decision")
    func noProcessedFiles_producesNoAlertDecision() {
        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: 0,
            failureCount: 0,
            successMessage: "ok",
            firstErrorMessage: nil
        )

        #expect(decision == .none)
    }

    @Test("All successful files produces success alert")
    func allSuccess_producesSuccessAlert() {
        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: 3,
            failureCount: 0,
            successMessage: "Encrypted",
            firstErrorMessage: nil
        )

        #expect(decision == .success("Encrypted"))
    }

    @Test("Partial failure keeps success context and first error")
    func partialFailure_keepsSuccessContextAndFirstError() {
        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: 2,
            failureCount: 1,
            successMessage: "Encrypted",
            firstErrorMessage: "Permission denied"
        )

        #expect(decision == .error("Encrypted\nPermission denied"))
    }

    @Test("All failures uses first error message directly")
    func allFailure_usesFirstErrorMessageDirectly() {
        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: 0,
            failureCount: 2,
            successMessage: "Encrypted",
            firstErrorMessage: "Bad passphrase"
        )

        #expect(decision == .error("Bad passphrase"))
    }

    @Test("Missing error falls back to localized generic error")
    func missingError_usesLocalizedFallback() {
        let decision = KeyActionBatchResultPlanner.makeAlertDecision(
            successCount: 0,
            failureCount: 1,
            successMessage: "Encrypted",
            firstErrorMessage: nil
        )

        #expect(decision == .error(String(localized: "error_occurred")))
    }
}
