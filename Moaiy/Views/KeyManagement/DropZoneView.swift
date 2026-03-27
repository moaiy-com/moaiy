//
//  DropZoneView.swift
//  Moaiy
//
//  Drop zone component for file encryption/decryption
//

import SwiftUI
import UniformTypeIdentifiers

struct KeyDropZoneView: View {
    var onDrop: (([URL]) -> Void)?
    @State private var isTargeted = false
    @State private var isProcessing = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, dash: [4, 4])
            )
            .frame(height: 60)
            .overlay {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.on.clip")
                            .font(.title3)
                            .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                        Text("drop_zone_hint")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleFileDrop(providers: providers)
                return true
            }
    }
    
    private func handleFileDrop(providers: [NSItemProvider]) {
        guard let onDrop = onDrop else { return }
        
        Task { @MainActor in
            isProcessing = true
            
            var urls: [URL] = []
            
            for provider in providers {
                do {
                    if let url = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL {
                        urls.append(url)
                    }
                } catch {
                    continue
                }
            }
            
            isProcessing = false
            
            if !urls.isEmpty {
                onDrop(urls)
            }
        }
    }
}

#Preview {
    KeyDropZoneView()
        .frame(width: 300, height: 100)
}
