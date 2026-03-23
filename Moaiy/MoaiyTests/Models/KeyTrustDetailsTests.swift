//
//  KeyTrustDetailsTests.swift
//  MoaiyTests
//
//  Unit tests for KeyTrustDetails model
//

import Foundation
import Testing
@testable import Moaiy

@Suite("KeyTrustDetails Tests")
struct KeyTrustDetailsTests {
    
    // MARK: - Is Trusted Tests
    
    @Test("isTrusted with full calculated trust returns true")
    func isTrusted_fullCalculated_returnsTrue() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .marginal,
            calculatedTrust: .full,
            signatureCount: 0
        )
        
        #expect(details.isTrusted == true)
    }
    
    @Test("isTrusted with ultimate calculated trust returns true")
    func isTrusted_ultimateCalculated_returnsTrue() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .none,
            calculatedTrust: .ultimate,
            signatureCount: 0
        )
        
        #expect(details.isTrusted == true)
    }
    
    @Test("isTrusted with marginal calculated trust returns false")
    func isTrusted_marginalCalculated_returnsFalse() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .full,
            calculatedTrust: .marginal,
            signatureCount: 0
        )
        
        #expect(details.isTrusted == false)
    }
    
    @Test("isTrusted with unknown calculated trust returns false")
    func isTrusted_unknownCalculated_returnsFalse() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .ultimate,
            calculatedTrust: .unknown,
            signatureCount: 0
        )
        
        #expect(details.isTrusted == false)
    }
    
    @Test("isTrusted with none calculated trust returns false")
    func isTrusted_noneCalculated_returnsFalse() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .full,
            calculatedTrust: .none,
            signatureCount: 0
        )
        
        #expect(details.isTrusted == false)
    }
    
    // MARK: - Has Signatures Tests
    
    @Test("hasSignatures with positive count returns true")
    func hasSignatures_positiveCount_returnsTrue() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .unknown,
            calculatedTrust: .unknown,
            signatureCount: 1
        )
        
        #expect(details.hasSignatures == true)
    }
    
    @Test("hasSignatures with zero count returns false")
    func hasSignatures_zeroCount_returnsFalse() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .unknown,
            calculatedTrust: .unknown,
            signatureCount: 0
        )
        
        #expect(details.hasSignatures == false)
    }
    
    @Test("hasSignatures with large count returns true")
    func hasSignatures_largeCount_returnsTrue() {
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .unknown,
            calculatedTrust: .unknown,
            signatureCount: 100
        )
        
        #expect(details.hasSignatures == true)
    }
    
    // MARK: - Property Storage Tests
    
    @Test("All properties are correctly stored")
    func allProperties_correctlyStored() {
        let details = KeyTrustDetails(
            keyID: "ABC123",
            ownerTrust: .full,
            calculatedTrust: .marginal,
            signatureCount: 5
        )
        
        #expect(details.keyID == "ABC123")
        #expect(details.ownerTrust == .full)
        #expect(details.calculatedTrust == .marginal)
        #expect(details.signatureCount == 5)
    }
    
    // MARK: - Trust Independence Tests
    
    @Test("isTrusted depends on calculatedTrust not ownerTrust")
    func isTrusted_dependsOnCalculatedTrust() {
        // Owner trust is ultimate but calculated is marginal
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .ultimate,
            calculatedTrust: .marginal,
            signatureCount: 0
        )
        
        // Should be false because calculated trust is marginal
        #expect(details.isTrusted == false)
    }
    
    @Test("isTrusted ignores ownerTrust when calculated is full")
    func isTrusted_ignoresOwnerTrustWhenCalculatedFull() {
        // Owner trust is none but calculated is full
        let details = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .none,
            calculatedTrust: .full,
            signatureCount: 0
        )
        
        // Should be true because calculated trust is full
        #expect(details.isTrusted == true)
    }
}
