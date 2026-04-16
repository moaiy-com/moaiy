//
//  GPGErrorTests.swift
//  MoaiyTests
//
//  Unit tests for GPGError enum
//

import Foundation
import Testing
@testable import Moaiy

@Suite("GPGError Tests")
struct GPGErrorTests {
    
    // MARK: - Error Description Tests
    
    @Test("gpgNotFound returns localized description")
    func gpgNotFound_errorDescription() {
        let error = GPGError.gpgNotFound
        
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
    
    @Test("executionFailed includes message")
    func executionFailed_includesMessage() {
        let message = "Test error message"
        let error = GPGError.executionFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("invalidOutput includes message")
    func invalidOutput_includesMessage() {
        let message = "Invalid format"
        let error = GPGError.invalidOutput(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("keyNotFound includes identifier")
    func keyNotFound_includesIdentifier() {
        let identifier = "ABC123"
        let error = GPGError.keyNotFound(identifier)
        
        #expect(error.errorDescription?.contains(identifier) == true)
    }
    
    @Test("keyGenerationFailed includes message")
    func keyGenerationFailed_includesMessage() {
        let message = "Weak passphrase"
        let error = GPGError.keyGenerationFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("encryptionFailed includes message")
    func encryptionFailed_includesMessage() {
        let message = "No recipient"
        let error = GPGError.encryptionFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("decryptionFailed includes message")
    func decryptionFailed_includesMessage() {
        let message = "Bad passphrase"
        let error = GPGError.decryptionFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("importFailed includes message")
    func importFailed_includesMessage() {
        let message = "Invalid key"
        let error = GPGError.importFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("exportFailed includes message")
    func exportFailed_includesMessage() {
        let message = "Permission denied"
        let error = GPGError.exportFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("invalidPassphrase returns localized description")
    func invalidPassphrase_errorDescription() {
        let error = GPGError.invalidPassphrase
        
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }
    
    @Test("operationCancelled returns localized description")
    func operationCancelled_errorDescription() {
        let error = GPGError.operationCancelled
        
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test("smart card errors return localized descriptions")
    func smartCardErrors_errorDescription() {
        let errors: [GPGError] = [
            .smartCardNotPresent,
            .smartCardUnavailable,
            .smartCardPinInvalid
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
    
    @Test("fileAccessDenied includes path")
    func fileAccessDenied_includesPath() {
        let path = "/path/to/file.gpg"
        let error = GPGError.fileAccessDenied(path)
        
        #expect(error.errorDescription?.contains(path) == true)
    }
    
    @Test("unsupportedKeyType includes type")
    func unsupportedKeyType_includesType() {
        let type = "DSA"
        let error = GPGError.unsupportedKeyType(type)
        
        #expect(error.errorDescription?.contains(type) == true)
    }
    
    @Test("trustUpdateFailed includes message")
    func trustUpdateFailed_includesMessage() {
        let message = "Database locked"
        let error = GPGError.trustUpdateFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    @Test("keySigningFailed includes message")
    func keySigningFailed_includesMessage() {
        let message = "No signing key"
        let error = GPGError.keySigningFailed(message)
        
        #expect(error.errorDescription?.contains(message) == true)
    }
    
    // MARK: - Recovery Suggestion Tests
    
    @Test("All error cases have recovery suggestions")
    func allCases_haveRecoverySuggestions() {
        let errors: [GPGError] = [
            .gpgNotFound,
            .executionFailed("test"),
            .invalidOutput("test"),
            .keyNotFound("test"),
            .keyGenerationFailed("test"),
            .encryptionFailed("test"),
            .decryptionFailed("test"),
            .importFailed("test"),
            .exportFailed("test"),
            .invalidPassphrase,
            .operationCancelled,
            .fileAccessDenied("test"),
            .unsupportedKeyType("test"),
            .trustUpdateFailed("test"),
            .keySigningFailed("test"),
            .smartCardNotPresent,
            .smartCardUnavailable,
            .smartCardPinInvalid
        ]
        
        for error in errors {
            #expect(error.recoverySuggestion != nil, "Missing recovery suggestion for \(error)")
            #expect(!error.recoverySuggestion!.isEmpty, "Empty recovery suggestion for \(error)")
        }
    }
    
    // MARK: - LocalizedError Conformance Tests
    
    @Test("errorDescription is same as localizedDescription")
    func errorDescription_sameAsLocalizedDescription() {
        let error = GPGError.gpgNotFound
        
        #expect(error.errorDescription == error.localizedDescription)
    }
    
    // MARK: - Error Equality Tests
    
    @Test("Same error cases are equal")
    func sameErrors_areEqual() {
        let error1 = GPGError.gpgNotFound
        let error2 = GPGError.gpgNotFound
        
        #expect(error1.localizedDescription == error2.localizedDescription)
    }
    
    @Test("Different error cases have different descriptions")
    func differentErrors_haveDifferentDescriptions() {
        let error1 = GPGError.gpgNotFound
        let error2 = GPGError.invalidPassphrase
        
        #expect(error1.localizedDescription != error2.localizedDescription)
    }

    @Test("Raw bad pin message maps to smart card pin error message")
    func rawBadPin_mapsToSmartCardPinMessage() {
        let mapped = UserFacingErrorMapper.message(
            for: GPGError.executionFailed("gpg: signing failed: Bad PIN"),
            context: .sign
        )
        #expect(mapped == AppLocalization.string("error_smartcard_pin_invalid"))
    }

    @Test("Raw bad passphrase maps to invalid passphrase message")
    func rawBadPassphrase_mapsToInvalidPassphraseMessage() {
        let mapped = UserFacingErrorMapper.message(
            for: GPGError.executionFailed("gpg: signing failed: Bad passphrase"),
            context: .keyEdit
        )
        #expect(mapped == AppLocalization.string("error_invalid_passphrase"))
    }

    @Test("Ownertrust raw failures fall back to trust update message")
    func ownertrustRawFailure_mapsToTrustUpdateMessage() {
        let mapped = UserFacingErrorMapper.message(
            for: GPGError.executionFailed("gpg: error in ownertrust values"),
            context: .trust
        )
        #expect(mapped == AppLocalization.string("error_trust_update_failed"))
    }

    @Test("App localization string follows all supported app languages")
    func appLocalization_stringFollowsAllSupportedLanguages() {
        let defaults = UserDefaults.standard
        let key = Constants.StorageKeys.appLanguageCode
        let originalValue = defaults.string(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let followSystemExpectations: [(AppLanguageOption, String)] = [
            (.english, "Follow System"),
            (.chineseSimplified, "跟随系统"),
            (.spanish, "Seguir el sistema"),
            (.portugueseBrazil, "Seguir sistema"),
            (.hindi, "सिस्टम सेटिंग का पालन करें"),
            (.arabic, "اتباع إعدادات النظام"),
            (.french, "Suivre le système"),
            (.german, "System folgen"),
            (.japanese, "システムに従う"),
            (.korean, "시스템 설정 따르기"),
            (.russian, "Следовать системе"),
        ]

        for (language, expected) in followSystemExpectations {
            defaults.set(language.rawValue, forKey: key)
            #expect(AppLocalization.string("setting_language_option_system") == expected)
        }
    }

    @Test("App language options include all planned locales")
    func appLanguageOptions_includeAllPlannedLocales() {
        #expect(AppLanguageOption.allCases.count == 12)
    }

    @Test("Newly added East Europe locales do not fall back to English")
    func newlyAddedLocales_doNotFallbackToEnglish() {
        let defaults = UserDefaults.standard
        let key = Constants.StorageKeys.appLanguageCode
        let originalValue = defaults.string(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let nonEnglishLanguages: [AppLanguageOption] = [
            .japanese,
            .korean,
            .russian,
        ]

        for language in nonEnglishLanguages {
            defaults.set(language.rawValue, forKey: key)
            #expect(AppLocalization.string("action_cancel") != "Cancel")
            #expect(AppLocalization.string("action_confirm") != "Confirm")
        }
    }
}
