//
//  ExpirationReminderService.swift
//  Moaiy
//
//  Service for managing key expiration reminders
//

import Foundation
import UserNotifications
import os.log

protocol NotificationCenterClient {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
}

struct UserNotificationCenterClient: NotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }
}

@MainActor
@Observable
class ExpirationReminderService {
    private let logger = Logger(subsystem: "com.moaiy.app", category: "ExpirationReminder")
    private let notificationClient: NotificationCenterClient
    private let userDefaults: UserDefaults
    var onPermissionDenied: (() -> Void)?

    private enum DefaultsKey {
        static let reminderEnabled = "expirationReminderEnabled"
        static let reminderDays = "expirationReminderDays"
    }

    // MARK: - Published State

    var isEnabled: Bool {
        get { userDefaults.bool(forKey: DefaultsKey.reminderEnabled) }
        set {
            userDefaults.set(newValue, forKey: DefaultsKey.reminderEnabled)
            if newValue {
                Task { @MainActor in
                    let authorized = await ensureNotificationPermissionIfNeeded()
                    guard authorized else {
                        isEnabled = false
                        return
                    }
                    await scheduleReminders()
                }
            } else {
                Task { await cancelAllReminders() }
            }
        }
    }

    var reminderDays: Int {
        get { userDefaults.integer(forKey: DefaultsKey.reminderDays) }
        set {
            userDefaults.set(newValue, forKey: DefaultsKey.reminderDays)
            Task { await scheduleReminders() }
        }
    }

    var expiredKeys: [GPGKey] = []
    var expiringSoonKeys: [GPGKey] = []

    // MARK: - Constants

    private let notificationIdentifier = "com.moaiy.expirationReminder"

    // MARK: - Initialization

    init(
        notificationClient: NotificationCenterClient = UserNotificationCenterClient(),
        userDefaults: UserDefaults = .standard,
        onPermissionDenied: (() -> Void)? = nil
    ) {
        self.notificationClient = notificationClient
        self.userDefaults = userDefaults
        self.onPermissionDenied = onPermissionDenied

        // Default values
        if userDefaults.object(forKey: DefaultsKey.reminderEnabled) == nil {
            isEnabled = true
        }
        if userDefaults.object(forKey: DefaultsKey.reminderDays) == nil {
            reminderDays = 30 // Default: 30 days before expiration
        }

        Task {
            await checkExpiredKeys()
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
        content.title = AppLocalization.string("notification_expired_keys_title")
        content.body = String(
            format: AppLocalization.string("notification_expired_keys_body"),
            locale: AppLocalization.locale,
            expiredKeys.count
        )
        content.sound = .default
        content.badge = NSNumber(value: expiredKeys.count)

        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier).expired",
            content: content,
            trigger: nil // Immediate
        )

        do {
            try await notificationClient.add(request)
            logger.info("Sent expired keys notification")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    /// Send immediate notification for expiring soon keys
    func notifyExpiringSoonKeys() async {
        guard isEnabled, !expiringSoonKeys.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = AppLocalization.string("notification_expiring_soon_title")
        content.body = String(
            format: AppLocalization.string("notification_expiring_soon_body"),
            locale: AppLocalization.locale,
            expiringSoonKeys.count
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(notificationIdentifier).expiring",
            content: content,
            trigger: nil // Immediate
        )

        do {
            try await notificationClient.add(request)
            logger.info("Sent expiring soon notification")
        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
        }
    }

    /// Cancel all scheduled reminders
    func cancelAllReminders() async {
        notificationClient.removeAllPendingNotificationRequests()
        logger.info("Cancelled all expiration reminders")
    }

    // MARK: - Private Methods

    private func requestNotificationPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await notificationClient.requestAuthorization(options: options)

            if granted {
                logger.info("Notification permission granted")
            } else {
                logger.warning("Notification permission denied")
                onPermissionDenied?()
            }
            return granted
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
            onPermissionDenied?()
            return false
        }
    }

    private func ensureNotificationPermissionIfNeeded() async -> Bool {
        switch await notificationClient.authorizationStatus() {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return await requestNotificationPermission()
        case .denied:
            logger.warning("Notification permission denied")
            onPermissionDenied?()
            return false
        @unknown default:
            return false
        }
    }

    private func scheduleReminder(for key: GPGKey, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = AppLocalization.string("notification_key_expiring_title")
        content.body = String(
            format: AppLocalization.string("notification_key_expiring_body"),
            locale: AppLocalization.locale,
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
            try await notificationClient.add(request)
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
