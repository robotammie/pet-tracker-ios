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

    var medicineName: String?
    var medicineDosage: Double?
    var medicineUnit: String?

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
    var foodUnitRawValue: String?
    var foodCaloriesPerUnit: Int?
    var foodTypeRawValue: String?

    var medicineName: String?
    var medicineDosage: Double?
    var medicineUnit: String?
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

    var foodName: String?
    var foodTypeRawValue: String?
    var foodAmount: Double?
    var foodUnitRawValue: String?
    var foodCalories: Int?

    var medicineName: String?
    var medicineDosage: Double?
    var medicineUnit: String?

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
