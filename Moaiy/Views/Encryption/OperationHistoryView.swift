//
//  OperationHistoryView.swift
//  Moaiy
//
//  View displaying encryption/decryption operation history
//

import SwiftUI

struct OperationHistoryView: View {
    @Bindable var viewModel: EncryptionViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("history_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !viewModel.operationHistory.isEmpty {
                    Button("action_clear_history", role: .destructive) {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            
            Divider()
            
            if viewModel.operationHistory.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("history_empty_title")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("history_empty_description")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // History list
                List {
                    ForEach(viewModel.operationHistory) { item in
                        OperationHistoryRow(item: item)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Operation History Row

struct OperationHistoryRow: View {
    let item: EncryptionHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.type.icon)
                .font(.title3)
                .foregroundStyle(item.success ? Color.moiaySuccess : Color.moiayError)
                .frame(width: 32, height: 32)
                .background((item.success ? Color.moiaySuccess : Color.moiayError).opacity(0.1))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.type.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !item.success {
                        Text("status_failed")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                
                Text(item.contentPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timestamp
            Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let vm = EncryptionViewModel()
    
    return OperationHistoryView(viewModel: vm)
}
