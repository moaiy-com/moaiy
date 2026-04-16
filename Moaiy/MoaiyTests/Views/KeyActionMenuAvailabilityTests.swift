//
//  KeyActionMenuAvailabilityTests.swift
//  MoaiyTests
//
//  Unit tests for key action menu visibility and enablement rules.
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Action Menu Availability Tests")
struct KeyActionMenuAvailabilityTests {

    @Test("Backup/Restore menu stays hidden for public key by default")
    func backupMenuHidden_forPublicKeyByDefault() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: false),
            isKeySigningMenuEnabled: false
        )

        #expect(!availability.showsBackupRestore)
    }

    @Test("Backup/Restore menu stays hidden for secret key by default")
    func backupMenuHidden_forSecretKeyByDefault() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true),
            isKeySigningMenuEnabled: false
        )

        #expect(!availability.showsBackupRestore)
    }

    @Test("Backup/Restore menu visibility follows feature flag")
    func backupMenuVisibility_followsFeatureFlag() {
        let disabledAvailability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true),
            isKeySigningMenuEnabled: false,
            isBackupRestoreMenuEnabled: false
        )
        #expect(!disabledAvailability.showsBackupRestore)

        let enabledAvailability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true),
            isKeySigningMenuEnabled: false,
            isBackupRestoreMenuEnabled: true
        )
        #expect(enabledAvailability.showsBackupRestore)
    }

    @Test("Private export hidden when key has no secret material")
    func privateExportHidden_forPublicKey() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: false),
            isKeySigningMenuEnabled: false
        )

        #expect(!availability.showsExportPrivateKey)
    }

    @Test("Private export shown when key has secret material")
    func privateExportShown_forSecretKey() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true),
            isKeySigningMenuEnabled: false
        )

        #expect(availability.showsExportPrivateKey)
    }

    @Test("Secret-only actions disabled for public key")
    func secretActionsDisabled_forPublicKey() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: false),
            isKeySigningMenuEnabled: true
        )

        #expect(!availability.canDecrypt)
        #expect(!availability.canSignDetached)
        #expect(!availability.canEdit)
        #expect(!availability.canManageSubkeys)
        #expect(!availability.canSignKey)
    }

    @Test("Subkey management enabled for local secret key")
    func subkeyManagement_enabledForLocalSecret() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true, secretMaterial: .localSecret),
            isKeySigningMenuEnabled: false
        )

        #expect(availability.canManageSubkeys)
        #expect(availability.canManageRevocation)
    }

    @Test("Key signing visibility follows feature flag")
    func keySigningVisibility_followsFeatureFlag() {
        let disabledAvailability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true),
            isKeySigningMenuEnabled: false
        )
        #expect(!disabledAvailability.showsSignKey)

        let enabledAvailability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true),
            isKeySigningMenuEnabled: true
        )
        #expect(enabledAvailability.showsSignKey)
        #expect(enabledAvailability.canSignKey)
    }

    @Test("Smart-card stub disables edit and private-export actions")
    func smartCardStub_disablesEditAndPrivateExport() {
        let availability = KeyActionMenuAvailability(
            key: makeKey(isSecret: true, secretMaterial: .smartCardStub),
            isKeySigningMenuEnabled: true
        )

        #expect(availability.canDecrypt)
        #expect(availability.canSignDetached)
        #expect(!availability.canEdit)
        #expect(!availability.canManageSubkeys)
        #expect(!availability.canManageRevocation)
        #expect(!availability.showsExportPrivateKey)
        #expect(!availability.canSignKey)
    }

    private func makeKey(isSecret: Bool, secretMaterial: SecretKeyMaterial? = nil) -> GPGKey {
        GPGKey(
            id: isSecret ? "secret-key-id" : "public-key-id",
            keyID: isSecret ? "SECRET123" : "PUBLIC123",
            fingerprint: isSecret ? "SECRET-FINGERPRINT" : "PUBLIC-FINGERPRINT",
            name: isSecret ? "Secret Key" : "Public Key",
            email: "test@moaiy.app",
            algorithm: "RSA",
            keyLength: 4096,
            isSecret: isSecret,
            createdAt: nil,
            expiresAt: nil,
            trustLevel: .unknown,
            secretMaterial: secretMaterial
        )
    }
}
