import Foundation
import SwiftData

@Model
final class PetRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var caloriesPerDay: Int?

    init(id: UUID = UUID(), name: String, caloriesPerDay: Int? = nil) {
        self.id = id
        self.name = name
        self.caloriesPerDay = caloriesPerDay
    }
}

@Model
final class CareEventRecord {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    var petID: UUID?
    var createdAt: Date
    var startTime: Date
    var endTime: Date?

    var foodName: String?
    var foodTypeRawValue: String?
    var foodAmount: Double?
    var foodUnitRawValue: String?
    var foodCalories: Int?
    var foodCaloriesPerUnit: Int?
    var doseTimingOverrideAt: Date?
    var doseTimingOverrideMessage: String?

    var medicineName: String?
    var medicineDosage: Double?
    var medicineUnit: String?
    var medicineSavedOptionID: UUID?
    var medicineMinimumDoseHours: Double?
    var medicineMaximumDoseHours: Double?

    init(
        id: UUID = UUID(),
        typeRawValue: String,
        petID: UUID?,
        createdAt: Date,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.id = id
        self.typeRawValue = typeRawValue
        self.petID = petID
        self.createdAt = createdAt
        self.startTime = startTime
        self.endTime = endTime
    }
}

@Model
final class SavedEventOptionRecord {
    @Attribute(.unique) var id: UUID
    var eventTypeRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var foodName: String?
    var foodOfficialName: String?
    var foodUnitRawValue: String?
    var foodCaloriesPerUnit: Int?
    var foodTypeRawValue: String?

    var medicineName: String?
    var medicinePurpose: String?
    var medicinePetDoseIntervalsJSON: String?
    var medicineDosage: Double?
    var medicineUnit: String?
    var medicineSavedOptionID: UUID?
    var medicineMinimumDoseHours: Double?
    var medicineMaximumDoseHours: Double?
    var medicineRecurrenceKind: String?
    var medicineRecurrenceValue: Int?
    var medicineRecurrenceUnitRawValue: String?
    var medicineTimesOfDayMinutes: String?

    init(
        id: UUID = UUID(),
        eventTypeRawValue: String,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.eventTypeRawValue = eventTypeRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

@Model
final class ReminderRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var modeRawValue: String
    var eventTypeRawValue: String?
    var eventPetID: UUID?
    var dueAt: Date
    var dueStyleRawValue: String
    var statusRawValue: String
    var completedAt: Date?
    var ignoredUntil: Date?

    var foodName: String?
    var foodTypeRawValue: String?
    var foodAmount: Double?
    var foodUnitRawValue: String?
    var foodCalories: Int?

    var medicineName: String?
    var medicineDosage: Double?
    var medicineUnit: String?
    var medicineSavedOptionID: UUID?
    var medicineMinimumDoseHours: Double?
    var medicineMaximumDoseHours: Double?

    var recurrenceKind: String?
    var recurrenceValue: Int?
    var recurrenceUnitRawValue: String?
    var timesOfDayMinutes: String?
    var endDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        modeRawValue: String,
        eventTypeRawValue: String?,
        dueAt: Date,
        dueStyleRawValue: String,
        statusRawValue: String
    ) {
        self.id = id
        self.title = title
        self.modeRawValue = modeRawValue
        self.eventTypeRawValue = eventTypeRawValue
        self.dueAt = dueAt
        self.dueStyleRawValue = dueStyleRawValue
        self.statusRawValue = statusRawValue
    }
}

@Model
final class ReminderTargetRecord {
    @Attribute(.unique) var id: UUID
    var reminderID: UUID
    var petID: UUID
    var completedAt: Date?

    var foodName: String?
    var foodTypeRawValue: String?
    var foodAmount: Double?
    var foodUnitRawValue: String?
    var foodCalories: Int?

    var medicineName: String?
    var medicineDosage: Double?
    var medicineUnit: String?
    var medicineSavedOptionID: UUID?
    var medicineMinimumDoseHours: Double?
    var medicineMaximumDoseHours: Double?

    init(
        id: UUID = UUID(),
        reminderID: UUID,
        petID: UUID,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.reminderID = reminderID
        self.petID = petID
        self.completedAt = completedAt
    }
}

@Model
final class ScheduledEventRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var petID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var nextDueAt: Date?
    var calendarJSON: String

    var foodName: String
    var foodTypeRawValue: String
    var foodAmount: Double
    var foodUnitRawValue: String
    var foodCalories: Int
    var foodCaloriesPerUnit: Int?

    var recurrenceKind: String?
    var recurrenceValue: Int?
    var recurrenceUnitRawValue: String?
    var timesOfDayMinutes: String?
    var endDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        petID: UUID?,
        createdAt: Date,
        updatedAt: Date,
        nextDueAt: Date?,
        calendarJSON: String,
        foodName: String,
        foodTypeRawValue: String,
        foodAmount: Double,
        foodUnitRawValue: String,
        foodCalories: Int
    ) {
        self.id = id
        self.title = title
        self.petID = petID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.nextDueAt = nextDueAt
        self.calendarJSON = calendarJSON
        self.foodName = foodName
        self.foodTypeRawValue = foodTypeRawValue
        self.foodAmount = foodAmount
        self.foodUnitRawValue = foodUnitRawValue
        self.foodCalories = foodCalories
    }
}
