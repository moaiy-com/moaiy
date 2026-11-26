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

    @Test("Managed agent config points at the helper app and does not start scdaemon")
    func managedAgentConfiguration_usesProgramPathsOnly() {
        let scdaemonPath = "/Applications/Moaiy.app/Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/MoaiyScdaemon"
        let configuration = GPGService.managedAgentConfiguration(
            scdaemonPath: scdaemonPath,
            pinentryPath: "/Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/pinentry"
        )
        #expect(configuration.contains("allow-loopback-pinentry"))
        #expect(configuration.contains("scdaemon-program \(scdaemonPath)"))
        #expect(configuration.contains("pinentry-program /Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/pinentry"))
        #expect(!configuration.contains("--daemon"))
        #expect(!configuration.contains("passphrase"))
        #expect(!configuration.contains("default-cache-ttl"))
        #expect(!configuration.contains("gpg.bundle/bin/scdaemon"))
        #expect(!configuration.contains("MacOS/scdaemon"))
    }

    @Test("Helper scdaemon path is resolved from the bundled gpg executable")
    func bundledScdaemonHelperURL_isDerivedFromGPGExecutable() {
        let gpgURL = URL(fileURLWithPath: "/Applications/Moaiy.app/Contents/Resources/gpg.bundle/bin/gpg")
        let helper = GPGService.bundledScdaemonHelperURL(fromGPGExecutable: gpgURL)
        #expect(helper?.path == "/Applications/Moaiy.app/Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/scdaemon")
        #expect(GPGService.bundledScdaemonHelperRelativePath == "Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/scdaemon")
        let helperApp = GPGService.bundledScdaemonHelperAppURL(fromGPGExecutable: gpgURL)
        #expect(helperApp?.path == "/Applications/Moaiy.app/Contents/Helpers/MoaiyScdaemon.app")
        #expect(GPGService.bundledScdaemonHelperAppRelativePath == "Contents/Helpers/MoaiyScdaemon.app")
        let agentProgram = GPGService.bundledScdaemonAgentProgramURL(fromGPGExecutable: gpgURL)
        #expect(agentProgram?.path == "/Applications/Moaiy.app/Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/MoaiyScdaemon")
        #expect(GPGService.bundledScdaemonAgentProgramRelativePath == "Contents/Helpers/MoaiyScdaemon.app/Contents/MacOS/MoaiyScdaemon")
        #expect(agentProgram?.path != helper?.path)
    }

    @Test("Launcher execs scdaemon with the helper-container homedir and multi-server, without a PIN or daemon")
    func scdaemonHelperLauncher_resolvesRealHomeAndExecsMultiServer() {
        let realHome = "/Users/example"
        let publishedHome = GPGService.launcherResolvedGnuPGHomePath(realHome: realHome)
        let sandboxHome = GPGService.launcherResolvedScdaemonSandboxHomePath(realHome: realHome)
        #expect(publishedHome == "/Users/example/Library/Containers/com.moaiy.app/Data/Library/gnupg")
        #expect(sandboxHome == "/Users/example/Library/Containers/com.moaiy.app.scdaemon/Data/Library/gnupg")
        #expect(GPGService.appManagedGnuPGHomeRelativePath == "Library/Containers/com.moaiy.app/Data/Library/gnupg")
        #expect(GPGService.scdaemonHelperSandboxHomeRelativePath == "Library/Containers/com.moaiy.app.scdaemon/Data/Library/gnupg")
        #expect(GPGService.scdaemonHelperPublishesSocketInAppManagedHome)

        #expect(GPGService.realUserHomeDirectoryPath(passwdDirectory: realHome) == realHome)
        #expect(GPGService.realUserHomeDirectoryPath(passwdDirectory: "/Users/example/Library/Containers/com.moaiy.app.scdaemon/Data") == nil)
        #expect(GPGService.realUserHomeDirectoryPath(passwdDirectory: "relative") == nil)
        #expect(GPGService.launcherResolvedGnuPGHomePath(realHome: "/Users/example/Library/Containers/foo/Data") == nil)
        #expect(GPGService.launcherResolvedScdaemonSandboxHomePath(realHome: "/Users/example/Library/Containers/foo/Data") == nil)

        let arguments = GPGService.scdaemonHelperExecArguments(homePath: sandboxHome!)
        #expect(arguments == ["--homedir", sandboxHome, "--multi-server"])
        #expect(arguments != ["--homedir", publishedHome, "--multi-server"])
        #expect(!arguments.contains("--daemon"))
        #expect(!arguments.contains("--server"))
        #expect(!arguments.contains("passphrase"))
        #expect(!arguments.contains("pin"))
        #expect(!arguments.contains("PIN"))

        #expect(GPGService.scdaemonHelperLaunchServicesPassesArguments == false)
        let resolved = GPGService.realUserHomeDirectoryPath()
        #expect(resolved != nil)
        #expect(resolved?.hasPrefix("/") == true)
        #expect(resolved?.contains("/Library/Containers/") == false)
    }

    @Test("Managed scdaemon.conf keeps disable-ccid and pcsc-shared without dropping other lines")
    func managedScdaemonConfiguration_preservesExistingOptions() {
        let created = GPGService.managedScdaemonConfiguration(existing: nil)
        #expect(created.contains("disable-ccid"))
        #expect(created.contains("pcsc-shared"))

        let existing = "disable-ccid\npcsc-shared\n"
        #expect(GPGService.managedScdaemonConfiguration(existing: existing) == existing)

        let withExtra = "# reader comment\nreader-port 0\n"
        let merged = GPGService.managedScdaemonConfiguration(existing: withExtra)
        #expect(merged.contains("reader-port 0"))
        #expect(merged.contains("# reader comment"))
        #expect(merged.contains("disable-ccid"))
        #expect(merged.contains("pcsc-shared"))
    }

    @Test("Key list retries skip card-path failures and only briefly retry agent start")
    func keyListRetryPolicy_skipsCardPathAndLimitsAgentRetry() {
        #expect(GPGService.keyListRetryPolicy(for: GPGError.smartCardUnavailable) == .doNotRetry)
        #expect(GPGService.keyListRetryPolicy(for: GPGError.smartCardNotPresent) == .doNotRetry)
        #expect(
            GPGService.keyListRetryPolicy(for: GPGError.executionFailed("can't connect to the scdaemon"))
                == .doNotRetry
        )
        #expect(
            GPGService.keyListRetryPolicy(for: GPGError.executionFailed("Failed to launch gpg-agent (exit code: 1)"))
                == .retryOnceShort
        )
        #expect(
            GPGService.keyListRetryPolicy(for: GPGError.executionFailed("gpg-agent is not reachable after launch"))
                == .retryOnceShort
        )
        #expect(
            GPGService.keyListRetryPolicy(for: GPGError.executionFailed("unexpected parse error"))
                == .retryWithBackoff
        )
        #expect(GPGService.secretKeyListTimeout <= 5)
        #expect(GPGService.smartCardPresenceTimeout <= 3)
        #expect(GPGService.secretKeyListArgumentsWithoutCardIO().contains("--no-autostart"))
        #expect(!GPGService.secretKeyListArgumentsWithoutCardIO().contains("--list-secret-keys"))
    }

    @Test("File-backed stubs expose card serials without talking to scdaemon")
    func secretInfoFromPrivateKeyFile_readsShadowSerial() {
        let shadowed = """
        (shadowed-private-key
          (ecc (curve "Ed25519")(q #00#))
          (shadowed t1-v1
            #D2760001240100000006198741050000# "OPENPGP.1"))
        """
        let token = GPGService.secretInfoFromPrivateKeyFile(contents: shadowed)
        #expect(token.isToken)
        #expect(token.serialNumber == "D2760001240100000006198741050000")

        let local = """
        (protected-private-key
          (key (protected openpgp-s2k3-sha1-aes-cbc #00#)))
        """
        let disk = GPGService.secretInfoFromPrivateKeyFile(contents: local)
        #expect(!disk.isToken)
        #expect(disk.serialNumber == nil)

        let fromDir = GPGService.secretInfoFromPrivateKeyDirectory(files: [
            (keygrip: "1111111111111111111111111111111111111111", contents: shadowed)
        ])
        #expect(fromDir["1111111111111111111111111111111111111111"]?.serialNumber == "D2760001240100000006198741050000")
    }

    @Test("Secret key list merge uses KEYINFO stubs instead of card I/O")
    func keysByMergingAgentSecretInfo_usesFileBackedStubs() {
        let output = """
        pub:u:255:22:80A9F21258CB1E83:1773379357:::u:::scESCA:::ed25519:::0:
        fpr:::::::::AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:
        grp:::::::::1111111111111111111111111111111111111111:
        uid:u::::1773379357::ABCDEF::Card User <card@example.com>::::::::::0:
        sub:u:255:18:21635FE639C33F67:1773379357::::::e:::cv25519::
        fpr:::::::::BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB:
        grp:::::::::2222222222222222222222222222222222222222:
        """
        let publicKeys = [
            GPGKey(
                id: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                keyID: "80A9F21258CB1E83",
                fingerprint: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                name: "Card User",
                email: "card@example.com",
                algorithm: "22",
                keyLength: 255,
                isSecret: false,
                createdAt: nil,
                expiresAt: nil,
                trustLevel: .ultimate
            )
        ]
        let grips = GPGService.parseKeygripsByPrimaryFingerprint(output)
        #expect(grips["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"] == [
            "1111111111111111111111111111111111111111",
            "2222222222222222222222222222222222222222"
        ])

        let keyinfo = """
        S KEYINFO 1111111111111111111111111111111111111111 T D2760001240100000006198741050000 OPENPGP.1 - - - -
        S KEYINFO 2222222222222222222222222222222222222222 T D2760001240100000006198741050000 OPENPGP.2 - - - -
        """
        let info = GPGService.parseAgentSecretKeyInfo(keyinfo)
        let secrets = GPGService.keysByMergingAgentSecretInfo(
            publicKeys: publicKeys,
            keygripsByFingerprint: grips,
            secretInfoByKeygrip: info,
            secretOnly: true
        )
        #expect(secrets.count == 1)
        #expect(secrets[0].isSecret)
        #expect(secrets[0].secretMaterial == .smartCardStub)
        #expect(secrets[0].cardSerialNumber == "D2760001240100000006198741050000")
        #expect(secrets[0].email == "card@example.com")
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

    @Test("App-managed key listing does not start the agent or scdaemon")
    func appManagedKeyList_doesNotNeedRunningAgent() {
        #expect(!GPGService.appManagedKeyListNeedsRunningAgent(secretOnly: true))
        #expect(!GPGService.appManagedKeyListNeedsRunningAgent(secretOnly: false))
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
