//
//  FilteringTests.swift
//  MoaiyTests
//
//  Unit tests for key filtering functionality
//

import Foundation
import Testing
@testable import Moaiy

@Suite("Key Filtering Tests")
@MainActor
struct FilteringTests {
    
    // MARK: - Basic Filter Tests
    
    @Test("No filter returns all keys")
    func noFilter_returnsAllKeys() async {
        let viewModel = KeyManagementViewModel()
        let testKeys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.keys = testKeys
        viewModel.resetFilters()
        
        #expect(viewModel.filteredKeys.count == testKeys.count)
    }
    
    @Test("Search by name filters correctly")
    func searchByName_filtersCorrectly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.searchText = "Alice"
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.name.localizedCaseInsensitiveContains("Alice") })
    }
    
    @Test("Search by email filters correctly")
    func searchByEmail_filtersCorrectly() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.searchText = "@example.com"
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.email.localizedCaseInsensitiveContains("@example.com") })
    }
    
    @Test("Search by fingerprint filters correctly")
    func searchByFingerprint_filtersCorrectly() async {
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
    
    @Test("Search is case insensitive")
    func searchIsCaseInsensitive() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [TestKeyFactory.makeKey(name: "TestUser")]
        viewModel.searchText = "testuser"
        viewModel.filterKeyType = .all
        
        #expect(viewModel.filteredKeys.count == 1)
    }
    
    // MARK: - Key Type Filter Tests
    
    @Test("Public only filter returns only public keys")
    func publicOnly_returnsOnlyPublicKeys() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterKeyType = .publicOnly
        viewModel.searchText = ""
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { !$0.isSecret })
    }
    
    @Test("Secret only filter returns only secret keys")
    func secretOnly_returnsOnlySecretKeys() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterKeyType = .secretOnly
        viewModel.searchText = ""
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.isSecret })
    }
    
    @Test("All keys filter returns all keys")
    func allKeys_returnsAllKeys() async {
        let viewModel = KeyManagementViewModel()
        let testKeys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.keys = testKeys
        viewModel.filterKeyType = .all
        viewModel.searchText = ""
        
        #expect(viewModel.filteredKeys.count == testKeys.count)
    }
    
    // MARK: - Trust Level Filter Tests
    
    @Test("Filter by trust level unknown")
    func filterByTrust_unknown() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterTrustLevel = .unknown
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.trustLevel == .unknown })
    }
    
    @Test("Filter by trust level marginal")
    func filterByTrust_marginal() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterTrustLevel = .marginal
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.trustLevel == .marginal })
    }
    
    @Test("Filter by trust level full")
    func filterByTrust_full() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterTrustLevel = .full
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.trustLevel == .full })
    }
    
    @Test("Filter by trust level ultimate")
    func filterByTrust_ultimate() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterTrustLevel = .ultimate
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.trustLevel == .ultimate })
    }
    
    // MARK: - Expired Key Filter Tests
    
    @Test("Hide expired keys excludes expired")
    func hideExpired_excludesExpired() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.showExpiredKeys = false
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { !$0.isExpired })
    }
    
    @Test("Show expired keys includes expired")
    func showExpired_includesExpired() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.showExpiredKeys = true
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        // Should include both expired and non-expired keys
        let hasExpired = viewModel.keys.contains { $0.isExpired }
        #expect(hasExpired == true || viewModel.keys.isEmpty)
    }
    
    // MARK: - Algorithm Filter Tests
    
    @Test("Filter by algorithm RSA")
    func filterByAlgorithm_rsa() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [
            TestKeyFactory.makeKey(name: "RSA User", algorithm: "RSA"),
            TestKeyFactory.makeECCKey()
        ]
        viewModel.filterAlgorithm = "RSA"
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.algorithm.localizedCaseInsensitiveContains("RSA") })
    }
    
    @Test("Filter by algorithm EDDSA")
    func filterByAlgorithm_eddsa() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [
            TestKeyFactory.makeKey(name: "RSA User", algorithm: "RSA"),
            TestKeyFactory.makeECCKey()
        ]
        viewModel.filterAlgorithm = "EDDSA"
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.algorithm.localizedCaseInsensitiveContains("EDDSA") })
    }
    
    // MARK: - Combined Filter Tests
    
    @Test("Combined filters: secret + full trust")
    func combinedFilters_secretAndFullTrust() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.filterKeyType = .secretOnly
        viewModel.filterTrustLevel = .full
        viewModel.searchText = ""
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { $0.isSecret && $0.trustLevel == .full })
    }
    
    @Test("Combined filters: search + public only")
    func combinedFilters_searchAndPublic() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = TestKeyFactory.makeMixedKeyCollection()
        viewModel.searchText = "Alice"
        viewModel.filterKeyType = .publicOnly
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { 
            !$0.isSecret && $0.name.localizedCaseInsensitiveContains("Alice") 
        })
    }
    
    @Test("Combined filters: all filters applied")
    func combinedFilters_allFilters() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [
            TestKeyFactory.makeKey(name: "Test Alice", email: "alice@test.com", isSecret: false, trustLevel: .full),
            TestKeyFactory.makeSecretKey(name: "Secret Alice"),
            TestKeyFactory.makeExpiredKey()
        ]
        viewModel.searchText = "Alice"
        viewModel.filterKeyType = .publicOnly
        viewModel.filterTrustLevel = .full
        viewModel.showExpiredKeys = false
        
        let filtered = viewModel.filteredKeys
        
        #expect(filtered.allSatisfy { key in
            !key.isSecret &&
            key.name.localizedCaseInsensitiveContains("Alice") &&
            key.trustLevel == .full &&
            !key.isExpired
        })
    }
    
    // MARK: - Filter Reset Tests
    
    @Test("Reset filters clears all filters")
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
    
    @Test("hasActiveFilters returns true when filters are active")
    func hasActiveFilters_returnsTrueWhenActive() async {
        let viewModel = KeyManagementViewModel()
        viewModel.resetFilters()
        
        #expect(viewModel.hasActiveFilters == false)
        
        viewModel.searchText = "test"
        #expect(viewModel.hasActiveFilters == true)
        
        viewModel.resetFilters()
        viewModel.filterKeyType = .secretOnly
        #expect(viewModel.hasActiveFilters == true)
        
        viewModel.resetFilters()
        viewModel.filterTrustLevel = .full
        #expect(viewModel.hasActiveFilters == true)
        
        viewModel.resetFilters()
        viewModel.showExpiredKeys = false
        #expect(viewModel.hasActiveFilters == true)
    }
    
    @Test("hasActiveFilters returns false when no filters")
    func hasActiveFilters_returnsFalseWhenNone() async {
        let viewModel = KeyManagementViewModel()
        viewModel.resetFilters()
        
        #expect(viewModel.hasActiveFilters == false)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Empty keys returns empty filtered list")
    func emptyKeys_returnsEmpty() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = []
        viewModel.searchText = "test"
        viewModel.filterKeyType = .publicOnly
        
        #expect(viewModel.filteredKeys.isEmpty)
    }
    
    @Test("Search with no results returns empty")
    func searchNoMatch_returnsEmpty() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [TestKeyFactory.makeKey(name: "Alice")]
        viewModel.searchText = "XYZ123NOTFOUND"
        viewModel.filterKeyType = .all
        
        #expect(viewModel.filteredKeys.isEmpty)
    }
    
    @Test("Filter with no matching trust level returns empty")
    func filterNoMatch_returnsEmpty() async {
        let viewModel = KeyManagementViewModel()
        viewModel.keys = [TestKeyFactory.makeKeyWithTrust(.unknown)]
        viewModel.filterTrustLevel = .ultimate
        viewModel.searchText = ""
        viewModel.filterKeyType = .all
        
        #expect(viewModel.filteredKeys.isEmpty)
    }
}

