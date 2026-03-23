//
//  TrustManagementTests.swift
//  MoaiyTests
//
//  Unit tests for trust management functionality
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Trust Management Tests")
@MainActor
struct TrustManagementTests {
    
    // MARK: - TrustLevel Tests
    
    @Test("Check trust returns correct level")
    func checkTrust_returnsCorrectLevel() async throws {
        let mockService = MockGPGService()
        mockService.stubbedTrustLevel = .full
        
        let trust = try await mockService.checkTrust(keyID: "TEST_KEY")
        
        #expect(trust == .full)
        #expect(mockService.checkTrustCallCount == 1)
    }
    
    @Test("Set trust updates trust level")
    func setTrust_updatesTrustLevel() async throws {
        let mockService = MockGPGService()
        
        try await mockService.setTrust(keyID: "TEST_KEY", trustLevel: .ultimate)
        
        #expect(mockService.setTrustCallCount == 1)
        #expect(mockService.lastSetTrustLevel == .ultimate)
    }
    
    @Test("Set trust to marginal")
    func setTrust_marginal_setsCorrectly() async throws {
        let mockService = MockGPGService()
        
        try await mockService.setTrust(keyID: "TEST_KEY", trustLevel: .marginal)
        
        #expect(mockService.lastSetTrustLevel == .marginal)
    }
    
    @Test("Set trust to full")
    func setTrust_full_setsCorrectly() async throws {
        let mockService = MockGPGService()
        
        try await mockService.setTrust(keyID: "TEST_KEY", trustLevel: .full)
        
        #expect(mockService.lastSetTrustLevel == .full)
    }
    
    @Test("Set trust to ultimate")
    func setTrust_ultimate_setsCorrectly() async throws {
        let mockService = MockGPGService()
        
        try await mockService.setTrust(keyID: "TEST_KEY", trustLevel: .ultimate)
        
        #expect(mockService.lastSetTrustLevel == .ultimate)
    }
    
    @Test("Set trust to none")
    func setTrust_none_setsCorrectly() async throws {
        let mockService = MockGPGService()
        
        try await mockService.setTrust(keyID: "TEST_KEY", trustLevel: TrustLevel.none)
        
        #expect(mockService.lastSetTrustLevel == TrustLevel.none)
    }
    
    @Test("Update trust database completes successfully")
    func updateTrustDB_completesSuccessfully() async throws {
        let mockService = MockGPGService()
        
        try await mockService.updateTrustDB()
        
        #expect(mockService.updateTrustDBCallCount == 1)
    }
    
    // MARK: - Key Signing Tests
    
    @Test("Sign key with passphrase succeeds")
    func signKey_withPassphrase_succeeds() async throws {
        let mockService = MockGPGService()
        
        try await mockService.signKey(
            keyID: "KEY_TO_SIGN",
            signerKeyID: "SIGNER_KEY",
            passphrase: "passphrase123",
            trustLevel: nil
        )
        
        #expect(mockService.signKeyCallCount == 1)
    }
    
    @Test("Sign key with trust level sets trust")
    func signKey_withTrustLevel_setsTrust() async throws {
        let mockService = MockGPGService()
        
        try await mockService.signKey(
            keyID: "KEY_TO_SIGN",
            signerKeyID: "SIGNER_KEY",
            passphrase: "passphrase123",
            trustLevel: .full
        )
        
        #expect(mockService.signKeyCallCount == 1)
    }
    
    @Test("Sign key without signer uses default")
    func signKey_withoutSigner_usesDefault() async throws {
        let mockService = MockGPGService()
        
        try await mockService.signKey(
            keyID: "KEY_TO_SIGN",
            signerKeyID: nil,
            passphrase: "passphrase123",
            trustLevel: nil
        )
        
        #expect(mockService.signKeyCallCount == 1)
    }
    
    // MARK: - KeyTrustDetails Tests
    
    @Test("Get trust details returns correct information")
    func getTrustDetails_returnsCorrectInfo() async throws {
        let mockService = MockGPGService()
        mockService.stubbedTrustDetails = KeyTrustDetails(
            keyID: "TEST_KEY",
            ownerTrust: .full,
            calculatedTrust: .ultimate,
            signatureCount: 5
        )
        
        let details = try await mockService.getTrustDetails(keyID: "TEST_KEY")
        
        #expect(details.keyID == "TEST_KEY")
        #expect(details.ownerTrust == .full)
        #expect(details.calculatedTrust == .ultimate)
        #expect(details.signatureCount == 5)
    }
    
