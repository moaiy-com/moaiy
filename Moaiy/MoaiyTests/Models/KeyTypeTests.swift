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

    // MARK: - Post-Quantum Hybrid Tests

    @Test("Post-Quantum Hybrid uses quick generation")
    func postQuantumHybrid_generationMode() {
        #expect(KeyType.postQuantumHybrid.generationMode == .quick)
    }

    @Test("Post-Quantum Hybrid returns expected metadata")
    func postQuantumHybrid_metadata() {
        let keyType = KeyType.postQuantumHybrid

        #expect(keyType.keyLength == 0)
        #expect(keyType.subkeyLength == 768)
        #expect(keyType.gpgKeyType == "pqc")
        #expect(keyType.gpgSubkeyType == "default")
        #expect(keyType.curve == nil)
        #expect(keyType.compatibilityLevel == .experimentalInterop)
    }

    @Test("Classical key types use batch generation")
    func classicalKeyTypes_generationMode() {
        #expect(KeyType.rsa4096.generationMode == .batch)
        #expect(KeyType.rsa2048.generationMode == .batch)
        #expect(KeyType.ecc.generationMode == .batch)
    }
    
    // MARK: - Raw Value Tests
    
    @Test("rawValue returns correct values")
    func rawValue_returnsCorrectValues() {
        #expect(KeyType.rsa4096.rawValue == "RSA-4096")
        #expect(KeyType.rsa2048.rawValue == "RSA-2048")
        #expect(KeyType.ecc.rawValue == "ECC")
        #expect(KeyType.postQuantumHybrid.rawValue == "Post-Quantum Hybrid")
    }
    
    // MARK: - Identifiable Tests
    
    @Test("id uses rawValue")
    func id_usesRawValue() {
        #expect(KeyType.rsa4096.id == "RSA-4096")
        #expect(KeyType.rsa2048.id == "RSA-2048")
        #expect(KeyType.ecc.id == "ECC")
        #expect(KeyType.postQuantumHybrid.id == "Post-Quantum Hybrid")
    }
    
    // MARK: - CaseIterable Tests
    
    @Test("allCases contains all key types")
    func allCases_containsAllTypes() {
        let allCases = KeyType.allCases
        
        #expect(allCases.contains(.rsa2048))
        #expect(allCases.contains(.rsa4096))
        #expect(allCases.contains(.ecc))
        #expect(allCases.contains(.postQuantumHybrid))
        #expect(allCases.count == 4)
    }

    // MARK: - Persisted Default Key Type Tests

    @Test("Persisted default key type maps raw values")
    func persistedDefaultKeyType_mapsRawValues() {
        #expect(PersistedDefaultKeyType.rsa4096.rawValue == 0)
        #expect(PersistedDefaultKeyType.rsa2048.rawValue == 1)
        #expect(PersistedDefaultKeyType.ecc.rawValue == 2)
        #expect(PersistedDefaultKeyType.postQuantumHybrid.rawValue == 3)
        #expect(PersistedDefaultKeyType.postQuantumHybrid.keyType == .postQuantumHybrid)
    }

    @Test("Persisted default key type recovers unknown values")
    func persistedDefaultKeyType_recoversUnknownValues() {
        #expect(PersistedDefaultKeyType.resolved(rawValue: -1) == .rsa4096)
        #expect(PersistedDefaultKeyType.resolved(rawValue: 99) == .rsa4096)
        #expect(PersistedDefaultKeyType.resolved(rawValue: 3) == .postQuantumHybrid)
    }

    @Test("Persisted selectable key types gate post quantum option")
    func persistedDefaultKeyType_selectableGatesPostQuantum() {
        #expect(PersistedDefaultKeyType.selectable(supportsPostQuantum: false) == [.rsa4096, .rsa2048, .ecc])
        #expect(PersistedDefaultKeyType.selectable(supportsPostQuantum: true).contains(.postQuantumHybrid))
    }

    @Test("Display keys are stable")
    func displayKeys_areStable() {
        #expect(KeyType.rsa4096.localizedDisplayKey == "key_type_rsa4096")
        #expect(KeyType.rsa2048.localizedDisplayKey == "key_type_rsa2048")
        #expect(KeyType.ecc.localizedDisplayKey == "key_type_ecc_curve25519")
        #expect(KeyType.postQuantumHybrid.localizedDisplayKey == "key_type_post_quantum_hybrid")
    }
    
    // MARK: - Comparison Tests
    
    @Test("RSA-4096 has larger key length than RSA-2048")
    func rsa4096_largerThan_rsa2048() {
        #expect(KeyType.rsa4096.keyLength > KeyType.rsa2048.keyLength)
    }
}
