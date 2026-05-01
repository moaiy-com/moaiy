import AppKit
import SwiftUI

enum BatchGovernanceOperationOption: String, CaseIterable, Identifiable, Sendable {
    case ownerTrust
    case revocationCertificate

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .ownerTrust:
            return "pro_batch_governance_operation_ownertrust"
        case .revocationCertificate:
            return "pro_batch_governance_operation_revocation"
        }
    }
}

enum BatchGovernanceOwnerTrustOption: String, CaseIterable, Identifiable, Sendable {
    case none
    case marginal
    case full
    case ultimate

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .none:
            return "trust_level_none"
        case .marginal:
            return "trust_level_marginal"
        case .full:
            return "trust_level_full"
        case .ultimate:
            return "trust_level_ultimate"
        }
    }
}

enum BatchGovernanceRevocationReasonOption: String, CaseIterable, Identifiable, Sendable {
    case noLongerUsed
    case keyCompromised
    case keyReplaced
    case userIDInvalid

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .noLongerUsed:
            return "revocation_reason_no_longer_used"
        case .keyCompromised:
            return "revocation_reason_key_compromised"
        case .keyReplaced:
            return "revocation_reason_key_replaced"
        case .userIDInvalid:
            return "revocation_reason_user_id_invalid"
        }
    }
}

struct BatchGovernanceExecutionRequest: Sendable, Equatable {
    let operation: BatchGovernanceOperationOption
    let targets: [String]
    let ownerTrust: BatchGovernanceOwnerTrustOption
    let revocationReason: BatchGovernanceRevocationReasonOption
    let revocationDescription: String
    let passphrase: String?

    var metadata: [String: String] {
        [
            "batch.operation": operation.rawValue,
            "batch.targets": targets.joined(separator: "\n"),
            "batch.ownerTrust": ownerTrust.rawValue,
            "batch.revocationReason": revocationReason.rawValue,
            "batch.revocationDescription": revocationDescription,
            "batch.passphrase": passphrase ?? ""
        ]
    }
}

struct BatchGovernanceExecutionReceipt: Sendable, Equatable {
    let titleKey: String
    let messageKey: String
    let metadata: [String: String]

    var totalTargets: Int {
        Int(metadata["batch.receipt.total"] ?? "") ?? 0
    }

    var succeededTargets: Int {
        Int(metadata["batch.receipt.succeeded"] ?? "") ?? 0
    }

    var failedTargets: Int {
        Int(metadata["batch.receipt.failed"] ?? "") ?? 0
    }

    var artifactCount: Int {
        Int(metadata["batch.receipt.artifacts"] ?? "") ?? 0
    }

    var outputDirectoryPath: String? {
        let path = metadata["batch.receipt.outputDirectory"]
        if let path, !path.isEmpty {
            return path
        }
        return nil
    }
}

struct BatchGovernanceSheet: View {
    let key: GPGKey
    let onExecute: @Sendable (BatchGovernanceExecutionRequest) async -> BatchGovernanceExecutionReceipt

    @Environment(\.dismiss) private var dismiss

    @State private var operation: BatchGovernanceOperationOption = .ownerTrust
    @State private var ownerTrust: BatchGovernanceOwnerTrustOption = .full
    @State private var revocationReason: BatchGovernanceRevocationReasonOption = .noLongerUsed
    @State private var targetsInput = ""
    @State private var revocationDescription = ""
    @State private var passphrase = ""
    @State private var isRunning = false
    @State private var validationMessageKey: String?
    @State private var receipt: BatchGovernanceExecutionReceipt?

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("pro_batch_governance_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text("pro_batch_governance_description")
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.lg) {
                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                        Picker("pro_batch_governance_operation_title", selection: $operation) {
                            ForEach(BatchGovernanceOperationOption.allCases) { option in
                                Text(LocalizedStringKey(option.titleKey))
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("pro_batch_governance_targets_title")
                            .font(.subheadline)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        TextEditor(text: $targetsInput)
                            .frame(minHeight: 140)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.moaiyBorderPrimary.opacity(0.8), lineWidth: 1)
                            )

                        Text("pro_batch_governance_targets_hint")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)

