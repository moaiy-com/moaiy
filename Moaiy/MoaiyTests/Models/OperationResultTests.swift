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
}
