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
                    let item = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                    if let url = resolvedURL(from: item) {
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

    private func resolvedURL(from item: NSSecureCoding?) -> URL? {
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let url = item as? URL {
            return url
        }
        if let nsURL = item as? NSURL {
            return nsURL as URL
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }
}

#Preview {
    KeyDropZoneView()
        .frame(width: 300, height: 100)
}
