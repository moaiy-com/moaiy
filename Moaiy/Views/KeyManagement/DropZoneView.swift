//
//  DropZoneView.swift
//  Moaiy
//
//  Drop zone component for file encryption/decryption
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    var onDrop: (([URL]) -> Void)?
    
 let isTargeted: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.gray.opacity(0.5), lineWidth: 2)
            .frame(height: 80)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.app")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("drop_zone_hint")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: true) { providers in
                guard let onDrop = onDrop else { return }
            let urls = providers.compactMap { $0.url }
            onDrop?(urls)
        }
    }
}

 .cornerRadius(8)
            .clipShape(.rect(cornerRadius: 8)
            .frame(maxWidth: .infinity)
        }
    }
}