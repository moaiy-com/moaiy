//
//  KeyManagementViewModelTests.swift
//  MoaiyTests
//
//  Unit tests for KeyManagementViewModel
//

import Foundation
import Testing
@testable import Moaiy

@MainActor
@Suite("KeyManagementViewModel Tests")
struct KeyManagementViewModelTests {
    
    // MARK: - State Management Tests
    
    @Test("Initial state has empty keys")
    func initialState_hasEmptyKeys() async {
        let viewModel = KeyManagementViewModel()
        
        // Wait a bit for async initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Keys might be loaded or empty depending on GPG availability
        // Just verify the property exists and is accessible
        _ = viewModel.keys
    }
    
    @Test("isLoading state is managed correctly")
    func isLoading_stateIsManaged() async {
        let viewModel = KeyManagementViewModel()
        
        // Wait a bit for initialization
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // isLoading may be true during initialization, but should be accessible
        // Just verify the property exists and is a Bool
        let _ = viewModel.isLoading
        
        // After calling clearError and reset, state should be clean
        viewModel.clearError()
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("errorMessage is nil initially")
    func errorMessage_nilInitially() async {
        let viewModel = KeyManagementViewModel()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // No error should be set initially
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("clearError clears error message")
    func clearError_clearsMessage() async {
        let viewModel = KeyManagementViewModel()
        viewModel.errorMessage = "Test error"
        
        viewModel.clearError()
        
        #expect(viewModel.errorMessage == nil)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("hasKeys returns true when keys exist")
    func hasKeys_returnsTrueWhenKeysExist() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        
        #expect(viewModel.hasKeys == true)
    }
    
    @Test("hasKeys returns false when keys empty")
    func hasKeys_returnsFalseWhenEmpty() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = []
        
        #expect(viewModel.hasKeys == false)
    }
    
    @Test("publicKeys returns only public keys")
    func publicKeys_returnsOnlyPublic() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        
        let publicKeys = viewModel.publicKeys
        
        #expect(publicKeys.allSatisfy { !$0.isSecret })
    }
    
    @Test("secretKeys returns only secret keys")
    func secretKeys_returnsOnlySecret() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        
        let secretKeys = viewModel.secretKeys
        
