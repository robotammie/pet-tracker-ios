import Foundation

final class SavedOptionFormViewModel: ObservableObject {
    @Published var eventType: CareEventType
    @Published var name: String
    @Published var foodType: FoodType
    @Published var foodUnit: FoodUnit
    @Published var caloriesPerUnit: Int
    @Published var dosage: Double
    @Published var medicineUnit: String
    @Published var shouldAutoqueueReminder = false
    @Published var reminderPetIDs: Set<UUID> = []
    @Published var reminderDueAt: Date = .now
    @Published var reminderMode: ReminderMode = .reminderToEvent

    init(option: SavedEventOption? = nil, eventType: CareEventType = .food) {
        self.eventType = option?.eventType ?? eventType
        self.name = ""
        self.foodType = .dry
        self.foodUnit = .cup
        self.caloriesPerUnit = 0
        self.dosage = 0
        self.medicineUnit = ""

        guard let option else {
            return
        }

        switch option.data {
        case let .food(data):
            name = data.name
            foodType = data.foodType
            foodUnit = data.unit
            caloriesPerUnit = data.caloriesPerUnit
        case let .medicine(data):
            name = data.name
            dosage = data.dosage
            medicineUnit = data.unit
        }
    }

    func toggleReminderPet(_ petID: UUID) {
        if reminderPetIDs.contains(petID) {
            reminderPetIDs.remove(petID)
        } else {
            reminderPetIDs.insert(petID)
        }
    }

    func canSave() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        switch eventType {
        case .food:
            return !trimmedName.isEmpty && caloriesPerUnit > 0
        case .medicine:
            return !trimmedName.isEmpty
                && dosage > 0
                && !medicineUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .litter:
            return false
        }
    }

    func makeOption(existing option: SavedEventOption? = nil, at date: Date = .now) -> SavedEventOption? {
        guard canSave() else {
            return nil
        }

        let data: SavedOptionData

        switch eventType {
        case .food:
            data = .food(SavedFoodData(
                name: name,
                unit: foodUnit,
                caloriesPerUnit: caloriesPerUnit,
                foodType: foodType
            ))
        case .medicine:
            data = .medicine(SavedMedicineData(
                name: name,
                dosage: dosage,
                unit: medicineUnit,
                cadence: MedicineCadence(rule: .every(value: 1, unit: .day))
            ))
        case .litter:
            return nil
        }

        return SavedEventOption(
            id: option?.id ?? UUID(),
            eventType: eventType,
            data: data,
            createdAt: option?.createdAt ?? date,
            updatedAt: date,
            deletedAt: option?.deletedAt
        )
    }

    func makeAutoqueuedReminder(at date: Date = .now) -> Reminder? {
        guard shouldAutoqueueReminder,
              eventType == .medicine,
              canSave(),
              !reminderPetIDs.isEmpty
        else {
            return nil
        }

        let medicine = MedicineEventData(name: name, dosage: dosage, unit: medicineUnit)
        let targets = reminderPetIDs.map { petID in
            ReminderTarget(petID: petID, eventData: .medicine(medicine))
        }

        return Reminder(
            title: name,
            mode: reminderMode,
            eventType: .medicine,
            eventData: .medicine(medicine),
            dueAt: reminderDueAt,
            dueStyle: .timestamp,
            schedule: ReminderSchedule(
                recurrenceRule: .every(value: 1, unit: .day),
                endDate: nil
            ),
            targets: targets
        )
    }
}
