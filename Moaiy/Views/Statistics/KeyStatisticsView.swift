//
//  KeyStatisticsView.swift
//  Moaiy
//
//  Key usage statistics and analytics
//

import SwiftUI

struct KeyStatisticsView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("statistics_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("statistics_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Overview cards
                    HStack(spacing: 16) {
                        StatCard(
                            title: "statistics_total_keys",
                            value: "\(viewModel.keys.count)",
                            icon: "key.fill",
                            color: .blue
                        )

                        StatCard(
                            title: "statistics_secret_keys",
                            value: "\(viewModel.secretKeys.count)",
                            icon: "key.viewfinder",
                            color: Color.moiayAccent
                        )

                        StatCard(
                            title: "statistics_trusted",
                            value: "\(trustedKeysCount)",
                            icon: "checkmark.seal.fill",
                            color: .green
                        )
                    }

                    // Algorithm distribution
                    VStack(alignment: .leading, spacing: 12) {
                        Text("statistics_algorithm_distribution")
                            .font(.headline)

                        ForEach(algorithmStats.sorted(by: { $0.value > $1.value }), id: \.key) { algorithm, count in
                            HStack {
                                Text(algorithm)
                                    .font(.subheadline)

                                Spacer()

                                Text("\(count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)

                                Text("(\(Int(Double(count) / Double(viewModel.keys.count) * 100))%)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)

                            ProgressView(value: Double(count), total: Double(viewModel.keys.count))
                                .tint(.blue)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Trust level distribution
                    VStack(alignment: .leading, spacing: 12) {
                        Text("statistics_trust_distribution")
                            .font(.headline)

                        ForEach(TrustLevel.allCases, id: \.self) { level in
                            let count = trustLevelStats[level] ?? 0
                            if count > 0 {
                                HStack {
                                    Image(systemName: trustIcon(for: level))
                                        .foregroundStyle(trustColor(for: level))
                                        .frame(width: 20)

                                    Text(level.localizedName)
                                        .font(.subheadline)

                                    Spacer()

                                    Text("\(count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Expiration status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("statistics_expiration_status")
                            .font(.headline)

                        HStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                                Text("\(expiredKeysCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("statistics_expired")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.title)
                                    .foregroundStyle(.orange)
                                Text("\(expiringSoonCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("statistics_expiring_soon")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(spacing: 8) {
                                Image(systemName: "infinity")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                Text("\(neverExpireCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("statistics_no_expiration")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Recent activity (placeholder)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("statistics_recent_activity")
                                .font(.headline)

                            Spacer()

                            Text("statistics_last_30_days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 12) {
                            ActivityRow(
                                icon: "plus.circle.fill",
                                color: .green,
                                title: "statistics_keys_created",
                                value: "0"
                            )

                            ActivityRow(
                                icon: "square.and.arrow.down.fill",
                                color: .blue,
                                title: "statistics_keys_imported",
                                value: "0"
                            )

                            ActivityRow(
                                icon: "signature",
                                color: Color.moiayAccent,
                                title: "statistics_keys_signed",
                                value: "0"
                            )
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Info
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)

                        Text("statistics_info")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(24)
            }
        }
        .frame(width: 700, height: 800)
    }

    // MARK: - Computed Properties

    private var trustedKeysCount: Int {
        viewModel.keys.filter { $0.trustLevel == .full || $0.trustLevel == .ultimate }.count
    }

    private var algorithmStats: [String: Int] {
        var stats: [String: Int] = [:]
        for key in viewModel.keys {
            stats[key.algorithm, default: 0] += 1
        }
        return stats
    }

    private var trustLevelStats: [TrustLevel: Int] {
        var stats: [TrustLevel: Int] = [:]
        for key in viewModel.keys {
            stats[key.trustLevel, default: 0] += 1
        }
        return stats
    }

    private var expiredKeysCount: Int {
        viewModel.keys.filter { $0.isExpired }.count
    }

    private var expiringSoonCount: Int {
        viewModel.keys.filter { key in
            guard let expiresAt = key.expiresAt else { return false }
            let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            return !key.isExpired && expiresAt < thirtyDaysFromNow
        }.count
    }

    private var neverExpireCount: Int {
        viewModel.keys.filter { $0.expiresAt == nil }.count
    }

    // MARK: - Helper Functions

    private func trustIcon(for level: TrustLevel) -> String {
        switch level {
        case .ultimate: return "checkmark.seal.fill"
        case .full: return "checkmark.circle.fill"
        case .marginal: return "questionmark.circle.fill"
        case .none: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private func trustColor(for level: TrustLevel) -> Color {
        switch level {
        case .ultimate: return .green
        case .full: return .blue
        case .marginal: return .orange
        case .none: return .red
        case .unknown: return .secondary
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ActivityRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Statistics") {
    KeyStatisticsView()
        .environment(KeyManagementViewModel())
}
