import XCTest
@testable import PetTrackerApp

final class LocalNotificationServiceTests: XCTestCase {
    func testSystemDefaultsIgnoreOldHiddenGlobalSwitchesAndMixedTypesCombineOverrides() {
        var settings = UserSettings.defaults
        settings.globalNotificationPreferences = .init(showsBanner: false, playsSound: false, updatesBadge: false)
        XCTAssertEqual(settings.notificationPreferences(for: nil), .defaults)
        settings.setNotificationPreferences(.init(showsBanner: false, playsSound: false, updatesBadge: false), for: .food)
        let reminder = Reminder(title: "Dinner", mode: .reminderToEvent, eventType: nil, dueAt: .now,
            dueStyle: .timestamp, eventActions: [
                ReminderEventAction(data: .food(FoodEventData(name: "Food", foodType: .dry, amount: 1, unit: .cup, calories: 10))),
                ReminderEventAction(petID: UUID(), data: .medicine(MedicineEventData(name: "Med", dosage: 1, unit: "pill")))])
        XCTAssertEqual(LocalNotificationService.preferences(for: reminder, settings: settings), .defaults)
        settings.setNotificationPreferences(nil, for: .food)
        XCTAssertFalse(settings.hasNotificationOverride(for: .food))
        XCTAssertEqual(settings.notificationPreferences(for: .food), .defaults)
    }

    func testBadgeCountIncludesOnlyActiveOverdueBadgeEnabledReminders() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12)))
        let overdue = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10)))
        let future = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 14)))
        var settings = UserSettings.defaults
        settings.globalNotificationPreferences.updatesBadge = true

        let reminders = [
            Reminder(
                title: "Overdue one",
                mode: .pureReminder,
                eventType: nil,
                dueAt: overdue,
                dueStyle: .timestamp
            ),
            Reminder(
                title: "Overdue two",
                mode: .pureReminder,
                eventType: nil,
                dueAt: overdue,
                dueStyle: .timestamp
            ),
            Reminder(
                title: "Future",
                mode: .pureReminder,
                eventType: nil,
                dueAt: future,
                dueStyle: .timestamp
            ),
            Reminder(
                title: "Muted",
                mode: .pureReminder,
                eventType: nil,
                dueAt: overdue,
                dueStyle: .timestamp,
                status: .muted
            )
        ]

        XCTAssertEqual(
            LocalNotificationService.badgeCount(
                for: reminders,
                settings: settings,
                now: now,
                calendar: calendar
            ),
            2
        )
    }

    func testBadgeCountHonorsDisabledBadgePreference() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 12)))
        let overdue = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10)))
        var settings = UserSettings.defaults
        settings.setNotificationPreferences(NotificationPresentationPreferences(showsBanner: true, playsSound: true, updatesBadge: false), for: .food)

        let reminders = [
            Reminder(
                title: "Overdue",
                mode: .pureReminder,
                eventType: .food,
                dueAt: overdue,
                dueStyle: .timestamp
            )
        ]

        XCTAssertEqual(
            LocalNotificationService.badgeCount(
                for: reminders,
                settings: settings,
                now: now,
                calendar: calendar
            ),
            0
        )
    }
}

final class UserDefaultsSettingsRepositoryTests: XCTestCase {
    func testSettingsRepositoryPersistsEventTypeOverrides() throws {
        let suiteName = "PetTrackerAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        var settings = UserSettings.defaults
        settings.defaultDayOnlyNotificationHour = 7
        settings.globalNotificationPreferences = NotificationPresentationPreferences(
            showsBanner: true,
            playsSound: false,
            updatesBadge: true
        )
        settings.setNotificationPreferences(
            NotificationPresentationPreferences(
                showsBanner: false,
                playsSound: false,
                updatesBadge: true
            ),
            for: .medicine
        )

        repository.saveSettings(settings)

        let loaded = repository.loadSettings()
        XCTAssertEqual(loaded.defaultDayOnlyNotificationHour, 7)
        XCTAssertEqual(loaded.globalNotificationPreferences, settings.globalNotificationPreferences)
        XCTAssertEqual(loaded.notificationPreferences(for: .medicine), settings.notificationPreferences(for: .medicine))
        XCTAssertFalse(loaded.hasNotificationOverride(for: .food))
    }

    func testSettingsRepositoryRemovesEventTypeOverrides() throws {
        let suiteName = "PetTrackerAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        var settings = UserSettings.defaults
        settings.setNotificationPreferences(
            NotificationPresentationPreferences(
                showsBanner: false,
                playsSound: false,
                updatesBadge: false
            ),
            for: .litter
        )
        repository.saveSettings(settings)

        settings.setNotificationPreferences(nil, for: .litter)
        repository.saveSettings(settings)

        let loaded = repository.loadSettings()
        XCTAssertFalse(loaded.hasNotificationOverride(for: .litter))
        XCTAssertEqual(loaded.notificationPreferences(for: .litter), settings.globalNotificationPreferences)
    }
}