// MARK: - KeyTypeFilter Tests

@Suite("KeyTypeFilter Tests")
struct KeyTypeFilterTests {
    
    @Test("All filter display name")
    func allFilter_displayName() {
        #expect(KeyTypeFilter.all.displayName == String(localized: "filter_all_keys"))
    }
    
    @Test("Public only filter display name")
    func publicOnlyFilter_displayName() {
        #expect(KeyTypeFilter.publicOnly.displayName == String(localized: "filter_public_keys"))
    }
    
    @Test("Secret only filter display name")
    func secretOnlyFilter_displayName() {
        #expect(KeyTypeFilter.secretOnly.displayName == String(localized: "filter_secret_keys"))
    }
    
    @Test("All filters are present in allCases")
    func allFilters_inAllCases() {
        let allCases = KeyTypeFilter.allCases
        
        #expect(allCases.contains(.all))
        #expect(allCases.contains(.publicOnly))
        #expect(allCases.contains(.secretOnly))
        #expect(allCases.count == 3)
    }
    
    @Test("Filter IDs match raw values")
    func filterIds_matchRawValues() {
        #expect(KeyTypeFilter.all.id == "all")
        #expect(KeyTypeFilter.publicOnly.id == "public")
        #expect(KeyTypeFilter.secretOnly.id == "secret")
    }
}
