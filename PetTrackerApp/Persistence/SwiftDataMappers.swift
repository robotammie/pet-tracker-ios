import Foundation

enum SwiftDataMapper {
    static func pet(from record: PetRecord) -> Pet {
        Pet(id: record.id, name: record.name, caloriesPerDay: record.caloriesPerDay)
    }

    static func update(_ record: PetRecord, with pet: Pet) {
        record.name = pet.name
        record.caloriesPerDay = pet.caloriesPerDay
    }

    static func event(from record: CareEventRecord) -> CareEvent? {
        guard let type = CareEventType(rawValue: record.typeRawValue) else {
            return nil
        }

        let data: CareEventData

        switch type {
        case .food:
            guard let name = record.foodName,
                  let foodTypeRawValue = record.foodTypeRawValue,
                  let foodType = FoodType(rawValue: foodTypeRawValue),
                  let amount = record.foodAmount,
                  let unitRawValue = record.foodUnitRawValue,
                  let unit = FoodUnit(rawValue: unitRawValue),
                  let calories = record.foodCalories
            else {
                return nil
            }

            data = .food(FoodEventData(
                name: name,
                foodType: foodType,
                amount: amount,
                unit: unit,
                calories: calories
            ))

        case .litter:
            data = .litter(LitterEventData())

        case .medicine:
            guard let name = record.medicineName,
                  let dosage = record.medicineDosage,
                  let unit = record.medicineUnit
            else {
                return nil
            }

            data = .medicine(MedicineEventData(
                name: name,
                dosage: dosage,
                unit: unit
            ))
        }

        return CareEvent(
            id: record.id,
            type: type,
            petID: record.petID,
            createdAt: record.createdAt,
            startTime: record.startTime,
            endTime: record.endTime,
            data: data
        )
    }

    static func update(_ record: CareEventRecord, with event: CareEvent) {
        record.typeRawValue = event.type.rawValue
        record.petID = event.petID
        record.createdAt = event.createdAt
        record.startTime = event.startTime
        record.endTime = event.endTime

        record.foodName = nil
        record.foodTypeRawValue = nil
        record.foodAmount = nil
        record.foodUnitRawValue = nil
        record.foodCalories = nil
        record.medicineName = nil
        record.medicineDosage = nil
        record.medicineUnit = nil

        switch event.data {
        case let .food(data):
            record.foodName = data.name
            record.foodTypeRawValue = data.foodType.rawValue
            record.foodAmount = data.amount
            record.foodUnitRawValue = data.unit.rawValue
            record.foodCalories = data.calories

        case .litter:
            break

        case let .medicine(data):
            record.medicineName = data.name
            record.medicineDosage = data.dosage
            record.medicineUnit = data.unit
        }
    }

    static func savedOption(from record: SavedEventOptionRecord) -> SavedEventOption? {
        guard let eventType = CareEventType(rawValue: record.eventTypeRawValue) else {
            return nil
        }

        let data: SavedOptionData

        switch eventType {
        case .food:
            guard let name = record.foodName,
                  let unitRawValue = record.foodUnitRawValue,
                  let unit = FoodUnit(rawValue: unitRawValue),
                  let caloriesPerUnit = record.foodCaloriesPerUnit,
                  let foodTypeRawValue = record.foodTypeRawValue,
                  let foodType = FoodType(rawValue: foodTypeRawValue)
            else {
                return nil
            }

            data = .food(SavedFoodData(
                name: name,
                unit: unit,
                caloriesPerUnit: caloriesPerUnit,
                foodType: foodType
            ))

        case .medicine:
            guard let name = record.medicineName,
                  let dosage = record.medicineDosage,
                  let unit = record.medicineUnit
            else {
                return nil
            }

            data = .medicine(SavedMedicineData(
                name: name,
                dosage: dosage,
                unit: unit,
                cadence: medicineCadence(from: record)
            ))

        case .litter:
            return nil
        }

        return SavedEventOption(
            id: record.id,
            eventType: eventType,
            data: data,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            deletedAt: record.deletedAt
        )
    }

