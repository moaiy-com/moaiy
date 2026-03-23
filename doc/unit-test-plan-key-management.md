# Key Management Unit Test Plan

> **Module**: Key Management
> **Version**: 1.0
> **Last Updated**: 2026-03-23

## Overview

This document outlines a comprehensive unit testing strategy for the Key Management module in Moaiy. The module consists of three main components:

1. **GPGService** - Core GPG operations
2. **KeyManagementViewModel** - State management and business logic
3. **ExpirationReminderService** - Key expiration notifications

---

## 1. GPGService Tests

### 1.1 GPGProcessExecutor Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-PE-001 | `testExecute_withValidCommand_returnsSuccess` | Execute valid GPG command (e.g., `--version`) | High |
| GPG-PE-002 | `testExecute_withInvalidArguments_returnsError` | Execute with invalid arguments | High |
| GPG-PE-003 | `testExecute_withTimeout_throwsTimeoutError` | Test timeout handling for long-running commands | High |
| GPG-PE-004 | `testExecute_withInput_writesToStdin` | Verify stdin input is correctly passed | Medium |
| GPG-PE-005 | `testExecute_withCustomEnvironment_setsEnvironment` | Verify custom environment variables | Medium |
| GPG-PE-006 | `testExecute_withGPGHome_setsGNUPGHOME` | Verify GNUPGHOME environment is set | High |

### 1.2 Key Listing Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-KL-001 | `testListKeys_returnsPublicKeys` | List all public keys | High |
| GPG-KL-002 | `testListKeys_withSecretOnly_returnsSecretKeys` | List only secret keys | High |
| GPG-KL-003 | `testListKeys_parsesKeyFields` | Verify all GPGKey fields are correctly parsed | High |
| GPG-KL-004 | `testListKeys_parsesFingerprint` | Verify fingerprint parsing from `fpr` record | High |
| GPG-KL-005 | `testListKeys_parsesUserID` | Verify name/email parsing from `uid` record | High |
| GPG-KL-006 | `testListKeys_parsesTrustLevel` | Verify trust level parsing | High |
| GPG-KL-007 | `testListKeys_parsesExpiration` | Verify expiration date parsing | High |
| GPG-KL-008 | `testListKeys_withNoKeys_returnsEmptyArray` | Handle empty keyring | Medium |
| GPG-KL-009 | `testListKeys_withInvalidOutput_throwsError` | Handle malformed GPG output | High |

### 1.3 Key Generation Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-KG-001 | `testGenerateKey_rsa4096_returnsFingerprint` | Generate RSA-4096 key | High |
| GPG-KG-002 | `testGenerateKey_rsa2048_returnsFingerprint` | Generate RSA-2048 key | High |
| GPG-KG-003 | `testGenerateKey_ecc_returnsFingerprint` | Generate ECC (Curve25519) key | High |
| GPG-KG-004 | `testGenerateKey_withPassphrase_storesPassphrase` | Key with passphrase | High |
| GPG-KG-005 | `testGenerateKey_withoutPassphrase_noProtection` | Key without passphrase | High |
| GPG-KG-006 | `testGenerateKey_withEmptyName_throwsError` | Validate required fields | Medium |
| GPG-KG-007 | `testGenerateKey_withInvalidEmail_throwsError` | Validate email format | Medium |
| GPG-KG-008 | `testGenerateKey_duplicateEmail_returnsNewFingerprint` | Allow duplicate emails | Low |
| GPG-KG-009 | `testBuildKeyGenerationParams_rsa_format` | Verify RSA param format | Medium |
| GPG-KG-010 | `testBuildKeyGenerationParams_ecc_format` | Verify ECC param format | Medium |

### 1.4 Key Import Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-KI-001 | `testImportKey_publicKey_importsSuccessfully` | Import public key from file | High |
| GPG-KI-002 | `testImportKey_secretKey_importsSuccessfully` | Import secret key from file | High |
| GPG-KI-003 | `testImportKey_armoredKey_importsSuccessfully` | Import ASCII-armored key | High |
| GPG-KI-004 | `testImportKey_binaryKey_importsSuccessfully` | Import binary key | Medium |
| GPG-KI-005 | `testImportKey_duplicateKey_returnsUnchanged` | Handle duplicate import | Medium |
| GPG-KI-006 | `testImportKey_invalidFile_throwsError` | Handle invalid file | High |
| GPG-KI-007 | `testImportKey_nonExistentFile_throwsError` | Handle missing file | High |
| GPG-KI-008 | `testParseImportResult_extractsNewKeyIDs` | Verify result parsing | Medium |

