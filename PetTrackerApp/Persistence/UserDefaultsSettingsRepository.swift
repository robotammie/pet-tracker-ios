import Foundation

final class UserDefaultsSettingsRepository: UserSettingsRepository {
    private enum Key {
        static let defaultDayOnlyNotificationHour = "settings.defaultDayOnlyNotificationHour"
        static let showsBanner = "settings.globalNotification.showsBanner"
        static let playsSound = "settings.globalNotification.playsSound"
        static let updatesBadge = "settings.globalNotification.updatesBadge"
        static func eventTypeShowsBanner(_ eventType: CareEventType) -> String {
            "settings.\(eventType.rawValue).notification.showsBanner"
        }
        static func eventTypePlaysSound(_ eventType: CareEventType) -> String {
            "settings.\(eventType.rawValue).notification.playsSound"
        }
        static func eventTypeUpdatesBadge(_ eventType: CareEventType) -> String {
            "settings.\(eventType.rawValue).notification.updatesBadge"
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> UserSettings {
        UserSettings(
            defaultDayOnlyNotificationHour: defaults.object(forKey: Key.defaultDayOnlyNotificationHour) as? Int
                ?? UserSettings.defaults.defaultDayOnlyNotificationHour,
            globalNotificationPreferences: NotificationPresentationPreferences(
                showsBanner: bool(for: Key.showsBanner, default: UserSettings.defaults.globalNotificationPreferences.showsBanner),
                playsSound: bool(for: Key.playsSound, default: UserSettings.defaults.globalNotificationPreferences.playsSound),
                updatesBadge: bool(for: Key.updatesBadge, default: UserSettings.defaults.globalNotificationPreferences.updatesBadge)
            ),
            eventTypeNotificationPreferences: CareEventType.allCases.compactMap(eventTypeNotificationPreferences(for:))
        )
    }

    func saveSettings(_ settings: UserSettings) {
        defaults.set(settings.defaultDayOnlyNotificationHour, forKey: Key.defaultDayOnlyNotificationHour)
        defaults.set(settings.globalNotificationPreferences.showsBanner, forKey: Key.showsBanner)
        defaults.set(settings.globalNotificationPreferences.playsSound, forKey: Key.playsSound)
        defaults.set(settings.globalNotificationPreferences.updatesBadge, forKey: Key.updatesBadge)

        CareEventType.allCases.forEach { eventType in
            guard let override = settings.eventTypeNotificationPreferences.first(where: { $0.eventType == eventType }) else {
                defaults.removeObject(forKey: Key.eventTypeShowsBanner(eventType))
                defaults.removeObject(forKey: Key.eventTypePlaysSound(eventType))
                defaults.removeObject(forKey: Key.eventTypeUpdatesBadge(eventType))
                return
            }

            defaults.set(override.preferences.showsBanner, forKey: Key.eventTypeShowsBanner(eventType))
            defaults.set(override.preferences.playsSound, forKey: Key.eventTypePlaysSound(eventType))
            defaults.set(override.preferences.updatesBadge, forKey: Key.eventTypeUpdatesBadge(eventType))
        }
    }

    private func bool(for key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private func eventTypeNotificationPreferences(for eventType: CareEventType) -> EventTypeNotificationPreferences? {
        guard defaults.object(forKey: Key.eventTypeShowsBanner(eventType)) != nil,
              defaults.object(forKey: Key.eventTypePlaysSound(eventType)) != nil,
              defaults.object(forKey: Key.eventTypeUpdatesBadge(eventType)) != nil
        else {
            return nil
        }

        return EventTypeNotificationPreferences(
            eventType: eventType,
            preferences: NotificationPresentationPreferences(
                showsBanner: bool(for: Key.eventTypeShowsBanner(eventType), default: UserSettings.defaults.globalNotificationPreferences.showsBanner),
                playsSound: bool(for: Key.eventTypePlaysSound(eventType), default: UserSettings.defaults.globalNotificationPreferences.playsSound),
                updatesBadge: bool(for: Key.eventTypeUpdatesBadge(eventType), default: UserSettings.defaults.globalNotificationPreferences.updatesBadge)
            )
        )
    }
}
