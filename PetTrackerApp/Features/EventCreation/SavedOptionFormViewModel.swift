import Foundation

final class SavedOptionFormViewModel: ObservableObject {
    @Published var eventType: CareEventType
    @Published var name: String
    @Published var officialFoodName = ""
    @Published var medicinePurpose = ""
    private var medicineCadence: MedicineCadence?
    @Published var usesDoseTiming = false
    @Published var minimumDoseHours = 0.0
    @Published var maximumDoseHours = 0.0
    @Published var petDoseIntervals: [PetMedicationDoseInterval] = []
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
            officialFoodName = data.officialName ?? ""
            foodType = data.foodType
            foodUnit = data.unit
            caloriesPerUnit = data.caloriesPerUnit
        case let .medicine(data):
            name = data.name
            medicinePurpose = data.purpose ?? ""
            medicineCadence = data.cadence
            usesDoseTiming = data.doseInterval != nil
            minimumDoseHours = data.doseInterval?.minimumHours ?? 0
            maximumDoseHours = data.doseInterval?.maximumHours ?? 0
            petDoseIntervals = data.petDoseIntervals
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
                && FoodUnit.options(for: foodType).contains(foodUnit)
        case .medicine:
            return !trimmedName.isEmpty
                && dosage.isFinite && dosage > 0
                && !medicineUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (!usesDoseTiming || configuredDoseInterval.isValid)
                && petDoseIntervals.allSatisfy { $0.interval.isValid }
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
                foodType: foodType,
                officialName: officialFoodName
            ))
        case .medicine:
            data = .medicine(SavedMedicineData(
                name: name,
                dosage: dosage,
                unit: medicineUnit,
                cadence: medicineCadence,
                purpose: medicinePurpose,
                doseInterval: usesDoseTiming ? configuredDoseInterval : nil,
                petDoseIntervals: petDoseIntervals
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

    func makeAutoqueuedReminder(at date: Date = .now, savedOption: SavedEventOption? = nil) -> Reminder? {
        guard shouldAutoqueueReminder,
              eventType == .medicine,
              canSave(),
              !reminderPetIDs.isEmpty
        else {
            return nil
        }

        let medicine = MedicineEventData(name: name, dosage: dosage, unit: medicineUnit,
                                        savedOptionID: savedOption?.id,
                                        doseInterval: usesDoseTiming ? configuredDoseInterval : nil)
        let targets = reminderPetIDs.map { petID in
            var payload = medicine
            payload.doseInterval = petDoseIntervals.first { $0.petID == petID }?.interval ?? medicine.doseInterval
            return ReminderTarget(petID: petID, eventData: .medicine(payload))
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

    var configuredDoseInterval: MedicationDoseInterval {
        MedicationDoseInterval(minimumHours: minimumDoseHours, maximumHours: maximumDoseHours)
    }

    func setPetDoseIntervalEnabled(_ enabled: Bool, petID: UUID) {
        petDoseIntervals.removeAll { $0.petID == petID }
        if enabled {
            petDoseIntervals.append(PetMedicationDoseInterval(petID: petID,
                interval: MedicationDoseInterval(minimumHours: 0, maximumHours: 0)))
        }
    }

    func setPetDoseHours(_ hours: Double, petID: UUID, minimum: Bool) {
        guard let index = petDoseIntervals.firstIndex(where: { $0.petID == petID }) else { return }
        if minimum { petDoseIntervals[index].interval.minimumHours = hours }
        else { petDoseIntervals[index].interval.maximumHours = hours }
    }
}