### 1.5 Key Export Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-KE-001 | `testExportPublicKey_returnsData` | Export public key | High |
| GPG-KE-002 | `testExportPublicKey_withArmor_returnsArmoredData` | Export armored public key | High |
| GPG-KE-003 | `testExportPublicKey_withoutArmor_returnsBinaryData` | Export binary public key | Medium |
| GPG-KE-004 | `testExportSecretKey_returnsData` | Export secret key with passphrase | High |
| GPG-KE-005 | `testExportSecretKey_withWrongPassphrase_throwsError` | Wrong passphrase handling | High |
| GPG-KE-006 | `testExportKey_nonExistentKey_throwsError` | Handle missing key | High |

### 1.6 Key Deletion Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-KD-001 | `testDeleteKey_publicKey_deletesSuccessfully` | Delete public key | High |
| GPG-KD-002 | `testDeleteKey_secretKey_deletesSuccessfully` | Delete secret key | High |
| GPG-KD-003 | `testDeleteKey_nonExistentKey_throwsError` | Handle missing key | High |
| GPG-KD-004 | `testDeleteKey_withBoth_deletesBothKeys` | Delete both public and secret | High |

### 1.7 Trust Management Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-TM-001 | `testCheckTrust_returnsTrustLevel` | Check key trust level | High |
| GPG-TM-002 | `testSetTrust_updatesTrustLevel` | Set owner trust | High |
| GPG-TM-003 | `testSetTrust_marginal_setsCorrectly` | Set marginal trust | Medium |
| GPG-TM-004 | `testSetTrust_full_setsCorrectly` | Set full trust | Medium |
| GPG-TM-005 | `testSetTrust_ultimate_setsCorrectly` | Set ultimate trust | Medium |
| GPG-TM-006 | `testUpdateTrustDB_completesSuccessfully` | Update trust database | Medium |
| GPG-TM-007 | `testSignKey_withPassphrase_signsSuccessfully` | Sign a key | High |
| GPG-TM-008 | `testSignKey_withTrustLevel_setsTrust` | Sign and set trust | Medium |
| GPG-TM-009 | `testGetTrustDetails_returnsDetails` | Get trust details | Medium |
| GPG-TM-010 | `testGetTrustDetails_countsSignatures` | Count key signatures | Low |

### 1.8 Error Handling Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| GPG-ERR-001 | `testGPGNotFound_throwsCorrectError` | GPG not found error | High |
| GPG-ERR-002 | `testExecutionFailed_includesMessage` | Execution failed with message | High |
| GPG-ERR-003 | `testInvalidOutput_throwsCorrectError` | Invalid output error | High |
| GPG-ERR-004 | `testKeyNotFound_throwsCorrectError` | Key not found error | High |
| GPG-ERR-005 | `testFileAccessDenied_includesPath` | File access denied with path | Medium |

---

## 2. KeyManagementViewModel Tests

### 2.1 State Management Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-ST-001 | `testInit_loadsKeys` | Initialization triggers key loading | High |
| VM-ST-002 | `testIsLoading_setsCorrectly` | Loading state management | High |
| VM-ST-003 | `testErrorMessage_setsOnError` | Error message on failure | High |
| VM-ST-004 | `testClearError_clearsMessage` | Clear error message | Medium |
| VM-ST-005 | `testKeys_sortedByName` | Keys sorted alphabetically | Medium |

### 2.2 Key Loading Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-KL-001 | `testLoadKeys_mergesPublicAndSecret` | Merge public and secret keys | High |
| VM-KL-002 | `testLoadKeys_marksSecretKeys` | Secret keys have isSecret=true | High |
| VM-KL-003 | `testLoadKeys_updatesExpirationReminder` | Expiration service updated | Medium |
| VM-KL-004 | `testLoadKeys_onError_setsErrorMessage` | Error handling | High |
| VM-KL-005 | `testLoadKeys_retriesOnError` | Auto-retry logic | High |
| VM-KL-006 | `testLoadKeys_maxRetries_stopsRetrying` | Max retry limit | Medium |
| VM-KL-007 | `testRefresh_resetsRetryCount` | Manual refresh resets retries | Medium |

