//
//  SmartCardDecryptPolicyTests.swift
//  MoaiyTests
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Smart card decrypt policy")
struct SmartCardDecryptPolicyTests {

    @Test("Recipient probe does not decrypt with loopback or an empty passphrase")
    func recipientProbe_doesNotRequirePIN() {
        let arguments = GPGService.encryptedRecipientProbeArguments(
            outputPath: "/tmp/out",
            sourcePath: "/tmp/in"
        )
        #expect(arguments.contains("cancel"))
        #expect(!arguments.contains("loopback"))
        #expect(!arguments.contains("--passphrase-fd"))
        #expect(!arguments.contains("--passphrase-file"))
        #expect(!arguments.contains("--passphrase"))
    }

    @Test("Hardware decrypt arguments do not put the PIN on the command line")
    func hardwarePinentryArguments_omitLoopbackAndTokenPath() {
        let tokenPath = "/tmp/gnupg/moaiy-pinentry.token"
        let arguments = StreamingCryptoPipeline.passphraseArguments(
            delivery: .hardwarePinentryToken,
            passphraseFile: tokenPath
        )
        #expect(arguments == ["--pinentry-mode", "ask", "--no-tty"])
        #expect(!arguments.contains("loopback"))
        #expect(!arguments.contains(tokenPath))
        #expect(!arguments.contains("--passphrase"))
    }

    @Test("Software decrypt keeps loopback passphrase file delivery")
    func softwarePassphraseArguments_stayLoopback() {
        let arguments = StreamingCryptoPipeline.passphraseArguments(
            delivery: .loopbackFile,
            passphraseFile: "/tmp/passphrase.token"
        )
        #expect(arguments == [
            "--pinentry-mode", "loopback",
            "--passphrase-file", "/tmp/passphrase.token"
        ])
    }

    @Test("Managed agent config points at bundled programs and does not start scdaemon")
    func managedAgentConfiguration_usesProgramPathsOnly() {
        let configuration = GPGService.managedAgentConfiguration(
            scdaemonPath: "/Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/scdaemon",
            pinentryPath: "/Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/pinentry"
        )
        #expect(configuration.contains("allow-loopback-pinentry"))
        #expect(configuration.contains("scdaemon-program /Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/scdaemon"))
        #expect(configuration.contains("pinentry-program /Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/pinentry"))
        #expect(!configuration.contains("--daemon"))
        #expect(!configuration.contains("passphrase"))
        #expect(!configuration.contains("default-cache-ttl"))
    }

    @Test("A PIN-less recipient probe does not block the smartcard PIN sheet")
    func preflight_probeNeedsPIN_presentsPINSheet() {
        let generic = AppLocalization.string("error_decryption_failed")
        let decision = KeyFileCryptoCoordinator.makeDecryptPreflightDecision(
            isSmartCardStub: true,
            presenceMessage: nil,
            recipientProbeNeedsPIN: true,
            recipientMismatchMessage: generic
        )
        #expect(decision == .presentHardwarePIN)
    }

    @Test("Generic presence failure is not shown as generic decryption failed")
    func preflight_genericPresence_usesSmartCardUnavailable() {
        let generic = AppLocalization.string("error_decryption_failed")
        let decision = KeyFileCryptoCoordinator.makeDecryptPreflightDecision(
            isSmartCardStub: true,
            presenceMessage: generic,
            recipientProbeNeedsPIN: false,
            recipientMismatchMessage: nil
        )
        guard case .block(let message) = decision else {
            Issue.record("Expected a blocking smartcard message")
            return
        }
        #expect(message == AppLocalization.string("error_smartcard_unavailable"))
        #expect(message != generic)
    }

    @Test("Missing card still blocks before the PIN sheet")
    func preflight_cardNotPresent_blocksWithSpecificMessage() {
        let message = AppLocalization.string("error_smartcard_not_present")
        let decision = KeyFileCryptoCoordinator.makeDecryptPreflightDecision(
            isSmartCardStub: true,
            presenceMessage: message,
            recipientProbeNeedsPIN: true,
            recipientMismatchMessage: nil
        )
        #expect(decision == .block(message))
    }

    @Test("A completed mismatch probe still blocks the PIN sheet")
    func preflight_realMismatch_blocks() {
        let mismatch = AppLocalization.string("error_decryption_requires_private_key")
        let decision = KeyFileCryptoCoordinator.makeDecryptPreflightDecision(
            isSmartCardStub: true,
            presenceMessage: nil,
            recipientProbeNeedsPIN: false,
            recipientMismatchMessage: mismatch
        )
        #expect(decision == .block(mismatch))
    }

    @Test("Software decrypt preflight is unchanged by the smartcard gate")
    func preflight_softwareKey_proceedsWithoutMismatch() {
        let decision = KeyFileCryptoCoordinator.makeDecryptPreflightDecision(
            isSmartCardStub: false,
            presenceMessage: nil,
            recipientProbeNeedsPIN: true,
            recipientMismatchMessage: nil
        )
        #expect(decision == .proceedToSoftwareDecrypt)
    }
}
