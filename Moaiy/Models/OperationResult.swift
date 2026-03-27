//
//  OperationResult.swift
//  Moaiy
//
//  Result model for GPG operations (encrypt, decrypt, sign, verify, import)
//

import Foundation
import SwiftUI

enum OperationType: String, Codable {
    case encrypt
    case decrypt
    case sign
    case verify
    case `import`
    case export
    case backup
    
    var localizedName: LocalizedStringKey {
        switch self {
        case .encrypt: return "operation_type_encrypt"
        case .decrypt: return "operation_type_decrypt"
        case .sign: return "operation_type_sign"
        case .verify: return "operation_type_verify"
        case .import: return "operation_type_import"
        case .export: return "operation_type_export"
        case .backup: return "operation_type_backup"
        }
    }
    
    var iconName: String {
        switch self {
        case .encrypt: return "lock.fill"
        case .decrypt: return "lock.open.fill"
        case .sign: return "signature"
        case .verify: return "checkmark.seal.fill"
        case .import: return "square.and.arrow.down"
        case .export: return "square.and.arrow.up"
        case .backup: return "externaldrive.fill.badge.icloud"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .encrypt: return .blue
        case .decrypt: return .green
        case .sign: return .purple
        case .verify: return .orange
        case .import: return .cyan
        case .export: return .indigo
        case .backup: return .brown
        }
    }
}

struct OperationResult: Identifiable, Hashable {
    let id = UUID()
    let fileURL: URL
    let success: Bool
    let operation: OperationType
    let message: String
    let outputURL: URL?
    let timestamp: Date
    
    init(
        fileURL: URL,
        success: Bool,
        operation: OperationType,
        message: String,
        outputURL: URL? = nil
    ) {
        self.fileURL = fileURL
        self.success = success
        self.operation = operation
        self.message = message
        self.outputURL = outputURL
        self.timestamp = Date()
    }
    
    var fileName: String {
        fileURL.lastPathComponent
    }
    
    var outputFileName: String? {
        outputURL?.lastPathComponent
    }
    
    static func successEncrypt(fileURL: URL, outputURL: URL? = nil) -> OperationResult {
        OperationResult(fileURL: fileURL, success: true, operation: .encrypt, message: "operation_encrypt_success", outputURL: outputURL)
    }
    
    static func successDecrypt(fileURL: URL, outputURL: URL? = nil) -> OperationResult {
        OperationResult(fileURL: fileURL, success: true, operation: .decrypt, message: "operation_decrypt_success", outputURL: outputURL)
    }
    
    static func failure(fileURL: URL, operation: OperationType, errorMessage: String) -> OperationResult {
        OperationResult(fileURL: fileURL, success: false, operation: operation, message: errorMessage)
    }
    
    static func == (lhs: OperationResult, rhs: OperationResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct BatchOperationSummary {
    let results: [OperationResult]
    let startTime: Date
    let endTime: Date
    
    var successCount: Int {
        results.filter { $0.success }.count
    }
    
    var failureCount: Int {
        results.filter { !$0.success }.count
    }
    
    var allSucceeded: Bool {
        failureCount == 0
    }
    
    var allFailed: Bool {
        successCount == 0
    }
    
    var hasMixedResults: Bool {
        successCount > 0 && failureCount > 0
    }
    
    init(results: [OperationResult]) {
        self.results = results
        self.startTime = results.first?.timestamp ?? Date()
        self.endTime = results.last?.timestamp ?? Date()
    }
}