### 2.3 Filtering Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-FT-001 | `testFilteredKeys_withNoFilter_returnsAll` | No filter returns all keys | High |
| VM-FT-002 | `testFilteredKeys_withSearchText_filtersByName` | Search by name | High |
| VM-FT-003 | `testFilteredKeys_withSearchText_filtersByEmail` | Search by email | High |
| VM-FT-004 | `testFilteredKeys_withSearchText_filtersByFingerprint` | Search by fingerprint | High |
| VM-FT-005 | `testFilteredKeys_withPublicOnly_returnsPublicKeys` | Filter public keys only | High |
| VM-FT-006 | `testFilteredKeys_withSecretOnly_returnsSecretKeys` | Filter secret keys only | High |
| VM-FT-007 | `testFilteredKeys_withTrustLevel_filtersCorrectly` | Filter by trust level | Medium |
| VM-FT-008 | `testFilteredKeys_withAlgorithm_filtersCorrectly` | Filter by algorithm | Medium |
| VM-FT-009 | `testFilteredKeys_hideExpired_excludesExpired` | Hide expired keys | High |
| VM-FT-010 | `testFilteredKeys_combinedFilters_appliesAll` | Combined filters | High |
| VM-FT-011 | `testResetFilters_clearsAllFilters` | Reset all filters | High |
| VM-FT-012 | `testHasActiveFilters_returnsCorrectValue` | Active filter detection | Medium |

### 2.4 Computed Properties Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-CP-001 | `testPublicKeys_returnsOnlyPublic` | Public keys property | High |
| VM-CP-002 | `testSecretKeys_returnsOnlySecret` | Secret keys property | High |
| VM-CP-003 | `testHasKeys_returnsTrueWithKeys` | Has keys check | Medium |
| VM-CP-004 | `testHasKeys_returnsFalseEmpty` | Empty keys check | Medium |
| VM-CP-005 | `testAvailableAlgorithms_returnsSortedUnique` | Algorithm list | Medium |

### 2.5 Key Generation Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-KG-001 | `testGenerateKey_success_returnsFingerprint` | Generate key returns fingerprint | High |
| VM-KG-002 | `testGenerateKey_reloadsKeys` | Keys reloaded after generation | High |
| VM-KG-003 | `testGenerateKey_onError_setsErrorMessage` | Error handling | High |
| VM-KG-004 | `testGenerateKey_setsLoading` | Loading state during generation | Medium |

### 2.6 Key Import/Export Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-IE-001 | `testImportKey_success_returnsResult` | Import key returns result | High |
| VM-IE-002 | `testImportKey_reloadsKeys` | Keys reloaded after import | High |
| VM-IE-003 | `testImportKey_handlesSecurityScopedResource` | Security-scoped resource | High |
| VM-IE-004 | `testExportPublicKey_returnsData` | Export public key | High |
| VM-IE-005 | `testExportSecretKey_validatesSecret` | Validate secret key exists | High |
| VM-IE-006 | `testExportSecretKey_returnsData` | Export secret key | High |

### 2.7 Key Deletion Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-KD-001 | `testDeleteKey_secretOnly_deletesSecret` | Delete secret only | High |
| VM-KD-002 | `testDeleteKey_publicOnly_deletesPublic` | Delete public only | High |
| VM-KD-003 | `testDeleteKey_both_deletesAll` | Delete both | High |
| VM-KD-004 | `testDeleteKey_reloadsKeys` | Keys reloaded after delete | High |
| VM-KD-005 | `testDeleteKey_onError_setsErrorMessage` | Error handling | High |

### 2.8 Trust Management Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-TM-001 | `testCheckTrust_returnsTrustLevel` | Check trust level | High |
| VM-TM-002 | `testSetTrust_updatesKey` | Set trust and reload | High |
| VM-TM-003 | `testSignKey_signsSuccessfully` | Sign key | High |
| VM-TM-004 | `testUpdateTrustDB_completesSuccessfully` | Update trust DB | Medium |