                        if operation == .ownerTrust {
                            Picker("pro_batch_governance_ownertrust_title", selection: $ownerTrust) {
                                ForEach(BatchGovernanceOwnerTrustOption.allCases) { option in
                                    Text(LocalizedStringKey(option.titleKey))
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            Picker("pro_batch_governance_revocation_reason_title", selection: $revocationReason) {
                                ForEach(BatchGovernanceRevocationReasonOption.allCases) { option in
                                    Text(LocalizedStringKey(option.titleKey))
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.menu)

                            TextField("pro_batch_governance_revocation_note_placeholder", text: $revocationDescription)
                                .textFieldStyle(.roundedBorder)

                            SecureField("pro_batch_governance_passphrase_placeholder", text: $passphrase)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: MoaiyUI.Spacing.sm) {
                            Button("action_cancel") {
                                dismiss()
                            }
                            .buttonStyle(.bordered)

                            Button(action: executeBatchGovernance) {
                                if isRunning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("action_pro_batch_governance_execute")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.moaiyAccentV2)
                            .disabled(isRunning)
                        }
                    }
                    .padding(MoaiyUI.Spacing.md)
                    .moaiyCardStyle()

                    if let validationMessageKey {
                        Text(LocalizedStringKey(validationMessageKey))
                            .font(.subheadline)
                            .foregroundStyle(Color.moaiyError)
                            .padding(MoaiyUI.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .moaiyBannerStyle(tint: Color.moaiyError)
                    }

                    if let receipt {
                        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
                            Text("pro_batch_governance_receipt_title")
                                .font(.headline)

                            Text(LocalizedStringKey(receipt.messageKey))
                                .font(.subheadline)
                                .foregroundStyle(
                                    receipt.failedTargets == 0
                                        ? Color.moaiySuccess
                                        : Color.moaiyWarning
                                )

                            receiptMetricRow(
                                titleKey: "pro_batch_governance_receipt_total",
                                value: receipt.totalTargets
                            )
                            receiptMetricRow(
                                titleKey: "pro_batch_governance_receipt_success",
                                value: receipt.succeededTargets
                            )
                            receiptMetricRow(
                                titleKey: "pro_batch_governance_receipt_failure",
                                value: receipt.failedTargets
                            )

                            if operation == .revocationCertificate {
                                receiptMetricRow(
                                    titleKey: "pro_batch_governance_receipt_artifacts",
                                    value: receipt.artifactCount
                                )
                            }

                            if let outputDirectoryPath = receipt.outputDirectoryPath {
                                Text(outputDirectoryPath)
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                                    .textSelection(.enabled)

                                Button("pro_batch_governance_receipt_open_folder") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: outputDirectoryPath, isDirectory: true))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(MoaiyUI.Spacing.md)
                        .moaiyCardStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(MoaiyUI.Spacing.xxl)
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(
            minWidth: 560,
            idealWidth: 720,
            maxWidth: 860,
            minHeight: 520,
            idealHeight: 680,
            maxHeight: 860
        )
        .task {
            if targetsInput.isEmpty {
                targetsInput = key.fingerprint
            }
        }
    }

    private func executeBatchGovernance() {
        let parsedTargets = parseTargets(from: targetsInput)
        guard !parsedTargets.isEmpty else {
            validationMessageKey = "pro_batch_governance_validation_targets_required"
            return
        }

        validationMessageKey = nil
        isRunning = true

        let request = BatchGovernanceExecutionRequest(
            operation: operation,
            targets: parsedTargets,
            ownerTrust: ownerTrust,
            revocationReason: revocationReason,
            revocationDescription: revocationDescription,
            passphrase: passphrase.isEmpty ? nil : passphrase
        )

        Task {
            let result = await onExecute(request)
            await MainActor.run {
                receipt = result
                isRunning = false
            }
        }
    }

    private func parseTargets(from source: String) -> [String] {
        var deduped: [String] = []
        var seen: Set<String> = []
        let separators = CharacterSet(charactersIn: ",;\n")
        for token in source.components(separatedBy: separators) {
            let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                deduped.append(normalized)
            }
        }
        return deduped
    }

    @ViewBuilder
    private func receiptMetricRow(titleKey: String, value: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(Color.moaiyTextSecondary)
            Spacer()
            Text("\(value)")
                .foregroundStyle(Color.moaiyTextPrimary)
        }
        .font(.subheadline)
    }
}
