//
//  ExpirationReminderService.swift
//  Moaiy
//
//  Service for managing key expiration reminders
//

import Foundation
import UserNotifications
import os.log

@MainActor
@Observable
class ExpirationReminderService {
    private let logger = Logger(subsystem: "com.moaiy.app", category: "ExpirationReminder")

    // MARK: - Published State

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "expirationReminderEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "expirationReminderEnabled")
            if newValue {
                Task { await scheduleReminders() }
            } else {
                Task { await cancelAllReminders() }
            }
        }
    }

    var reminderDays: Int {
        get { UserDefaults.standard.integer(forKey: "expirationReminderDays") }
        set {
            UserDefaults.standard.set(newValue, forKey: "expirationReminderDays")
            Task { await scheduleReminders() }
        }
    }

    var expiredKeys: [GPGKey] = []
    var expiringSoonKeys: [GPGKey] = []

    // MARK: - Constants

    private let notificationIdentifier = "com.moaiy.expirationReminder"

    // MARK: - Initialization

    init() {
        // Default values
        if UserDefaults.standard.object(forKey: "expirationReminderEnabled") == nil {
            isEnabled = true
        }
        if UserDefaults.standard.object(forKey: "expirationReminderDays") == nil {
            reminderDays = 30 // Default: 30 days before expiration
        }

        Task {
            await checkExpiredKeys()
            await requestNotificationPermission()
        }
    }

    // MARK: - Public Methods

    /// Check all keys for expiration status
    func checkExpiredKeys() async {
        // This would be called from KeyManagementViewModel
        // For now, we'll set up the structure
        logger.info("Checking key expiration status")
    }

    /// Update expiration status with current keys
    func updateKeys(_ keys: [GPGKey]) {
        let now = Date()
        let warningDate = Calendar.current.date(byAdding: .day, value: reminderDays, to: now) ?? now

        expiredKeys = keys.filter { key in
            guard let expiresAt = key.expiresAt else { return false }
            return expiresAt < now
        }

        expiringSoonKeys = keys.filter { key in
            guard let expiresAt = key.expiresAt else { return false }
            return expiresAt >= now && expiresAt <= warningDate
        }

        logger.info("Found \(self.expiredKeys.count) expired keys, \(self.expiringSoonKeys.count) expiring soon")
    }

    /// Schedule reminders for expiring keys
    func scheduleReminders() async {
        guard isEnabled else { return }

        await cancelAllReminders()

        // Schedule for expiring soon keys
        for key in expiringSoonKeys {
            if let expiresAt = key.expiresAt {
                await scheduleReminder(for: key, at: expiresAt)
            }
        }

        logger.info("Scheduled \(self.expiringSoonKeys.count) expiration reminders")
    }

    /// Send immediate notification for expired keys
    func notifyExpiredKeys() async {
        guard isEnabled, !expiredKeys.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_expired_keys_title", comment: "")
        content.body = String(format: NSLocalizedString("notification_expired_keys_body", comment: ""), expiredKeys.count)
        content.sound = .default
        content.badge = NSNumber(value: expiredKeys.count)

        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier).expired",
            content: content,
            trigger: nil // Immediate
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Sent expired keys notification")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    /// Send immediate notification for expiring soon keys
    func notifyExpiringSoonKeys() async {
        guard isEnabled, !expiringSoonKeys.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_expiring_soon_title", comment: "")
        content.body = String(format: NSLocalizedString("notification_expiring_soon_body", comment: ""), expiringSoonKeys.count)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier).expiring",
            content: content,
            trigger: nil // Immediate
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Sent expiring soon notification")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    /// Cancel all scheduled reminders
    func cancelAllReminders() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        logger.info("Cancelled all expiration reminders")
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)

            if granted {
                logger.info("Notification permission granted")
            } else {
                logger.warning("Notification permission denied")
            }
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
        }
    }

    private func scheduleReminder(for key: GPGKey, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_key_expiring_title", comment: "")
        content.body = String(
            format: NSLocalizedString("notification_key_expiring_body", comment: ""),
            key.name,
            date.formatted(date: .abbreviated, time: .omitted)
        )
        content.sound = .default

        // Schedule 1 day before expiration
        let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier).\(key.fingerprint)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to schedule reminder for \(key.fingerprint): \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Helpers

extension ExpirationReminderService {
    /// Create sample data for testing
    func loadSampleData() {
        // This would be used for testing in development
    }
}
