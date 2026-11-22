import Foundation

struct Pet: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var caloriesPerDay: Int?

    init(id: UUID = UUID(), name: String, caloriesPerDay: Int? = nil) {
        self.id = id
        self.name = name
        self.caloriesPerDay = caloriesPerDay
    }
}

enum CareEventType: String, CaseIterable, Identifiable, Codable {
    case food = "Food"
    case litter = "Litter"
    case medicine = "Medicine"

    var id: String { rawValue }
}

enum FoodType: String, CaseIterable, Identifiable, Codable {
    case wet = "Wet"
    case dry = "Dry"
    case treat = "Treat"

    var id: String { rawValue }
}

enum FoodUnit: String, CaseIterable, Identifiable, Codable {
    case cup = "cup"
    case ounce = "oz"
    case can = "can"

    static func options(for foodType: FoodType) -> [FoodUnit] {
        allCases.filter { $0 != .can || foodType == .wet }
    }

    var id: String { rawValue }
}

struct FoodEventData: Hashable, Codable {
    var name: String
    var foodType: FoodType
    var amount: Double
    var unit: FoodUnit
    var calories: Int
    var caloriesPerUnit: Int?

    init(name: String, foodType: FoodType, amount: Double, unit: FoodUnit, calories: Int, caloriesPerUnit: Int? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.foodType = foodType
        self.amount = max(0, amount)
        self.unit = unit
        self.calories = max(0, calories)
        self.caloriesPerUnit = caloriesPerUnit
    }
}

struct LitterEventData: Hashable, Codable {}

struct MedicineEventData: Hashable, Codable {
    var name: String
    var dosage: Double
    var unit: String
    var savedOptionID: UUID?
    var doseInterval: MedicationDoseInterval?

    init(name: String, dosage: Double, unit: String, savedOptionID: UUID? = nil, doseInterval: MedicationDoseInterval? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dosage = max(0, dosage)
        self.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        self.savedOptionID = savedOptionID
        self.doseInterval = doseInterval
    }
}

enum CareEventData: Hashable, Codable {
    case food(FoodEventData)
    case litter(LitterEventData)
    case medicine(MedicineEventData)
}

struct CareEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var type: CareEventType
    var petID: UUID?
    var createdAt: Date
    var startTime: Date
    var endTime: Date?
    var data: CareEventData
    var doseTimingOverrideAt: Date?
    var doseTimingOverrideMessage: String?

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

enum SavedOptionData: Hashable, Codable {
    case food(SavedFoodData)
    case medicine(SavedMedicineData)
}

struct SavedFoodData: Hashable, Codable {
    var name: String
    var officialName: String?
    var unit: FoodUnit
    var caloriesPerUnit: Int
    var foodType: FoodType

    init(name: String, unit: FoodUnit, caloriesPerUnit: Int, foodType: FoodType, officialName: String? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unit = unit
        self.caloriesPerUnit = max(0, caloriesPerUnit)
        self.foodType = foodType
        self.officialName = officialName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.officialName?.isEmpty == true { self.officialName = nil }
    }
}

struct SavedMedicineData: Hashable, Codable {
    var name: String
    var purpose: String?
    var dosage: Double
    var unit: String
    var cadence: MedicineCadence?
    var doseInterval: MedicationDoseInterval?
    var petDoseIntervals: [PetMedicationDoseInterval]

    init(name: String, dosage: Double, unit: String, cadence: MedicineCadence? = nil, purpose: String? = nil,
         doseInterval: MedicationDoseInterval? = nil, petDoseIntervals: [PetMedicationDoseInterval] = []) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dosage = max(0, dosage)
        self.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cadence = cadence
        self.purpose = purpose?.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.purpose?.isEmpty == true { self.purpose = nil }
        self.doseInterval = doseInterval
        self.petDoseIntervals = petDoseIntervals
    }

    func doseInterval(for petID: UUID?) -> MedicationDoseInterval? {
        petDoseIntervals.first { $0.petID == petID }?.interval ?? doseInterval
    }
}

struct MedicationDoseInterval: Hashable, Codable {
    var minimumHours: Double
    var maximumHours: Double

    var isValid: Bool {
        minimumHours.isFinite && maximumHours.isFinite && minimumHours > 0
            && maximumHours >= minimumHours && (maximumHours * 3_600).isFinite
    }

    var summary: String {
        minimumHours == maximumHours ? "\(minimumHours.formatted()) hours"
            : "\(minimumHours.formatted())–\(maximumHours.formatted()) hours"
    }
}

struct PetMedicationDoseInterval: Hashable, Codable {
    var petID: UUID
    var interval: MedicationDoseInterval
}

struct SavedEventOption: Identifiable, Hashable, Codable {
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

enum ReminderMode: String, CaseIterable, Identifiable, Codable {
    case pureReminder = "Reminder"
    case reminderToEvent = "Reminder to Event"

