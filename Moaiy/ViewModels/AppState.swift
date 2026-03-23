//
//  AppState.swift
//  Moaiy
//
//  Shared application state for dependency injection
//

import Foundation

/// Shared application state container for dependency injection
@MainActor
@Observable
final class AppState {
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    // MARK: - Shared ViewModels
    
    /// Shared key management view model
    let keyManagement = KeyManagementViewModel()
    
    // MARK: - Initialization
    
    private init() {}
}
