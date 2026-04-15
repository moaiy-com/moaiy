//
//  OperationResultOverlay.swift
//  Moaiy
//
//  Overlay component for displaying operation results (encrypt/decrypt/etc)
//

import SwiftUI

struct OperationResultOverlay: View {
    let results: [OperationResult]
    let preferredOperation: OperationType?
    let onDismiss: () -> Void
    let onOpenInFinder: ((URL) -> Void)?
    
    @State private var isAnimating = false
    
    private var summary: BatchOperationSummary {
        BatchOperationSummary(results: results)
    }
    
    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.md) {
            headerView
            resultsListView
            footerView
        }
        .padding(MoaiyUI.Spacing.lg)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 380, idealWidth: 460, maxWidth: 620, maxHeight: 640)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
        .onAppear {
            withAnimation(.spring(response: 0.3)) {
                isAnimating = true
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            if summary.allSucceeded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.moaiySuccess)
                Text(LocalizedStringKey(summary.headerTitleKey(preferredOperation: preferredOperation)))
                    .font(.headline)
            } else if summary.allFailed {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.moaiyError)
                Text(LocalizedStringKey(summary.headerTitleKey(preferredOperation: preferredOperation)))
                    .font(.headline)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.moaiyWarning)
                Text(LocalizedStringKey(summary.headerTitleKey(preferredOperation: preferredOperation)))
                    .font(.headline)
            }
            
            Spacer()
            
            Text("\(summary.successCount)/\(results.count)")
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextSecondary)
        }
        .padding(MoaiyUI.Spacing.md)
    }
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: MoaiyUI.Spacing.sm) {
                ForEach(results) { result in
                    ResultRowView(
                        result: result,
                        onOpenInFinder: onOpenInFinder
                    )
                }
            }
            .padding(MoaiyUI.Spacing.sm)
        }
        .frame(maxHeight: 300)
    }
    
    private var footerView: some View {
        HStack {
            if let firstSuccess = results.first(where: { $0.success && $0.outputURL != nil }) {
                Button {
                    onOpenInFinder?(firstSuccess.outputURL!.deletingLastPathComponent())
                } label: {
                    Label("open_in_finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button("action_ok") {
                withAnimation {
                    onDismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.moaiyAccentV2)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(MoaiyUI.Spacing.md)
    }
}

struct ResultRowView: View {
    let result: OperationResult
    let onOpenInFinder: ((URL) -> Void)?
    
    var body: some View {
        HStack(spacing: MoaiyUI.Spacing.md) {
            Image(systemName: result.operation.iconName)
                .font(.title3)
                .foregroundStyle(result.success ? result.operation.iconColor : Color.moaiyError)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.subheadline)
                    .foregroundStyle(Color.moaiyTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(result.displayMessage)
                    .font(.caption)
                    .foregroundStyle(result.success ? Color.moaiyTextSecondary : Color.moaiyError)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if result.success, let outputURL = result.outputURL {
                Button {
                    onOpenInFinder?(outputURL.deletingLastPathComponent())
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("open_in_finder")
            }
        }
        .padding(MoaiyUI.Spacing.sm)
        .moaiyBannerStyle(
            tint: result.success ? Color.moaiySuccess : Color.moaiyError,
            cornerRadius: MoaiyUI.Radius.sm
        )
    }
}

#Preview("All Success") {
    OperationResultOverlay(
        results: [
            OperationResult.successEncrypt(
                fileURL: URL(fileURLWithPath: "/Users/test/document.pdf"),
                outputURL: URL(fileURLWithPath: "/Users/test/document.pdf.gpg")
            ),
            OperationResult.successEncrypt(
                fileURL: URL(fileURLWithPath: "/Users/test/image.png"),
                outputURL: URL(fileURLWithPath: "/Users/test/image.png.gpg")
            )
        ],
        preferredOperation: .encrypt,
        onDismiss: {},
        onOpenInFinder: { _ in }
    )
}

#Preview("Mixed Results") {
    OperationResultOverlay(
        results: [
            OperationResult.successEncrypt(
                fileURL: URL(fileURLWithPath: "/Users/test/document.pdf"),
                outputURL: URL(fileURLWithPath: "/Users/test/document.pdf.gpg")
            ),
            OperationResult.failure(
                fileURL: URL(fileURLWithPath: "/Users/test/secret.txt"),
                operation: .decrypt,
                errorMessage: AppLocalization.string("error_decryption_requires_private_key")
            )
        ],
        preferredOperation: nil,
        onDismiss: {},
        onOpenInFinder: { _ in }
    )
}