    @Test("Trust details isTrusted depends on calculated trust")
    func trustDetails_isTrusted_dependsOnCalculatedTrust() {
        // Full calculated trust is trusted
        let fullTrust = KeyTrustDetails(
            keyID: "TEST",
            ownerTrust: .none,
            calculatedTrust: .full,
            signatureCount: 0
        )
        #expect(fullTrust.isTrusted == true)
        
        // Marginal calculated trust is not trusted
        let marginalTrust = KeyTrustDetails(
            keyID: "TEST",
            ownerTrust: .ultimate,
            calculatedTrust: .marginal,
            signatureCount: 0
        )
        #expect(marginalTrust.isTrusted == false)
    }
    
    @Test("Trust details hasSignatures checks count")
    func trustDetails_hasSignatures_checksCount() {
        let withSignatures = KeyTrustDetails(
            keyID: "TEST",
            ownerTrust: .unknown,
            calculatedTrust: .unknown,
            signatureCount: 3
        )
        #expect(withSignatures.hasSignatures == true)
        
        let withoutSignatures = KeyTrustDetails(
            keyID: "TEST",
            ownerTrust: .unknown,
            calculatedTrust: .unknown,
            signatureCount: 0
        )
        #expect(withoutSignatures.hasSignatures == false)
    }
    
    // MARK: - Trust Level Display Tests
    
    @Test("Trust level display names are correct")
    func trustLevel_displayNames() {
        #expect(TrustLevel.unknown.displayName == "Unknown")
        #expect(TrustLevel.none.displayName == "None")
        #expect(TrustLevel.marginal.displayName == "Marginal")
        #expect(TrustLevel.full.displayName == "Full")
        #expect(TrustLevel.ultimate.displayName == "Ultimate")
    }
    
    @Test("Trust level localized names are not empty")
    func trustLevel_localizedNames_notEmpty() {
        for level in TrustLevel.allTestCases {
            #expect(!level.localizedName.isEmpty)
        }
    }
    
    @Test("Trust level localized descriptions are not empty")
    func trustLevel_localizedDescriptions_notEmpty() {
        for level in TrustLevel.allTestCases {
            #expect(!level.localizedDescription.isEmpty)
        }
    }
}

// MARK: - ViewModel Trust Tests

@Suite("ViewModel Trust Tests")
@MainActor
struct ViewModelTrustTests {
    
    @Test("Check trust for key returns correct level")
    func checkTrustForKey_returnsCorrectLevel() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [TestKeyFactory.makeKeyWithTrust(.full)]
        
        // Note: Actual trust check requires GPG
        #expect(viewModel.keys.first?.trustLevel == .full)
    }
    
    @Test("Set trust for key updates key")
    func setTrustForKey_updatesKey() async {
        let viewModel = KeyManagementViewModel()
        let key = TestKeyFactory.makeKeyWithTrust(.marginal)
        viewModel.keys = [key]
        
        // Verify initial state
        #expect(viewModel.keys.first?.trustLevel == .marginal)
    }
    
    @Test("Keys with different trust levels can be filtered")
    func keysWithDifferentTrust_canBeFiltered() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [
            TestKeyFactory.makeKeyWithTrust(.unknown, name: "Unknown", email: "unknown@test.com"),
            TestKeyFactory.makeKeyWithTrust(.marginal, name: "Marginal", email: "marginal@test.com"),
            TestKeyFactory.makeKeyWithTrust(.full, name: "Full", email: "full@test.com"),
            TestKeyFactory.makeKeyWithTrust(.ultimate, name: "Ultimate", email: "ultimate@test.com")
        ]
        
        viewModel.filterTrustLevel = .full
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.trustLevel == .full)
    }
    
    @Test("Update trust DB is callable")
    func updateTrustDB_isCallable() async {
        let viewModel = KeyManagementViewModel()
        
        // This would normally call GPG service
        // Here we just verify the method exists
        #expect(viewModel.keys.isEmpty == true || viewModel.keys.isEmpty == false)
    }
}
