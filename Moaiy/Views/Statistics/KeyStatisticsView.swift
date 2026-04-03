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
                            value: "\(viewModel.keys.count)",
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
                            value: "\(trustedKeysCount)",
                            icon: "checkmark.seal.fill",
                            color: Color.moaiySuccess
                        )
                    }

                    VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
                        Text("statistics_algorithm_distribution")
                            .font(.headline)
                            .foregroundStyle(Color.moaiyTextPrimary)

                        ForEach(algorithmStats.sorted(by: { $0.value > $1.value }), id: \.key) { algorithm, count in
                            HStack {
                                Text(algorithm)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.moaiyTextPrimary)

                                Spacer()

                                Text("\(count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.moaiyAccentV2)

                                Text("(\(Int(Double(count) / Double(viewModel.keys.count) * 100))%)")
                                    .font(.caption)
                                    .foregroundStyle(Color.moaiyTextSecondary)
                            }
                            .padding(.vertical, MoaiyUI.Spacing.xs)

                            ProgressView(value: Double(count), total: Double(viewModel.keys.count))
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
                            let count = trustLevelStats[level] ?? 0
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
                                Text("\(expiredKeysCount)")
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
                                Text("\(expiringSoonCount)")
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
                                Text("\(neverExpireCount)")
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
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date.distantFuture
        return viewModel.keys.filter { key in
            guard let expiresAt = key.expiresAt else { return false }
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
        case .ultimate: return Color.moaiySuccess
        case .full: return Color.moaiyInfo
        case .marginal: return Color.moaiyWarning
        case .none: return Color.moaiyError
        case .unknown: return Color.moaiyTextSecondary
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
