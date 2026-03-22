//
//  LoadingOverlay.swift
//  Moaiy
//
//  Loading overlay with progress indicator
//

import SwiftUI

struct LoadingOverlay: View {
    let message: String
    var showProgress: Bool = false
    var progress: Double? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            if let progress = progress, showProgress {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
            } else {
                ProgressView()
                    .scaleEffect(1.2)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        
        VStack(spacing: 40) {
            LoadingOverlay(message: "Encrypting...")
            
            LoadingOverlay(message: "Processing...", showProgress: true, progress: 0.6)
        }
    }
}