    var id: String { rawValue }
}

enum ReminderDueStyle: String, CaseIterable, Identifiable, Codable {
    case timestamp = "Timestamp"
    case dayOnly = "Day Only"

    var id: String { rawValue }
}

enum ReminderStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Active"
    case completed = "Completed"
    case muted = "Muted"

    var id: String { rawValue }
}

enum RecurrenceUnit: String, CaseIterable, Identifiable, Codable {
    case hour = "Hour"
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

enum RecurrenceRule: Hashable, Codable {
    case every(value: Int, unit: RecurrenceUnit)
    case timesPerDay(count: Int, times: [DateComponents])
}

struct MedicineCadence: Hashable, Codable {
    var rule: RecurrenceRule
}

struct ReminderSchedule: Hashable, Codable {
    var recurrenceRule: RecurrenceRule?
    var endDate: Date?
}

struct ReminderTarget: Identifiable, Hashable, Codable {
    var petID: UUID
    var eventData: CareEventData?
    var completedAt: Date?

    var id: UUID { petID }

    init(petID: UUID, eventData: CareEventData? = nil, completedAt: Date? = nil) {
        self.petID = petID
        self.eventData = eventData
        self.completedAt = completedAt
    }
}

struct ReminderEventAction: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var petID: UUID?
    var data: CareEventData
    var type: CareEventType { data.eventType }
}

extension CareEventData {
    var eventType: CareEventType {
        switch self { case .food: .food; case .medicine: .medicine; case .litter: .litter }
    }
}

struct Reminder: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var mode: ReminderMode
    var eventType: CareEventType?
    var eventPetID: UUID?
    var eventData: CareEventData?
    var eventActions: [ReminderEventAction]?
    var dueAt: Date
    var dueStyle: ReminderDueStyle
    var status: ReminderStatus
    var schedule: ReminderSchedule?
    var targets: [ReminderTarget]
    var completedAt: Date?
    var ignoredUntil: Date?

    var isActive: Bool {
        status == .active
    }

    var isRecurring: Bool {
        schedule?.recurrenceRule != nil
    }

    var incompleteTargets: [ReminderTarget] {
        targets.filter { $0.completedAt == nil }
    }

    var isFullyComplete: Bool {
        if targets.isEmpty {
            return status == .completed
        }

        return incompleteTargets.isEmpty
    }

    func displayDueAt(now: Date = .now) -> Date {
        if let ignoredUntil, ignoredUntil > now {
            return ignoredUntil
        }

        return dueAt
    }

    func isOverdue(now: Date = .now, calendar: Calendar = .current) -> Bool {
        let effectiveDueAt = displayDueAt(now: now)

        switch dueStyle {
        case .timestamp:
            return effectiveDueAt < now
        case .dayOnly:
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: effectiveDueAt)) else {
                return effectiveDueAt < now
            }

            return nextDay <= now
        }
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
        schedule: ReminderSchedule? = nil,
        targets: [ReminderTarget] = [],
        completedAt: Date? = nil,
        ignoredUntil: Date? = nil,
        eventActions: [ReminderEventAction]? = nil
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
        if targets.isEmpty, let eventPetID {
            self.targets = [ReminderTarget(petID: eventPetID, eventData: eventData)]
        } else {
            self.targets = targets
        }
        self.completedAt = completedAt
        self.ignoredUntil = ignoredUntil
        self.eventActions = eventActions
    }
}

struct ScheduledEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var petID: UUID?
    var food: FoodEventData?
    var eventType: CareEventType?
    var nextDueAt: Date?
    var schedule: ReminderSchedule?
    var calendar: Calendar
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        petID: UUID?,
        food: FoodEventData? = nil,
        eventType: CareEventType? = nil,
        nextDueAt: Date?,
        schedule: ReminderSchedule? = nil,
        calendar: Calendar = .current,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.petID = petID
        self.food = food
        self.eventType = eventType
        self.nextDueAt = nextDueAt
        self.schedule = schedule
        self.calendar = calendar
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: CareEventType { eventType ?? .food }
    var data: CareEventData? {
        switch type { case .food: food.map(CareEventData.food); case .litter: .litter(LitterEventData()); case .medicine: nil }
    }
    var isActive: Bool { nextDueAt != nil }
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
            return .defaults
        }

        return override.preferences
    }

    func hasNotificationOverride(for eventType: CareEventType) -> Bool {
        eventTypeNotificationPreferences.contains { $0.eventType == eventType }
    }

    mutating func setNotificationPreferences(
        _ preferences: NotificationPresentationPreferences?,
        for eventType: CareEventType
    ) {
        eventTypeNotificationPreferences.removeAll { $0.eventType == eventType }

        guard let preferences else {
            return
        }

        eventTypeNotificationPreferences.append(EventTypeNotificationPreferences(
            eventType: eventType,
            preferences: preferences
        ))
    }
}
