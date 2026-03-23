//
//  TrustLevelTests.swift
//  MoaiyTests
//
//  Unit tests for TrustLevel enum
//

import Foundation
import Testing
@testable import Moaiy

@Suite("TrustLevel Tests")
struct TrustLevelTests {
    
    // MARK: - GPG Code Mapping Tests
    
    @Test("gpgCode returns correct code for unknown")
    func gpgCode_unknown_returnsCorrectCode() {
        #expect(TrustLevel.unknown.gpgCode == "-")
    }
    
    @Test("gpgCode returns correct code for none")
    func gpgCode_none_returnsCorrectCode() {
        #expect(TrustLevel.none.gpgCode == "n")
    }
    
    @Test("gpgCode returns correct code for marginal")
    func gpgCode_marginal_returnsCorrectCode() {
        #expect(TrustLevel.marginal.gpgCode == "m")
    }
    
    @Test("gpgCode returns correct code for full")
    func gpgCode_full_returnsCorrectCode() {
        #expect(TrustLevel.full.gpgCode == "f")
    }
    
    @Test("gpgCode returns correct code for ultimate")
    func gpgCode_ultimate_returnsCorrectCode() {
        #expect(TrustLevel.ultimate.gpgCode == "u")
    }
    
    // MARK: - Init from GPG Code Tests
    
    @Test("init from gpgCode '-' returns unknown")
    func initFromGPGCode_dash_returnsUnknown() {
        #expect(TrustLevel(gpgCode: "-") == .unknown)
    }
    
    @Test("init from gpgCode '' returns unknown")
    func initFromGPGCode_empty_returnsUnknown() {
        #expect(TrustLevel(gpgCode: "") == .unknown)
    }
    
    @Test("init from gpgCode 'n' returns none")
    func initFromGPGCode_n_returnsNone() {
        #expect(TrustLevel(gpgCode: "n") == TrustLevel.none)
    }
    
    @Test("init from gpgCode 'm' returns marginal")
    func initFromGPGCode_m_returnsMarginal() {
        #expect(TrustLevel(gpgCode: "m") == .marginal)
    }
    
    @Test("init from gpgCode 'f' returns full")
    func initFromGPGCode_f_returnsFull() {
        #expect(TrustLevel(gpgCode: "f") == .full)
    }
    
    @Test("init from gpgCode 'u' returns ultimate")
    func initFromGPGCode_u_returnsUltimate() {
        #expect(TrustLevel(gpgCode: "u") == .ultimate)
    }
    
    @Test("init from invalid gpgCode returns nil")
    func initFromGPGCode_invalid_returnsNil() {
        #expect(TrustLevel(gpgCode: "x") == nil)
        #expect(TrustLevel(gpgCode: "invalid") == nil)
        #expect(TrustLevel(gpgCode: "1") == nil)
    }
    
    // MARK: - Display Name Tests
    
    @Test("displayName returns non-empty string for all levels")
    func displayName_returnsNonEmptyForAll() {
        for level in TrustLevel.allTestCases {
            #expect(!level.displayName.isEmpty)
        }
    }
    
    @Test("displayName returns expected values")
    func displayName_returnsExpectedValues() {
        #expect(TrustLevel.unknown.displayName == "Unknown")
        #expect(TrustLevel.none.displayName == "None")
        #expect(TrustLevel.marginal.displayName == "Marginal")
        #expect(TrustLevel.full.displayName == "Full")
        #expect(TrustLevel.ultimate.displayName == "Ultimate")
    }
    
    // MARK: - Localized Name Tests
    
    @Test("localizedName returns non-empty string for all levels")
    func localizedName_returnsNonEmptyForAll() {
        for level in TrustLevel.allTestCases {
            #expect(!level.localizedName.isEmpty)
        }
    }
    
    // MARK: - Localized Description Tests
    
    @Test("localizedDescription returns non-empty string for all levels")
    func localizedDescription_returnsNonEmptyForAll() {
        for level in TrustLevel.allTestCases {
            #expect(!level.localizedDescription.isEmpty)
        }
    }
    
    // MARK: - Round-trip Tests
    
    @Test("Round-trip gpgCode conversion preserves value")
    func roundTrip_gpgCode_preservesValue() {
        let mappings: [(TrustLevel, String)] = [
            (.unknown, "-"),
            (.none, "n"),
            (.marginal, "m"),
            (.full, "f"),
            (.ultimate, "u")
        ]
        
        for (level, code) in mappings {
            #expect(level.gpgCode == code)
            #expect(TrustLevel(gpgCode: code) == level)
        }
    }
    
    // MARK: - Identifiable Tests
    
    @Test("id uses rawValue")
    func id_usesRawValue() {
        #expect(TrustLevel.unknown.id == "unknown")
        #expect(TrustLevel.none.id == "none")
        #expect(TrustLevel.marginal.id == "marginal")
        #expect(TrustLevel.full.id == "full")
        #expect(TrustLevel.ultimate.id == "ultimate")
    }
    
    // MARK: - CaseIterable Tests
    
    @Test("allCases contains all trust levels")
    func allCases_containsAllLevels() {
        let allCases = TrustLevel.allCases
        
        #expect(allCases.contains(.unknown))
        #expect(allCases.contains(.none))
        #expect(allCases.contains(.marginal))
        #expect(allCases.contains(.full))
        #expect(allCases.contains(.ultimate))
        #expect(allCases.count == 5)
    }
}
