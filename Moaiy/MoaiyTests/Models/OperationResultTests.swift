//
//  OperationResultTests.swift
//  MoaiyTests
//
//  Unit tests for operation result message rendering.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("OperationResult Tests")
struct OperationResultTests {

    @Test("Success encrypt resolves localized message key")
    func successEncrypt_resolvesLocalizedMessageKey() {
        let result = OperationResult.successEncrypt(fileURL: URL(fileURLWithPath: "/tmp/demo.txt"))

        #expect(result.isLocalizedMessageKey == true)
        #expect(result.message == "operation_success_encrypt")
        #expect(result.displayMessage == NSLocalizedString("operation_success_encrypt", comment: ""))
    }

    @Test("Failure keeps raw error message")
    func failure_keepsRawErrorMessage() {
        let errorMessage = "Raw decryption failure"
        let result = OperationResult.failure(
            fileURL: URL(fileURLWithPath: "/tmp/demo.gpg"),
            operation: .decrypt,
            errorMessage: errorMessage
        )

        #expect(result.isLocalizedMessageKey == false)
        #expect(result.displayMessage == errorMessage)
    }

    @Test("Batch summary uses encrypt success title for encrypt-only success results")
    func batchSummary_encryptOnlySuccess_usesEncryptSuccessTitle() {
        let results = [
            OperationResult.successEncrypt(fileURL: URL(fileURLWithPath: "/tmp/a.txt")),
            OperationResult.successEncrypt(fileURL: URL(fileURLWithPath: "/tmp/b.txt"))
        ]
        let summary = BatchOperationSummary(results: results)

        #expect(summary.headerTitleKey() == "operation_encrypt_all_succeeded")
    }

    @Test("Batch summary uses decrypt success title for decrypt-only success results")
    func batchSummary_decryptOnlySuccess_usesDecryptSuccessTitle() {
        let results = [
            OperationResult.successDecrypt(fileURL: URL(fileURLWithPath: "/tmp/a.gpg")),
            OperationResult.successDecrypt(fileURL: URL(fileURLWithPath: "/tmp/b.gpg"))
        ]
        let summary = BatchOperationSummary(results: results)

        #expect(summary.headerTitleKey() == "operation_decrypt_all_succeeded")
    }

    @Test("Batch summary uses encrypt partial title for mixed encrypt success and failure")
    func batchSummary_encryptPartial_usesEncryptPartialTitle() {
        let results = [
            OperationResult.successEncrypt(fileURL: URL(fileURLWithPath: "/tmp/a.txt")),
            OperationResult.failure(
                fileURL: URL(fileURLWithPath: "/tmp/b.txt"),
                operation: .encrypt,
                errorMessage: "Permission denied"
            )
        ]
        let summary = BatchOperationSummary(results: results)

        #expect(summary.headerTitleKey() == "operation_encrypt_partial_success")
    }

    @Test("Batch summary uses decrypt failure title for decrypt-only failure results")
    func batchSummary_decryptOnlyFailure_usesDecryptFailureTitle() {
        let results = [
            OperationResult.failure(
                fileURL: URL(fileURLWithPath: "/tmp/a.gpg"),
                operation: .decrypt,
                errorMessage: "Bad passphrase"
            ),
            OperationResult.failure(
                fileURL: URL(fileURLWithPath: "/tmp/b.gpg"),
                operation: .decrypt,
                errorMessage: "No secret key"
            )
        ]
        let summary = BatchOperationSummary(results: results)

        #expect(summary.headerTitleKey() == "operation_decrypt_all_failed")
    }

    @Test("Batch summary falls back to generic title when operations are mixed")
    func batchSummary_mixedOperations_usesGenericTitle() {
        let results = [
            OperationResult.successEncrypt(fileURL: URL(fileURLWithPath: "/tmp/a.txt")),
            OperationResult.successDecrypt(fileURL: URL(fileURLWithPath: "/tmp/b.gpg"))
        ]
        let summary = BatchOperationSummary(results: results)

        #expect(summary.headerTitleKey() == "operation_all_succeeded")
    }

    @Test("Batch summary uses preferred operation when explicitly provided")
    func batchSummary_preferredOperation_usesPreferredTitle() {
        let results = [
            OperationResult.successEncrypt(fileURL: URL(fileURLWithPath: "/tmp/a.txt")),
            OperationResult.successDecrypt(fileURL: URL(fileURLWithPath: "/tmp/b.gpg"))
        ]
        let summary = BatchOperationSummary(results: results)

        #expect(summary.headerTitleKey(preferredOperation: .encrypt) == "operation_encrypt_all_succeeded")
    }
}
