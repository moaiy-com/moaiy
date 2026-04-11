//
//  ExpirationReminderSettingsView.swift
//  Moaiy
//
//  Settings for key expiration reminders
//

import SwiftUI

struct ExpirationReminderSettingsView: View {
    @State private var reminderService = ExpirationReminderService()
    @Environment(KeyManagementViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPermissionAlert = false
    @State private var promptAlert: PromptAlertContent?

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            ScrollView {
                VStack(spacing: MoaiyUI.Spacing.xxl) {
                    statusCard
                    reminderToggleCard
                    warningPeriodCard

                    if reminderService.isEnabled && (reminderService.expiredKeys.count > 0 || reminderService.expiringSoonKeys.count > 0) {
                        manualNotificationCard
                    }

                    infoCard
                }
                .padding(MoaiyUI.Spacing.xxl)
            }
        }
        .background(Color.moaiySurfaceBackground)
        .moaiyModalAdaptiveSize(
            minWidth: 500,
            idealWidth: 580,
            maxWidth: 720,
            minHeight: 650,
            idealHeight: 760,
            maxHeight: 900
        )
        .onAppear {
            reminderService.updateKeys(viewModel.keys)
        }
        .onChange(of: viewModel.keys) { _, newKeys in
            reminderService.updateKeys(newKeys)
        }
        .onChange(of: showingPermissionAlert) { _, isShowing in
            guard isShowing else { return }
            promptAlert = PromptAlertContent.info(
                title: "expiration_permission_title",
                message: String(localized: "expiration_permission_message"),
                onAcknowledge: {
                    showingPermissionAlert = false
                },
                onDismiss: {
                    showingPermissionAlert = false
                }
            )
        }
        .moaiyPromptAlertHost(alert: $promptAlert)
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                Text("expiration_settings_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.moaiyTextPrimary)

                Text("expiration_settings_subtitle")
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
        .padding(MoaiyUI.Spacing.xxl)
    }

    private var statusCard: some View {
        HStack(spacing: MoaiyUI.Spacing.lg) {
            Image(systemName: reminderService.isEnabled ? "bell.badge.fill" : "bell.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(reminderService.isEnabled ? Color.moaiySuccess : Color.moaiyTextSecondary)

            VStack(alignment: .leading, spacing: MoaiyUI.Spacing.xs) {
                Text("expiration_status_title")
                    .font(.headline)
                    .foregroundStyle(Color.moaiyTextPrimary)

                if reminderService.isEnabled {
                    Text("expiration_status_enabled")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyTextSecondary)
                } else {
                    Text("expiration_status_disabled")
                        .font(.caption)
                        .foregroundStyle(Color.moaiyWarning)
                }
            }

            Spacer()

            if reminderService.isEnabled {
                VStack(alignment: .trailing, spacing: MoaiyUI.Spacing.xs) {
                    HStack(spacing: MoaiyUI.Spacing.xs) {
                        Text("\(reminderService.expiringSoonKeys.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.moaiyWarning)

                        Text("expiration_expiring")
                            .font(.caption)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }

                    HStack(spacing: MoaiyUI.Spacing.xs) {
                        Text("\(reminderService.expiredKeys.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.moaiyError)

                        Text("expiration_expired")
                            .font(.caption2)
                            .foregroundStyle(Color.moaiyTextSecondary)
                    }
                }
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
    }

    private var reminderToggleCard: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Toggle("expiration_enable_reminders", isOn: $reminderService.isEnabled)
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            Text("expiration_enable_description")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
    }

    private var warningPeriodCard: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("expiration_warning_period")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            Picker("", selection: $reminderService.reminderDays) {
                Text("expiration_7_days").tag(7)
                Text("expiration_14_days").tag(14)
                Text("expiration_30_days").tag(30)
                Text("expiration_60_days").tag(60)
                Text("expiration_90_days").tag(90)
            }
            .pickerStyle(.radioGroup)

            Text("expiration_warning_description")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
        .disabled(!reminderService.isEnabled)
        .opacity(reminderService.isEnabled ? 1 : 0.5)
    }

    private var manualNotificationCard: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.md) {
            Text("expiration_manual_notifications")
                .font(.headline)
                .foregroundStyle(Color.moaiyTextPrimary)

            if reminderService.expiredKeys.count > 0 {
                Button(action: {
                    Task { await reminderService.notifyExpiredKeys() }
                }) {
                    Label(
                        String(
                            format: String(localized: "expiration_notify_expired"),
                            locale: Locale.current,
                            Int64(reminderService.expiredKeys.count)
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.moaiyError)
            }

            if reminderService.expiringSoonKeys.count > 0 {
                Button(action: {
                    Task { await reminderService.notifyExpiringSoonKeys() }
                }) {
                    Label(
                        String(
                            format: String(localized: "expiration_notify_expiring"),
                            locale: Locale.current,
                            Int64(reminderService.expiringSoonKeys.count)
                        ),
                        systemImage: "clock.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.moaiyWarning)
            }
        }
        .padding(MoaiyUI.Spacing.md)
        .moaiyCardStyle(cornerRadius: MoaiyUI.Radius.lg)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: MoaiyUI.Spacing.sm) {
            Label("expiration_info_1", systemImage: "bell.fill")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)

            Label("expiration_info_2", systemImage: "clock.fill")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)

            Label("expiration_info_3", systemImage: "gear.fill")
                .font(.caption)
                .foregroundStyle(Color.moaiyTextSecondary)
        }
        .padding(MoaiyUI.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moaiyBannerStyle(tint: Color.moaiyInfo)
    }
}

// MARK: - Preview

#Preview("Expiration Settings") {
    ExpirationReminderSettingsView()
        .environment(KeyManagementViewModel())
}
