//
//  OperationResultOverlay.swift
//  Moaiy
//
//  Overlay component for displaying operation results (encrypt/decrypt/etc)
//

import SwiftUI

struct OperationResultOverlay: View {
    let results: [OperationResult]
    let onDismiss: () -> Void
    let onOpenInFinder: ((URL) -> Void)?
    
    @State private var isAnimating = false
    
    private var summary: BatchOperationSummary {
        BatchOperationSummary(results: results)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            resultsListView
            Divider()
            footerView
        }
        .frame(width: 400)
        .frame(maxHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
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
                    .foregroundStyle(.green)
                Text("operation_all_succeeded")
                    .font(.headline)
            } else if summary.allFailed {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text("operation_all_failed")
                    .font(.headline)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("operation_partial_success")
                    .font(.headline)
            }
            
            Spacer()
            
            Text("\(summary.successCount)/\(results.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(results) { result in
                    ResultRowView(
                        result: result,
                        onOpenInFinder: onOpenInFinder
                    )
                }
            }
            .padding()
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
            
            Button("dismiss") {
                withAnimation {
                    onDismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding()
    }
}

struct ResultRowView: View {
    let result: OperationResult
    let onOpenInFinder: ((URL) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.operation.iconName)
                .font(.title3)
                .foregroundStyle(result.success ? result.operation.iconColor : .red)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(result.message)
                    .font(.caption)
                    .foregroundStyle(result.success ? Color.secondary : Color.red)
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(result.success ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
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
                errorMessage: "No secret key available"
            )
        ],
        onDismiss: {},
        onOpenInFinder: { _ in }
    )
}
