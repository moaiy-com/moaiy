//
//  Key.swift
//  Moaiy
//
//  GPG Key model
//

import Foundation

struct Key: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let email: String
    let type: String
    let createdAt: Date = Date()
    let fingerprint: String = ""
    let expiresAt: Date?
    
    init(name: String, email: String, type: String, expiresAt: Date? = nil) {
        self.name = name
        self.email = email
        self.type = type
        self.expiresAt = expiresAt
    }
}

// MARK: - Sample Data

extension Key {
    static let samples: [Key] = [
        Key(name: "Work Key", email: "work@example.com", type: "RSA-4096"),
        Key(name: "Personal Key", email: "personal@example.com", type: "RSA-4096"),
        Key(name: "GitHub Key", email: "github@example.com", type: "ECC (Curve25519)")
    ]
}
