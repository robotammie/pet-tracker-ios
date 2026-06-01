import Foundation

struct Pet: Identifiable, Hashable {
    let id: UUID
    var name: String
    var caloriesPerDay: Int?

    init(id: UUID = UUID(), name: String, caloriesPerDay: Int? = nil) {
        self.id = id
        self.name = name
        self.caloriesPerDay = caloriesPerDay
    }
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

    init(name: String, foodType: FoodType, amount: Double, unit: FoodUnit, calories: Int) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.foodType = foodType
        self.amount = max(0, amount)
        self.unit = unit
        self.calories = max(0, calories)
    }
}

struct LitterEventData: Hashable {}

struct MedicineEventData: Hashable {
    var name: String
    var dosage: Double
    var unit: String

    init(name: String, dosage: Double, unit: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dosage = max(0, dosage)
        self.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }
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

    init(
        id: UUID = UUID(),
        type: CareEventType,
        petID: UUID?,
        createdAt: Date = .now,
        startTime: Date = .now,
        endTime: Date? = nil,
        data: CareEventData
    ) {
        self.id = id
        self.type = type
        self.petID = petID
        self.createdAt = createdAt
        self.startTime = startTime
        self.endTime = endTime
        self.data = data
    }
}

enum SavedOptionData: Hashable {
    case food(SavedFoodData)
    case medicine(SavedMedicineData)
}

struct SavedFoodData: Hashable {
    var name: String
    var unit: FoodUnit
    var caloriesPerUnit: Int
    var foodType: FoodType

    init(name: String, unit: FoodUnit, caloriesPerUnit: Int, foodType: FoodType) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unit = unit
        self.caloriesPerUnit = max(0, caloriesPerUnit)
        self.foodType = foodType
    }
}

struct SavedMedicineData: Hashable {
    var name: String
    var dosage: Double
    var unit: String
    var cadence: MedicineCadence?

    init(name: String, dosage: Double, unit: String, cadence: MedicineCadence? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dosage = max(0, dosage)
        self.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cadence = cadence
    }
}

struct SavedEventOption: Identifiable, Hashable {
    let id: UUID
    var eventType: CareEventType
    var data: SavedOptionData
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var isDeleted: Bool {
        deletedAt != nil
    }

    init(
        id: UUID = UUID(),
        eventType: CareEventType,
        data: SavedOptionData,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
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

enum ReminderStatus: String, CaseIterable, Identifiable {
    case active = "Active"
    case completed = "Completed"
    case muted = "Muted"

    var id: String { rawValue }
}

enum RecurrenceUnit: String, CaseIterable, Identifiable {
    case hour = "Hour"
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

enum RecurrenceRule: Hashable {
    case every(value: Int, unit: RecurrenceUnit)
    case timesPerDay(count: Int, times: [DateComponents])
}

struct MedicineCadence: Hashable {
    var rule: RecurrenceRule
}

struct ReminderSchedule: Hashable {
    var recurrenceRule: RecurrenceRule?
    var endDate: Date?
}

struct Reminder: Identifiable, Hashable {
    let id: UUID
    var title: String
    var mode: ReminderMode
    var eventType: CareEventType?
    var eventPetID: UUID?
    var eventData: CareEventData?
    var dueAt: Date
    var dueStyle: ReminderDueStyle
    var status: ReminderStatus
    var schedule: ReminderSchedule?

    var isActive: Bool {
        status == .active
    }

    init(
        id: UUID = UUID(),
        title: String,
        mode: ReminderMode,
        eventType: CareEventType?,
        eventPetID: UUID? = nil,
        eventData: CareEventData? = nil,
        dueAt: Date,
        dueStyle: ReminderDueStyle,
        status: ReminderStatus = .active,
        schedule: ReminderSchedule? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode
        self.eventType = eventType
        self.eventPetID = eventPetID
        self.eventData = eventData
        self.dueAt = dueAt
        self.dueStyle = dueStyle
        self.status = status
        self.schedule = schedule
    }
}

struct NotificationPresentationPreferences: Hashable {
    var showsBanner: Bool
    var playsSound: Bool
    var updatesBadge: Bool

    static let defaults = NotificationPresentationPreferences(
        showsBanner: true,
        playsSound: true,
        updatesBadge: true
    )
}

struct EventTypeNotificationPreferences: Hashable {
    var eventType: CareEventType
    var preferences: NotificationPresentationPreferences
}

struct UserSettings: Hashable {
    var defaultDayOnlyNotificationHour: Int
    var globalNotificationPreferences: NotificationPresentationPreferences
    var eventTypeNotificationPreferences: [EventTypeNotificationPreferences]

    static let defaults = UserSettings(
        defaultDayOnlyNotificationHour: 9,
        globalNotificationPreferences: .defaults,
        eventTypeNotificationPreferences: []
    )

    func notificationPreferences(for eventType: CareEventType?) -> NotificationPresentationPreferences {
        guard let eventType,
              let override = eventTypeNotificationPreferences.first(where: { $0.eventType == eventType })
        else {
            return globalNotificationPreferences
        }

        return override.preferences
    }
}
