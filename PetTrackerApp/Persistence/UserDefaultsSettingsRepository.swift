import Foundation

final class UserDefaultsSettingsRepository: UserSettingsRepository {
    private enum Key {
        static let defaultDayOnlyNotificationHour = "settings.defaultDayOnlyNotificationHour"
        static let showsBanner = "settings.globalNotification.showsBanner"
        static let playsSound = "settings.globalNotification.playsSound"
        static let updatesBadge = "settings.globalNotification.updatesBadge"
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
            eventTypeNotificationPreferences: []
        )
    }

    func saveSettings(_ settings: UserSettings) {
        defaults.set(settings.defaultDayOnlyNotificationHour, forKey: Key.defaultDayOnlyNotificationHour)
        defaults.set(settings.globalNotificationPreferences.showsBanner, forKey: Key.showsBanner)
        defaults.set(settings.globalNotificationPreferences.playsSound, forKey: Key.playsSound)
        defaults.set(settings.globalNotificationPreferences.updatesBadge, forKey: Key.updatesBadge)
    }

    private func bool(for key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
