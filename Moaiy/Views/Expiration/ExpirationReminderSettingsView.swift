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

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Status card
                    HStack(spacing: 16) {
                        Image(systemName: reminderService.isEnabled ? "bell.badge.fill" : "bell.slash.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(reminderService.isEnabled ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("expiration_status_title")
                                .font(.headline)

                            if reminderService.isEnabled {
                                Text("expiration_status_enabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("expiration_status_disabled")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            if reminderService.isEnabled {
                                HStack(spacing: 4) {
                                    Text("\(reminderService.expiringSoonKeys.count)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                    Text("expiration_expiring")
                                        .font(.caption)
                                }

                                HStack(spacing: 4) {
                                    Text("\(reminderService.expiredKeys.count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                    Text("expiration_expired")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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

                    // Manual check buttons
                    if reminderService.isEnabled && (reminderService.expiredKeys.count > 0 || reminderService.expiringSoonKeys.count > 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("expiration_manual_notifications")
                                .font(.headline)

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
                                .foregroundStyle(.red)
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
                                .foregroundStyle(.orange)
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
        .frame(width: 500, height: 650)
        .onAppear {
            reminderService.updateKeys(viewModel.keys)
        }
        .onChange(of: viewModel.keys) { _, newKeys in
            reminderService.updateKeys(newKeys)
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