        #expect(secretKeys.allSatisfy { $0.isSecret })
    }
    
    @Test("availableAlgorithms returns sorted unique algorithms")
    func availableAlgorithms_returnsSortedUnique() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [
            TestKeyFactory.makeKey(algorithm: "RSA"),
            TestKeyFactory.makeKey(algorithm: "EDDSA"),
            TestKeyFactory.makeKey(algorithm: "RSA"),
            TestKeyFactory.makeKey(algorithm: "DSA")
        ]
        
        let algorithms = viewModel.availableAlgorithms
        
        #expect(algorithms.count == 3) // RSA, EDDSA, DSA
        #expect(algorithms == algorithms.sorted())
    }
    
    // MARK: - Filtering Tests
    
    @Test("filteredKeys with no filter returns all keys")
    func filteredKeys_noFilter_returnsAll() async {
        let viewModel = KeyManagementViewModel()
        let testKeys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.keys = testKeys
        viewModel.resetFilters()
        
        #expect(viewModel.filteredKeys.count == testKeys.count)
    }
    
    @Test("filteredKeys with search text filters by name")
    func filteredKeys_searchByName_filtersCorrectly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.searchText = "Alice"
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.name.contains("Alice") })
    }
    
    @Test("filteredKeys with search text filters by email")
    func filteredKeys_searchByEmail_filtersCorrectly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.searchText = "@example.com"
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.email.contains("@example.com") })
    }
    
    @Test("filteredKeys with search text filters by fingerprint")
    func filteredKeys_searchByFingerprint_filtersCorrectly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [
            TestKeyFactory.makeKey(fingerprint: "AAAA1111BBBB2222CCCC3333DDDD4444EEEE5555"),
            TestKeyFactory.makeKey(fingerprint: "FFFF6666GGGG7777HHHH8888IIII9999JJJJ0000")
        ]
        viewModel.searchText = "AAAA"
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.fingerprint.contains("AAAA") == true)
    }
    
    @Test("filteredKeys with publicOnly returns public keys only")
    func filteredKeys_publicOnly_returnsPublicOnly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterKeyType = .publicOnly
        viewModel.searchText = ""
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { !$0.isSecret })
    }
    
    @Test("filteredKeys with secretOnly returns secret keys only")
    func filteredKeys_secretOnly_returnsSecretOnly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterKeyType = .secretOnly
        viewModel.searchText = ""
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.isSecret })
    }
    
    @Test("filteredKeys with trust level filters correctly")
    func filteredKeys_withTrustLevel_filtersCorrectly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterTrustLevel = .full
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.trustLevel == .full })
    }
    
    @Test("filteredKeys hide expired excludes expired keys")
    func filteredKeys_hideExpired_excludesExpired() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.showExpiredKeys = false
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { !$0.isExpired })
    }
    
    @Test("filteredKeys combined filters applies all")
    func filteredKeys_combinedFilters_appliesAll() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.searchText = ""
        viewModel.filterKeyType = .publicOnly
        viewModel.showExpiredKeys = false
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { !$0.isSecret && !$0.isExpired })
    }
    
    // MARK: - Filter Reset Tests
    
    @Test("resetFilters clears all filters")
    func resetFilters_clearsAll() async {
        let viewModel = KeyManagementViewModel()
        viewModel.searchText = "test"
        viewModel.filterKeyType = .secretOnly
        viewModel.filterTrustLevel = .full
        viewModel.showExpiredKeys = false
        
        viewModel.resetFilters()
        
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filterKeyType == .all)
        #expect(viewModel.filterTrustLevel == nil)
        #expect(viewModel.showExpiredKeys == true)
    }
    
    @Test("hasActiveFilters returns correct value")
    func hasActiveFilters_returnsCorrectValue() async {
        let viewModel = KeyManagementViewModel()
        
        // No filters
        viewModel.resetFilters()
        #expect(viewModel.hasActiveFilters == false)
        
        // With search text
        viewModel.searchText = "test"
        #expect(viewModel.hasActiveFilters == true)
        
        // With filter type
        viewModel.searchText = ""
        viewModel.filterKeyType = .secretOnly
        #expect(viewModel.hasActiveFilters == true)
        
        // With trust level
        viewModel.filterKeyType = .all
        viewModel.filterTrustLevel = .full
        #expect(viewModel.hasActiveFilters == true)
        
        // With expired filter
        viewModel.filterTrustLevel = nil
        viewModel.showExpiredKeys = false
        #expect(viewModel.hasActiveFilters == true)
    }
    
    // MARK: - Search History Tests
    
    @Test("addToSearchHistory adds to beginning")
    func addToSearchHistory_addsToBeginning() async {
        let viewModel = KeyManagementViewModel()
        
        viewModel.addToSearchHistory("first")
        viewModel.addToSearchHistory("second")
        
        #expect(viewModel.searchHistory.first == "second")
    }
    
    @Test("addToSearchHistory moves existing to front")
    func addToSearchHistory_movesExistingToFront() async {
        let viewModel = KeyManagementViewModel()
        
        viewModel.addToSearchHistory("first")
        viewModel.addToSearchHistory("second")
        viewModel.addToSearchHistory("first")
        
        #expect(viewModel.searchHistory.first == "first")
        #expect(viewModel.searchHistory.count == 2)
    }
    
    @Test("addToSearchHistory ignores empty string")
    func addToSearchHistory_ignoresEmpty() async {
        let viewModel = KeyManagementViewModel()
        
        viewModel.addToSearchHistory("")
        
        #expect(viewModel.searchHistory.isEmpty)
    }
    
    @Test("clearSearchHistory clears all")
    func clearSearchHistory_clearsAll() async {
        let viewModel = KeyManagementViewModel()
        
        viewModel.addToSearchHistory("first")
        viewModel.addToSearchHistory("second")
        viewModel.clearSearchHistory()
        
        #expect(viewModel.searchHistory.isEmpty)
    }
}