### 2.9 Search History Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| VM-SH-001 | `testAddToSearchHistory_addsToBeginning` | Add to history start | Medium |
| VM-SH-002 | `testAddToSearchHistory_movesExistingToFront` | Move existing to front | Medium |
| VM-SH-003 | `testAddToSearchHistory_limitsSize` | History size limit | Medium |
| VM-SH-004 | `testClearSearchHistory_clearsAll` | Clear history | Low |

---

## 3. ExpirationReminderService Tests

### 3.1 Expiration Detection Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| ER-ED-001 | `testUpdateKeys_identifiesExpiredKeys` | Identify expired keys | High |
| ER-ED-002 | `testUpdateKeys_identifiesExpiringSoonKeys` | Identify expiring soon | High |
| ER-ED-003 | `testUpdateKeys_ignoresKeysWithoutExpiration` | Handle no expiration | Medium |
| ER-ED-004 | `testUpdateKeys_usesReminderDays` | Use configured days | High |

### 3.2 Notification Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| ER-NT-001 | `testScheduleReminders_schedulesForExpiring` | Schedule for expiring keys | High |
| ER-NT-002 | `testScheduleReminders_skipsIfDisabled` | Skip if disabled | High |
| ER-NT-003 | `testNotifyExpiredKeys_sendsNotification` | Send expired notification | High |
| ER-NT-004 | `testNotifyExpiringSoon_sendsNotification` | Send expiring notification | High |
| ER-NT-005 | `testCancelAllReminders_cancelsAll` | Cancel all notifications | Medium |

### 3.3 Settings Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| ER-ST-001 | `testIsEnabled_persistsToUserDefaults` | Persist enabled setting | Medium |
| ER-ST-002 | `testReminderDays_persistsToUserDefaults` | Persist days setting | Medium |
| ER-ST-003 | `testIsEnabled_onChange_schedulesOrCancels` | Toggle behavior | Medium |

---

## 4. Model Tests

### 4.1 GPGKey Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| MD-GK-001 | `testIsExpired_withPastDate_returnsTrue` | Expired key detection | High |
| MD-GK-002 | `testIsExpired_withFutureDate_returnsFalse` | Not expired detection | High |
| MD-GK-003 | `testIsExpired_withNoExpiration_returnsFalse` | No expiration handling | High |
| MD-GK-004 | `testIsTrusted_withFullTrust_returnsTrue` | Full trust is trusted | Medium |
| MD-GK-005 | `testIsTrusted_withUltimateTrust_returnsTrue` | Ultimate trust is trusted | Medium |
| MD-GK-006 | `testIsTrusted_withMarginalTrust_returnsFalse` | Marginal not trusted | Medium |
| MD-GK-007 | `testDisplayKeyType_formatsCorrectly` | Display format | Low |
| MD-GK-008 | `testHashable_consistency` | Hashable conformance | Medium |
| MD-GK-009 | `testIdentifiable_usesFingerprint` | ID is fingerprint | Medium |

### 4.2 TrustLevel Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| MD-TL-001 | `testGPGCode_returnsCorrectCode` | GPG code mapping | High |
| MD-TL-002 | `testInitFromGPGCode_mapsCorrectly` | Parse from GPG code | High |
| MD-TL-003 | `testInitFromGPGCode_handlesUnknown` | Unknown code handling | Medium |
| MD-TL-004 | `testDisplayName_returnsLocalized` | Localized display name | Medium |
| MD-TL-005 | `testAllCases_containsAllLevels` | All cases present | Low |

### 4.3 KeyType Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| MD-KT-001 | `testRSA4096_returnsCorrectLength` | RSA-4096 key length | High |
| MD-KT-002 | `testRSA2048_returnsCorrectLength` | RSA-2048 key length | High |
| MD-KT-003 | `testECC_returnsCorrectCurve` | ECC curve name | High |
| MD-KT-004 | `testKeyType_gpgKeyType` | GPG type string | Medium |
| MD-KT-005 | `testAllCases_containsAllTypes` | All cases present | Low |