    static func update(_ record: SavedEventOptionRecord, with option: SavedEventOption) {
        record.eventTypeRawValue = option.eventType.rawValue
        record.createdAt = option.createdAt
        record.updatedAt = option.updatedAt
        record.deletedAt = option.deletedAt

        record.foodName = nil
        record.foodUnitRawValue = nil
        record.foodCaloriesPerUnit = nil
        record.foodTypeRawValue = nil
        record.medicineName = nil
        record.medicineDosage = nil
        record.medicineUnit = nil
        record.medicineRecurrenceKind = nil
        record.medicineRecurrenceValue = nil
        record.medicineRecurrenceUnitRawValue = nil
        record.medicineTimesOfDayMinutes = nil

        switch option.data {
        case let .food(data):
            record.foodName = data.name
            record.foodUnitRawValue = data.unit.rawValue
            record.foodCaloriesPerUnit = data.caloriesPerUnit
            record.foodTypeRawValue = data.foodType.rawValue

        case let .medicine(data):
            record.medicineName = data.name
            record.medicineDosage = data.dosage
            record.medicineUnit = data.unit
            apply(data.cadence?.rule, toMedicine: record)
        }
    }

    static func reminder(from record: ReminderRecord) -> Reminder? {
        guard let mode = ReminderMode(rawValue: record.modeRawValue),
              let dueStyle = ReminderDueStyle(rawValue: record.dueStyleRawValue),
              let status = ReminderStatus(rawValue: record.statusRawValue)
        else {
            return nil
        }

        return Reminder(
            id: record.id,
            title: record.title,
            mode: mode,
            eventType: record.eventTypeRawValue.flatMap(CareEventType.init(rawValue:)),
            eventPetID: record.eventPetID,
            eventData: reminderEventData(from: record),
            dueAt: record.dueAt,
            dueStyle: dueStyle,
            status: status,
            schedule: reminderSchedule(from: record)
        )
    }

    static func update(_ record: ReminderRecord, with reminder: Reminder) {
        record.title = reminder.title
        record.modeRawValue = reminder.mode.rawValue
        record.eventTypeRawValue = reminder.eventType?.rawValue
        record.eventPetID = reminder.eventPetID
        record.dueAt = reminder.dueAt
        record.dueStyleRawValue = reminder.dueStyle.rawValue
        record.statusRawValue = reminder.status.rawValue

        record.foodName = nil
        record.foodTypeRawValue = nil
        record.foodAmount = nil
        record.foodUnitRawValue = nil
        record.foodCalories = nil
        record.medicineName = nil
        record.medicineDosage = nil
        record.medicineUnit = nil
        record.recurrenceKind = nil
        record.recurrenceValue = nil
        record.recurrenceUnitRawValue = nil
        record.timesOfDayMinutes = nil
        record.endDate = reminder.schedule?.endDate

        apply(reminder.eventData, toReminder: record)
        apply(reminder.schedule?.recurrenceRule, toReminder: record)
    }

    private static func reminderEventData(from record: ReminderRecord) -> CareEventData? {
        guard let eventTypeRawValue = record.eventTypeRawValue,
              let eventType = CareEventType(rawValue: eventTypeRawValue)
        else {
            return nil
        }

        switch eventType {
        case .food:
            guard let name = record.foodName,
                  let foodTypeRawValue = record.foodTypeRawValue,
                  let foodType = FoodType(rawValue: foodTypeRawValue),
                  let amount = record.foodAmount,
                  let unitRawValue = record.foodUnitRawValue,
                  let unit = FoodUnit(rawValue: unitRawValue),
                  let calories = record.foodCalories
            else {
                return nil
            }

            return .food(FoodEventData(
                name: name,
                foodType: foodType,
                amount: amount,
                unit: unit,
                calories: calories
            ))

        case .litter:
            return .litter(LitterEventData())

        case .medicine:
            guard let name = record.medicineName,
                  let dosage = record.medicineDosage,
                  let unit = record.medicineUnit
            else {
                return nil
            }

            return .medicine(MedicineEventData(
                name: name,
                dosage: dosage,
                unit: unit
            ))
        }
    }

