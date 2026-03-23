//
//  KeyTypeTests.swift
//  MoaiyTests
//
//  Unit tests for KeyType enum
//

import Foundation
import Testing
@testable import Moaiy

@Suite("KeyType Tests")
struct KeyTypeTests {
    
    // MARK: - RSA-4096 Tests
    
    @Test("RSA-4096 returns correct key length")
    func rsa4096_keyLength() {
        #expect(KeyType.rsa4096.keyLength == 4096)
    }
    
    @Test("RSA-4096 returns correct subkey length")
    func rsa4096_subkeyLength() {
        #expect(KeyType.rsa4096.subkeyLength == 4096)
    }
    
    @Test("RSA-4096 returns correct GPG key type")
    func rsa4096_gpgKeyType() {
        #expect(KeyType.rsa4096.gpgKeyType == "RSA")
    }
    
    @Test("RSA-4096 returns correct GPG subkey type")
    func rsa4096_gpgSubkeyType() {
        #expect(KeyType.rsa4096.gpgSubkeyType == "RSA")
    }
    
    @Test("RSA-4096 has no curve")
    func rsa4096_curve() {
        #expect(KeyType.rsa4096.curve == nil)
    }
    
    // MARK: - RSA-2048 Tests
    
    @Test("RSA-2048 returns correct key length")
    func rsa2048_keyLength() {
        #expect(KeyType.rsa2048.keyLength == 2048)
    }
    
    @Test("RSA-2048 returns correct subkey length")
    func rsa2048_subkeyLength() {
        #expect(KeyType.rsa2048.subkeyLength == 2048)
    }
    
    @Test("RSA-2048 returns correct GPG key type")
    func rsa2048_gpgKeyType() {
        #expect(KeyType.rsa2048.gpgKeyType == "RSA")
    }
    
    @Test("RSA-2048 returns correct GPG subkey type")
    func rsa2048_gpgSubkeyType() {
        #expect(KeyType.rsa2048.gpgSubkeyType == "RSA")
    }
    
    @Test("RSA-2048 has no curve")
    func rsa2048_curve() {
        #expect(KeyType.rsa2048.curve == nil)
    }
    
    // MARK: - ECC Tests
    
    @Test("ECC returns zero key length (uses curve)")
    func ecc_keyLength() {
        #expect(KeyType.ecc.keyLength == 0)
    }
    
    @Test("ECC returns zero subkey length (uses curve)")
    func ecc_subkeyLength() {
        #expect(KeyType.ecc.subkeyLength == 0)
    }
    
    @Test("ECC returns correct GPG key type")
    func ecc_gpgKeyType() {
        #expect(KeyType.ecc.gpgKeyType == "EDDSA")
    }
    
    @Test("ECC returns correct GPG subkey type")
    func ecc_gpgSubkeyType() {
        #expect(KeyType.ecc.gpgSubkeyType == "ECDH")
    }
    
    @Test("ECC returns correct curve")
    func ecc_curve() {
        #expect(KeyType.ecc.curve == "cv25519")
    }
    
    // MARK: - Raw Value Tests
    
    @Test("rawValue returns correct values")
    func rawValue_returnsCorrectValues() {
        #expect(KeyType.rsa4096.rawValue == "RSA-4096")
        #expect(KeyType.rsa2048.rawValue == "RSA-2048")
        #expect(KeyType.ecc.rawValue == "ECC")
    }
    
    // MARK: - Identifiable Tests
    
    @Test("id uses rawValue")
    func id_usesRawValue() {
        #expect(KeyType.rsa4096.id == "RSA-4096")
        #expect(KeyType.rsa2048.id == "RSA-2048")
        #expect(KeyType.ecc.id == "ECC")
    }
    
    // MARK: - CaseIterable Tests
    
    @Test("allCases contains all key types")
    func allCases_containsAllTypes() {
        let allCases = KeyType.allCases
        
        #expect(allCases.contains(.rsa2048))
        #expect(allCases.contains(.rsa4096))
        #expect(allCases.contains(.ecc))
        #expect(allCases.count == 3)
    }
    
    // MARK: - Comparison Tests
    
    @Test("RSA-4096 has larger key length than RSA-2048")
    func rsa4096_largerThan_rsa2048() {
        #expect(KeyType.rsa4096.keyLength > KeyType.rsa2048.keyLength)
    }
}
