//
//  KeyStatisticsView.swift
//  Moaiy
//
//  Key usage statistics and analytics
//

import SwiftUI

struct KeyStatisticsView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    private let expiringSoonWindowDays = 30

    var body: some View {
        let snapshot = makeSnapshot()

        VStack(spacing: MoaiyUI.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                    Text("statistics_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.moaiyTextPrimary)
                    Text("statistics_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(Color.moaiyTextSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, MoaiyUI.Spacing.xxl)
            .padding(.top, MoaiyUI.Spacing.xxl)

            ScrollView {
                VStack(spacing: MoaiyUI.Spacing.lg) {
                    HStack(spacing: MoaiyUI.Spacing.md) {
                        StatCard(
                            title: "statistics_total_keys",
                            value: "\(snapshot.totalKeys)",
                            icon: "key.fill",
                            color: Color.moaiyInfo
                        )

                        StatCard(
                            title: "statistics_secret_keys",
                            value: "\(viewModel.secretKeys.count)",
                            icon: "key.viewfinder",
                            color: Color.moaiyAccentV2
                        )

                        StatCard(
                            title: "statistics_trusted",
                            value: "\(snapshot.trustedKeysCount)",
                            icon: "checkmark.seal.fill",
                            color: Color.moaiySuccess
                        )
                    }

                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                        Text("statistics_algorithm_distribution")
                            .font(.headline)
                            .foregroundStyle(Color.moaiyTextPrimary)

                        ForEach(snapshot.sortedAlgorithmStats, id: \.key) { algorithm, count in
                            HStack {
                                Text(algorithm)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.moaiyTextPrimary)

                                Spacer()

                                Text("\(count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.moaiyAccentV2)

                                Text("(\(snapshot.percentage(for: count))%)")
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                            .padding(.vertical, MoaiyUI.Spacing.xs)

                            ProgressView(value: Double(count), total: Double(max(snapshot.totalKeys, 1)))
                                .tint(Color.moaiyAccentV2)
                        }
                    }
                    .padding(MoaiyUI.Spacing.lg)
                    .moaiyCardStyle()

                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                        Text("statistics_trust_distribution")
                            .font(.headline)
                            .foregroundStyle(Color.moaiyTextPrimary)

                        ForEach(TrustLevel.allCases, id: \.self) { level in
                            let count = snapshot.trustLevelStats[level] ?? 0
                            if count > 0 {
                                HStack {
                                    Image(systemName: trustIcon(for: level))
                                        .foregroundStyle(trustColor(for: level))
                                        .frame(width: 20)

                                    Text(level.localizedName)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.moaiyTextPrimary)

                                    Spacer()

                                    Text("\(count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.moaiyTextSecondary)
                                }
                                .padding(.vertical, MoaiyUI.Spacing.xs)
                            }
                        }
                    }
                    .padding(MoaiyUI.Spacing.lg)
                    .moaiyCardStyle()

                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                        Text("statistics_expiration_status")
                            .font(.headline)
                            .foregroundStyle(Color.moaiyTextPrimary)

                        HStack(spacing: MoaiyUI.Spacing.md) {
                            VStack(spacing: MoaiyUI.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.moaiyError)
                                Text("\(snapshot.expiredKeysCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.moaiyTextPrimary)
                                Text("statistics_expired")
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(MoaiyUI.Spacing.md)
                            .moaiyBannerStyle(tint: Color.moaiyError)

                            VStack(spacing: MoaiyUI.Spacing.sm) {
                                Image(systemName: "clock.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.moaiyWarning)
                                Text("\(snapshot.expiringSoonKeysCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.moaiyTextPrimary)
                                Text("statistics_expiring_soon")
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(MoaiyUI.Spacing.md)
                            .moaiyBannerStyle(tint: Color.moaiyWarning)

                            VStack(spacing: MoaiyUI.Spacing.sm) {
                                Image(systemName: "infinity")
                                    .font(.title3)
                                    .foregroundStyle(Color.moaiySuccess)
                                Text("\(snapshot.neverExpireKeysCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.moaiyTextPrimary)
                                Text("statistics_no_expiration")
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(MoaiyUI.Spacing.md)
                            .moaiyBannerStyle(tint: Color.moaiySuccess)
                        }
                    }
                    .padding(MoaiyUI.Spacing.lg)
                    .moaiyCardStyle()

                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                        HStack {
                            Text("statistics_recent_activity")
                                .font(.headline)
                                .foregroundStyle(Color.moaiyTextPrimary)

                            Spacer()

                            Text("statistics_last_30_days")
                                .font(.caption)
                                .foregroundStyle(Color.moaiyTextSecondary)
                        }

                        VStack(spacing: MoaiyUI.Spacing.md) {
                            ActivityRow(
                                icon: "plus.circle.fill",
                                color: Color.moaiySuccess,
                                title: "statistics_keys_created",
                                value: "0"
                            )

                            ActivityRow(
                                icon: "square.and.arrow.down.fill",
                                color: Color.moaiyInfo,
                                title: "statistics_keys_imported",
                                value: "0"
                            )

                            ActivityRow(
                                icon: "signature",
                                color: Color.moaiyAccentV2,
                                title: "statistics_keys_signed",
                                value: "0"
                            )
                        }
                    }
                    .padding(MoaiyUI.Spacing.lg)
                    .moaiyCardStyle()

                    HStack(spacing: MoaiyUI.Spacing.md) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.moaiyInfo)

                        Text("statistics_info")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                    .padding(MoaiyUI.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .moaiyBannerStyle(tint: Color.moaiyInfo)
                }
                .padding(.horizontal, MoaiyUI.Spacing.xxl)
                .padding(.bottom, MoaiyUI.Spacing.xxl)
            }
        }
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(minWidth: 640, idealWidth: 760, maxWidth: 960, minHeight: 620, idealHeight: 780, maxHeight: 980)
    }

    private func makeSnapshot(referenceDate: Date = Date()) -> KeyStatisticsSnapshot {
        KeyStatisticsSnapshot(
            keys: viewModel.keys,
            referenceDate: referenceDate,
            expiringSoonWindowDays: expiringSoonWindowDays
        )
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
        case .ultimate: return Color.moaiySuccess
        case .full: return Color.moaiyInfo
        case .marginal: return Color.moaiyWarning
        case .none: return Color.moaiyError
        case .unknown: return Color.moaiyTextSecondary
        }
    }
}

private struct KeyStatisticsSnapshot {
    let totalKeys: Int
    let trustedKeysCount: Int
    let algorithmStats: [String: Int]
    let sortedAlgorithmStats: [(key: String, value: Int)]
    let trustLevelStats: [TrustLevel: Int]
    let expiredKeysCount: Int
    let expiringSoonKeysCount: Int
    let neverExpireKeysCount: Int

    init(keys: [GPGKey], referenceDate: Date, expiringSoonWindowDays: Int) {
        totalKeys = keys.count

        let expiringSoonDate = Calendar.current.date(
            byAdding: .day,
            value: expiringSoonWindowDays,
            to: referenceDate
        ) ?? .distantFuture

        var trustedKeys = 0
        var expiredKeys = 0
        var expiringSoonKeys = 0
        var neverExpireKeys = 0
        var algorithmCounts: [String: Int] = [:]
        var trustCounts: [TrustLevel: Int] = [:]

        for key in keys {
            if key.trustLevel == .full || key.trustLevel == .ultimate {
                trustedKeys += 1
            }

            algorithmCounts[key.algorithm, default: 0] += 1
            trustCounts[key.trustLevel, default: 0] += 1

            guard let expiresAt = key.expiresAt else {
                neverExpireKeys += 1
                continue
            }

            if expiresAt < referenceDate {
                expiredKeys += 1
                continue
            }

            if expiresAt < expiringSoonDate {
                expiringSoonKeys += 1
            }
        }

        trustedKeysCount = trustedKeys
        algorithmStats = algorithmCounts
        sortedAlgorithmStats = algorithmCounts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            return lhs.value > rhs.value
        }
        trustLevelStats = trustCounts
        expiredKeysCount = expiredKeys
        expiringSoonKeysCount = expiringSoonKeys
        neverExpireKeysCount = neverExpireKeys
    }

    func percentage(for count: Int) -> Int {
        guard totalKeys > 0 else { return 0 }
        return Int(Double(count) / Double(totalKeys) * 100)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: MoaiyUI.Spacing.md) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.moaiyTextPrimary)

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(MoaiyUI.Spacing.lg)
        .moaiyCardStyle()
    }
}

struct ActivityRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: MoaiyUI.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.moaiyTextPrimary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.moaiyTextSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Statistics") {
    KeyStatisticsView()
        .environment(KeyManagementViewModel())
}
