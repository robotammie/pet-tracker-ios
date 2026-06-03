import XCTest
@testable import PetTrackerApp

final class LocalNotificationServiceTests: XCTestCase {
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
        settings.globalNotificationPreferences.updatesBadge = false

        let reminders = [
            Reminder(
                title: "Overdue",
                mode: .pureReminder,
                eventType: nil,
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
