//
//  ExpirationReminderServicePermissionTests.swift
//  MoaiyTests
//
//  Integration tests for reminder-permission handling flows.
//

import Foundation
import Testing
import UserNotifications
@testable import Moaiy

@MainActor
@Suite("Expiration Reminder Permission Flow Tests")
struct ExpirationReminderServicePermissionFlowTests {

    @Test("Enable reminders rolls back when authorization is already denied")
    func enableReminders_rollsBackWhenDenied() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: "expirationReminderEnabled")
        defaults.set(30, forKey: "expirationReminderDays")

        let notificationClient = MockNotificationCenterClient(authorizationStatus: .denied)
        var deniedCallbackCount = 0

        let service = ExpirationReminderService(
            notificationClient: notificationClient,
            userDefaults: defaults,
            onPermissionDenied: {
                deniedCallbackCount += 1
            }
        )

        service.isEnabled = true
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.isEnabled == false)
        #expect(notificationClient.requestAuthorizationCallCount == 0)
        #expect(deniedCallbackCount == 1)
    }

    @Test("Enable reminders requests permission and rolls back after user denial")
    func enableReminders_requestsAndRollsBackWhenUserDenies() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: "expirationReminderEnabled")
        defaults.set(30, forKey: "expirationReminderDays")

        let notificationClient = MockNotificationCenterClient(authorizationStatus: .notDetermined)
        notificationClient.requestAuthorizationResult = false
        var deniedCallbackCount = 0

        let service = ExpirationReminderService(
            notificationClient: notificationClient,
            userDefaults: defaults,
            onPermissionDenied: {
                deniedCallbackCount += 1
            }
        )

        service.isEnabled = true
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(notificationClient.requestAuthorizationCallCount == 1)
        #expect(service.isEnabled == false)
        #expect(deniedCallbackCount == 1)
    }

    @Test("Enable reminders keeps enabled and schedules reminders when authorized")
    func enableReminders_keepsEnabledAndSchedulesWhenAuthorized() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: "expirationReminderEnabled")
        defaults.set(30, forKey: "expirationReminderDays")

        let notificationClient = MockNotificationCenterClient(authorizationStatus: .authorized)
        var deniedCallbackCount = 0

        let service = ExpirationReminderService(
            notificationClient: notificationClient,
            userDefaults: defaults,
            onPermissionDenied: {
                deniedCallbackCount += 1
            }
        )

        service.updateKeys([TestKeyFactory.makeExpiringSoonKey(days: 2)])
        service.isEnabled = true
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.isEnabled == true)
        #expect(deniedCallbackCount == 0)
        #expect(notificationClient.addCallCount >= 1)
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "ExpirationReminderServicePermissionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

@MainActor
private final class MockNotificationCenterClient: NotificationCenterClient {
    var authorizationStatusValue: UNAuthorizationStatus
    var requestAuthorizationResult = true
    var requestAuthorizationCallCount = 0
    var addCallCount = 0

    init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatusValue = authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return requestAuthorizationResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func add(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
    }

    func removeAllPendingNotificationRequests() {
        // No-op for tests.
    }
}
