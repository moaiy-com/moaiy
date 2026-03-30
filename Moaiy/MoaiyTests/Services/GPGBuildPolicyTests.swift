//
//  GPGBuildPolicyTests.swift
//  MoaiyTests
//
//  Unit tests for build-specific GPG behavior.
//

import Testing
@testable import Moaiy

@Suite("GPG Build Policy Tests")
struct GPGBuildPolicyTests {

    @Test("External GPG fallback is allowed only for debug builds")
    @MainActor
    func externalGPGFallback_onlyDebugBuild() {
        #expect(GPGService.allowsExternalGPGFallback(isDebugBuild: true))
        #expect(!GPGService.allowsExternalGPGFallback(isDebugBuild: false))
    }

    @Test("System GPG home override requires debug build and explicit flag")
    @MainActor
    func systemGPGHomeOverride_requiresDebugAndFlag() {
        #expect(
            GPGService.allowsSystemGPGHomeOverride(
                isDebugBuild: true,
                environment: ["MOAIY_USE_SYSTEM_GNUPG": "1"]
            )
        )

        #expect(
            !GPGService.allowsSystemGPGHomeOverride(
                isDebugBuild: true,
                environment: [:]
            )
        )

        #expect(
            !GPGService.allowsSystemGPGHomeOverride(
                isDebugBuild: false,
                environment: ["MOAIY_USE_SYSTEM_GNUPG": "1"]
            )
        )
    }
}