    private static func reminderSchedule(from record: ReminderRecord) -> ReminderSchedule? {
        let rule = recurrenceRule(
            kind: record.recurrenceKind,
            value: record.recurrenceValue,
            unitRawValue: record.recurrenceUnitRawValue,
            timesOfDayMinutes: record.timesOfDayMinutes
        )

        guard rule != nil || record.endDate != nil else {
            return nil
        }

        return ReminderSchedule(recurrenceRule: rule, endDate: record.endDate)
    }

    private static func medicineCadence(from record: SavedEventOptionRecord) -> MedicineCadence? {
        recurrenceRule(
            kind: record.medicineRecurrenceKind,
            value: record.medicineRecurrenceValue,
            unitRawValue: record.medicineRecurrenceUnitRawValue,
            timesOfDayMinutes: record.medicineTimesOfDayMinutes
        ).map(MedicineCadence.init(rule:))
    }

    private static func recurrenceRule(
        kind: String?,
        value: Int?,
        unitRawValue: String?,
        timesOfDayMinutes: String?
    ) -> RecurrenceRule? {
        switch kind {
        case "every":
            guard let value,
                  let unitRawValue,
                  let unit = RecurrenceUnit(rawValue: unitRawValue)
            else {
                return nil
            }

            return .every(value: value, unit: unit)

        case "timesPerDay":
            let minutes = decodeMinutes(timesOfDayMinutes)
            guard !minutes.isEmpty else {
                return nil
            }

            return .timesPerDay(
                count: value ?? minutes.count,
                times: minutes.map { DateComponents(hour: $0 / 60, minute: $0 % 60) }
            )

        default:
            return nil
        }
    }

    private static func apply(_ rule: RecurrenceRule?, toReminder record: ReminderRecord) {
        switch rule {
        case let .every(value, unit):
            record.recurrenceKind = "every"
            record.recurrenceValue = value
            record.recurrenceUnitRawValue = unit.rawValue
        case let .timesPerDay(count, times):
            record.recurrenceKind = "timesPerDay"
            record.recurrenceValue = count
            record.timesOfDayMinutes = encodeMinutes(times)
        case nil:
            break
        }
    }

    private static func apply(_ data: CareEventData?, toReminder record: ReminderRecord) {
        switch data {
        case let .food(data):
            record.foodName = data.name
            record.foodTypeRawValue = data.foodType.rawValue
            record.foodAmount = data.amount
            record.foodUnitRawValue = data.unit.rawValue
            record.foodCalories = data.calories

        case .litter:
            break

        case let .medicine(data):
            record.medicineName = data.name
            record.medicineDosage = data.dosage
            record.medicineUnit = data.unit

        case nil:
            break
        }
    }

    private static func apply(_ rule: RecurrenceRule?, toMedicine record: SavedEventOptionRecord) {
        switch rule {
        case let .every(value, unit):
            record.medicineRecurrenceKind = "every"
            record.medicineRecurrenceValue = value
            record.medicineRecurrenceUnitRawValue = unit.rawValue
        case let .timesPerDay(count, times):
            record.medicineRecurrenceKind = "timesPerDay"
            record.medicineRecurrenceValue = count
            record.medicineTimesOfDayMinutes = encodeMinutes(times)
        case nil:
            break
        }
    }

    private static func encodeMinutes(_ times: [DateComponents]) -> String {
        times
            .compactMap { time -> Int? in
                guard let hour = time.hour else {
                    return nil
                }

                return hour * 60 + (time.minute ?? 0)
            }
            .map(String.init)
            .joined(separator: ",")
    }

    private static func decodeMinutes(_ value: String?) -> [Int] {
        value?
            .split(separator: ",")
            .compactMap { Int($0) } ?? []
    }
}
