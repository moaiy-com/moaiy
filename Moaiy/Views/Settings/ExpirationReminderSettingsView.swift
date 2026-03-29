//
//  ExpirationReminderSettingsView.swift
//  Moaiy
//
//  Settings view for expiration reminders
//

import SwiftUI

struct ExpirationReminderSettingsView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    @State private var reminderService: ExpirationReminderService = ExpirationReminderService()

    @State private var showingPermissionAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("expiration_settings_title")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("expiration_settings_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { /* dismiss */ }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Enable/Disable
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("expiration_enable_reminders", isOn: $reminderService.isEnabled)
                            .font(.headline)

                        Text("expiration_enable_description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Warning period
                    VStack(alignment: .leading, spacing: 12) {
                        Text("expiration_warning_period")
                            .font(.headline)

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
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!reminderService.isEnabled)
                    .opacity(reminderService.isEnabled ? 1 : 0.5)

                    // Status
                    if reminderService.isEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("expiration_current_status")
                                .font(.headline)

                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(
                                    String(
                                        format: String(localized: "expiration_expired_count"),
                                        locale: Locale.current,
                                        Int64(reminderService.expiredKeys.count)
                                    )
                                )
                                    .font(.subheadline)
                            }

                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.orange)
                                Text(
                                    String(
                                        format: String(localized: "expiration_expiring_count"),
                                        locale: Locale.current,
                                        Int64(reminderService.expiringSoonKeys.count)
                                    )
                                )
                                    .font(.subheadline)
                            }

                            if reminderService.expiredKeys.isEmpty && reminderService.expiringSoonKeys.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("expiration_all_keys_valid")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Actions
                    if reminderService.isEnabled && (!reminderService.expiredKeys.isEmpty || !reminderService.expiringSoonKeys.isEmpty) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("expiration_actions")
                                .font(.headline)

                            if !reminderService.expiredKeys.isEmpty {
                                Button(action: {
                                    Task {
                                        await reminderService.notifyExpiredKeys()
                                    }
                                }) {
                                    Label("expiration_notify_expired", systemImage: "bell.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }

                            if !reminderService.expiringSoonKeys.isEmpty {
                                Button(action: {
                                    Task {
                                        await reminderService.notifyExpiringSoonKeys()
                                    }
                                }) {
                                    Label("expiration_notify_expiring", systemImage: "bell.badge.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("expiration_info_1", systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("expiration_info_2", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("expiration_info_3", systemImage: "gear.fill")
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
        .frame(width: 500, height: 600)
        .onAppear {
            reminderService.updateKeys(viewModel.keys)
        }
        .alert("expiration_permission_title", isPresented: $showingPermissionAlert) {
            Button("action_ok") { }
        } message: {
            Text("expiration_permission_message")
        }
    }
}

// MARK: - Preview

#Preview("Expiration Settings") {
    ExpirationReminderSettingsView()
        .environment(KeyManagementViewModel())
}
