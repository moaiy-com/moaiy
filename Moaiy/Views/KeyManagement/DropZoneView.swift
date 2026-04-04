//
//  DropZoneView.swift
//  Moaiy
//
//  Drop zone component for file encryption/decryption
//

import SwiftUI
import UniformTypeIdentifiers

struct KeyDropZoneView: View {
    var hintTextKey: LocalizedStringKey = "drop_zone_hint"
    var onDrop: (([URL]) -> Void)?
    var onTap: (() -> Void)?
    @State private var isTargeted = false
    @State private var isProcessing = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: MoaiyUI.Radius.md, style: .continuous)
            .fill(isTargeted ? Color.moaiyAccentV2.opacity(0.08) : Color.moaiySurfaceSecondary.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: MoaiyUI.Radius.md, style: .continuous)
                    .stroke(
                        isTargeted ? Color.moaiyFocusRing : Color.moaiyBorderPrimary.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                    )
            )
            .frame(height: 52)
            .overlay {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color.moaiyAccentV2)
                } else {
                    HStack(spacing: MoaiyUI.Spacing.sm) {
                        Image(systemName: "arrow.down.doc.on.clip")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isTargeted ? Color.moaiyAccentV2 : Color.moaiyTextSecondary)
                        Text(hintTextKey)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isTargeted ? Color.moaiyTextPrimary : Color.moaiyTextSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, MoaiyUI.Spacing.md)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleFileDrop(providers: providers)
                return true
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                guard !isProcessing else { return }
                onTap?()
            }
            .animation(.easeOut(duration: MoaiyUI.animationFast), value: isTargeted)
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
