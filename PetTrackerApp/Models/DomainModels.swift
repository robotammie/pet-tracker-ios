import Foundation

struct Pet: Identifiable, Hashable {
    let id: UUID
    var name: String
    var caloriesPerDay: Int?
}

enum CareEventType: String, CaseIterable, Identifiable {
    case food = "Food"
    case litter = "Litter"
    case medicine = "Medicine"

    var id: String { rawValue }
}

enum FoodType: String, CaseIterable, Identifiable {
    case wet = "Wet"
    case dry = "Dry"
    case treat = "Treat"

    var id: String { rawValue }
}

enum FoodUnit: String, CaseIterable, Identifiable {
    case cup = "cup"
    case ounce = "oz"

    var id: String { rawValue }
}

struct FoodEventData: Hashable {
    var name: String
    var foodType: FoodType
    var amount: Double
    var unit: FoodUnit
    var calories: Int
}

struct LitterEventData: Hashable {}

struct MedicineEventData: Hashable {
    var name: String
    var dosage: Double
    var unit: String
}

enum CareEventData: Hashable {
    case food(FoodEventData)
    case litter(LitterEventData)
    case medicine(MedicineEventData)
}

struct CareEvent: Identifiable, Hashable {
    let id: UUID
    var type: CareEventType
    var petID: UUID?
    var createdAt: Date
    var startTime: Date
    var endTime: Date?
    var data: CareEventData
}

enum ReminderMode: String, CaseIterable, Identifiable {
    case pureReminder = "Reminder"
    case reminderToEvent = "Reminder to Event"

    var id: String { rawValue }
}

enum ReminderDueStyle: String, CaseIterable, Identifiable {
    case timestamp = "Timestamp"
    case dayOnly = "Day Only"

    var id: String { rawValue }
}

struct Reminder: Identifiable, Hashable {
    let id: UUID
    var title: String
    var mode: ReminderMode
    var eventType: CareEventType?
    var dueAt: Date
    var dueStyle: ReminderDueStyle
    var isCompleted: Bool
}

struct UserSettings: Hashable {
    var defaultDayOnlyNotificationHour: Int
    var showsBannerNotifications: Bool
    var playsNotificationSounds: Bool
    var updatesBadge: Bool

    static let defaults = UserSettings(
        defaultDayOnlyNotificationHour: 9,
        showsBannerNotifications: true,
        playsNotificationSounds: true,
        updatesBadge: true
    )
}