### 4.4 KeyTrustDetails Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| MD-TD-001 | `testIsTrusted_withFullCalculated_returnsTrue` | Calculated trust check | Medium |
| MD-TD-002 | `testHasSignatures_withCount_returnsTrue` | Signature count check | Low |

### 4.5 GPGError Tests

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| MD-GE-001 | `testErrorDescription_returnsLocalized` | Localized description | High |
| MD-GE-002 | `testRecoverySuggestion_returnsLocalized` | Recovery suggestion | High |
| MD-GE-003 | `testAllCases_haveDescriptions` | All cases covered | Medium |

---

## 5. Integration Tests

### 5.1 End-to-End Key Lifecycle

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| INT-LC-001 | `testKeyLifecycle_generateExportImportDelete` | Full key lifecycle | High |
| INT-LC-002 | `testKeyTrust_setAndVerify` | Trust lifecycle | High |
| INT-LC-003 | `testKeySearch_filterAndView` | Search and filter flow | Medium |

### 5.2 ViewModel-Service Integration

| Test ID | Test Name | Description | Priority |
|---------|-----------|-------------|----------|
| INT-VS-001 | `testViewModel_usesSharedGPGService` | Service injection | High |
| INT-VS-002 | `testViewModel_updatesExpirationService` | Expiration integration | High |

---

## 6. Test Infrastructure Requirements

### 6.1 Mock Objects

```
MockGPGService
├── stubbedKeys: [GPGKey]
├── stubbedError: Error?
├── generateKeyResult: Result<String, Error>
├── importKeyResult: Result<KeyImportResult, Error>
└── exportKeyData: Data?
```

### 6.2 Test Helpers

```swift
// Test key factory
struct TestKeyFactory {
    static func makeKey(
        name: String = "Test User",
        email: String = "test@example.com",
        isSecret: Bool = false,
        trustLevel: TrustLevel = .unknown,
        expiresAt: Date? = nil
    ) -> GPGKey
    
    static func makeExpiredKey() -> GPGKey
    static func makeExpiringSoonKey(days: Int = 7) -> GPGKey
}

// Async test helpers
extension XCTestCase {
    func asyncAwait(_ timeout: TimeInterval = 1.0, _ operation: @escaping () async throws -> Void) throws
}
```

### 6.3 Test Environment Setup

- Isolated GPG home directory for each test
- Cleanup after each test
- Mock file system for import/export tests

---

## 7. Test Coverage Goals

| Component | Target Coverage | Priority |
|-----------|-----------------|----------|
| GPGService | 80% | High |
| KeyManagementViewModel | 90% | High |
| ExpirationReminderService | 85% | Medium |
| Models (GPGKey, TrustLevel, etc.) | 95% | Medium |
| GPGError | 100% | Low |

---

## 8. Implementation Priority

### Phase 1: Core Functionality (Week 1)
- GPGService key listing tests
- KeyManagementViewModel state tests
- Model tests (GPGKey, TrustLevel, KeyType)

### Phase 2: Key Operations (Week 2)
- Key generation tests
- Key import/export tests
- Key deletion tests

### Phase 3: Trust & Filtering (Week 3)
- Trust management tests
- Filter tests
- Search history tests

### Phase 4: Integration & Edge Cases (Week 4)
- Integration tests
- Error handling tests
- Edge case coverage

---

## 9. Test File Structure

```
MoaiyTests/
├── Services/
│   ├── GPGServiceTests.swift
│   ├── GPGProcessExecutorTests.swift
│   └── ExpirationReminderServiceTests.swift
├── ViewModels/
│   └── KeyManagementViewModelTests.swift
├── Models/
│   ├── GPGKeyTests.swift
│   ├── TrustLevelTests.swift
│   ├── KeyTypeTests.swift
│   ├── KeyTrustDetailsTests.swift
│   └── GPGErrorTests.swift
├── Integration/
│   └── KeyLifecycleIntegrationTests.swift
└── Helpers/
    ├── MockGPGService.swift
    ├── TestKeyFactory.swift
    └── XCTestCase+Async.swift
```

---

## 10. Notes

- All tests should follow Swift Testing framework (`@Test` macro)
- Use async/await for asynchronous tests
- Mock external dependencies (GPG binary, file system)
- Ensure tests are isolated and can run in parallel
- Add localization tests for error messages

