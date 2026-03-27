//
//  Tutorial.swift
//  Moaiy
//
//  Tutorial data model for How To guides
//

import Foundation
import SwiftUI

struct TutorialSection: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringKey
    let icon: String
    let items: [TutorialItem]
    
    static func == (lhs: TutorialSection, rhs: TutorialSection) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TutorialItem: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringKey
    let content: LocalizedStringKey
    let iconName: String
    
    static func == (lhs: TutorialItem, rhs: TutorialItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tutorial Data

enum TutorialData {
    static let sections: [TutorialSection] = [
        TutorialSection(
            id: "basics",
            title: "tutorial_section_basics",
            icon: "books.vertical",
            items: [
                TutorialItem(
                    id: "what_is_gpg",
                    title: "tutorial_what_is_gpg",
                    content: "tutorial_what_is_gpg_content",
                    iconName: "lock.shield"
                ),
                TutorialItem(
                    id: "create_first_key",
                    title: "tutorial_create_first_key",
                    content: "tutorial_create_first_key_content",
                    iconName: "plus.circle"
                ),
                TutorialItem(
                    id: "public_private_keys",
                    title: "tutorial_public_private_keys",
                    content: "tutorial_public_private_keys_content",
                    iconName: "key"
                )
            ]
        ),
        TutorialSection(
            id: "encryption",
            title: "tutorial_section_encryption",
            icon: "lock.fill",
            items: [
                TutorialItem(
                    id: "encrypt_files",
                    title: "tutorial_encrypt_files",
                    content: "tutorial_encrypt_files_content",
                    iconName: "doc.fill"
                ),
                TutorialItem(
                    id: "decrypt_files",
                    title: "tutorial_decrypt_files",
                    content: "tutorial_decrypt_files_content",
                    iconName: "doc.fill.badge.ellipsis"
                )
            ]
        ),
        TutorialSection(
            id: "key_management",
            title: "tutorial_section_key_management",
            icon: "key.fill",
            items: [
                TutorialItem(
                    id: "import_keys",
                    title: "tutorial_import_keys",
                    content: "tutorial_import_keys_content",
                    iconName: "square.and.arrow.down"
                ),
                TutorialItem(
                    id: "export_keys",
                    title: "tutorial_export_keys",
                    content: "tutorial_export_keys_content",
                    iconName: "square.and.arrow.up"
                ),
                TutorialItem(
                    id: "backup_keys",
                    title: "tutorial_backup_keys",
                    content: "tutorial_backup_keys_content",
                    iconName: "externaldrive.fill"
                )
            ]
        ),
        TutorialSection(
            id: "advanced",
            title: "tutorial_section_advanced",
            icon: "gearshape.2",
            items: [
                TutorialItem(
                    id: "trust_management",
                    title: "tutorial_trust_management",
                    content: "tutorial_trust_management_content",
                    iconName: "checkmark.seal"
                ),
                TutorialItem(
                    id: "keyserver",
                    title: "tutorial_keyserver",
                    content: "tutorial_keyserver_content",
                    iconName: "globe"
                )
            ]
        )
    ]
}
