import Foundation
@preconcurrency import UserNotifications

protocol NotificationScheduling {
    func requestAuthorization()
    func sync(reminders: [Reminder], settings: UserSettings)
    func resetScheduledNotifications()
}

struct LocalNotificationScheduler: NotificationScheduling {
    func requestAuthorization() {
        LocalNotificationService.requestAuthorization()
    }

    func sync(reminders: [Reminder], settings: UserSettings) {
        LocalNotificationService.sync(reminders: reminders, settings: settings)
    }

    func resetScheduledNotifications() {
        LocalNotificationService.resetScheduledNotifications()
    }
}

enum LocalNotificationService {
    private static let identifierPrefix = "reminder-"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func sync(reminders: [Reminder], settings: UserSettings, calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        let activeReminders = reminders.filter(\.isActive)
        let overdueBadgeCount = badgeCount(
            for: reminders,
            settings: settings,
            now: .now,
            calendar: calendar
        )

        setBadgeCount(overdueBadgeCount)

        removePendingReminderRequests(center: center) {
            activeReminders.forEach { reminder in
                schedule(
                    reminder,
                    settings: settings,
                    calendar: calendar,
                    deliveredBadgeCount: deliveredBadgeCount(
                        for: reminder,
                        activeReminders: activeReminders,
                        settings: settings,
                        calendar: calendar
                    )
                )
            }
        }
    }

    static func badgeCount(
        for reminders: [Reminder],
        settings: UserSettings,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        reminders.filter { reminder in
            reminder.isActive
                && settings.notificationPreferences(for: reminder.eventType).updatesBadge
                && reminder.isOverdue(now: now, calendar: calendar)
        }.count
    }

    static func schedule(
        _ reminder: Reminder,
        settings: UserSettings,
        calendar: Calendar = .current,
        deliveredBadgeCount: Int? = nil
    ) {
        guard reminder.isActive else {
            cancel(reminderID: reminder.id)
            return
        }

        let preferences = settings.notificationPreferences(for: reminder.eventType)

        guard preferences.showsBanner || preferences.playsSound || preferences.updatesBadge else {
            return
        }

        let content = UNMutableNotificationContent()

        if preferences.showsBanner {
            content.title = reminder.title
            content.body = notificationBody(for: reminder)
        }

        if preferences.playsSound {
            content.sound = .default
        }

        if preferences.updatesBadge {
            content.badge = NSNumber(value: max(1, deliveredBadgeCount ?? 1))
        }

        let trigger: UNNotificationTrigger

        switch reminder.dueStyle {
        case .timestamp:
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.displayDueAt()
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        case .dayOnly:
            var components = calendar.dateComponents([.year, .month, .day], from: reminder.displayDueAt())
            components.hour = settings.defaultDayOnlyNotificationHour
            components.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: reminder.id),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(reminderID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: reminderID)]
        )
    }

    static func resetScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        setBadgeCount(0)
    }

    private static func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    private static func deliveredBadgeCount(
        for reminder: Reminder,
        activeReminders: [Reminder],
        settings: UserSettings,
        calendar: Calendar
    ) -> Int {
        guard settings.notificationPreferences(for: reminder.eventType).updatesBadge else {
            return 0
        }

        return activeReminders.filter { candidate in
            settings.notificationPreferences(for: candidate.eventType).updatesBadge
                && candidate.displayDueAt() <= reminder.displayDueAt()
                && candidate.isOverdue(now: reminder.displayDueAt(), calendar: calendar)
        }.count
    }

    private static func removePendingReminderRequests(
        center: UNUserNotificationCenter,
        completion: @escaping @Sendable () -> Void
    ) {
        center.getPendingNotificationRequests { requests in
            let reminderIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }

            center.removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
            completion()
        }
    }

    private static func notificationBody(for reminder: Reminder) -> String {
        let pendingCount = reminder.incompleteTargets.count

        guard pendingCount > 0 else {
            return reminder.mode.rawValue
        }

        if pendingCount == 1 {
            return "Still due for 1 pet"
        }

        return "Still due for \(pendingCount) pets"
    }

    private static func notificationIdentifier(for reminderID: UUID) -> String {
        "\(identifierPrefix)\(reminderID.uuidString)"
    }
}
