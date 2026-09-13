import Foundation

struct CareEventEditDraft {
    let original: CareEvent
    var timestamp: Date
    var petID: UUID?
    var name = ""
    var foodType = FoodType.dry
    var amount = 0.0
    var foodUnit = FoodUnit.cup
    var calories = 0
    var dosage = 0.0
    var medicineUnit = ""
    var savedMedicationID: UUID?

    init(event: CareEvent) {
        original = event
        timestamp = event.startTime
        petID = event.petID
        switch event.data {
        case let .food(data):
            name = data.name
            foodType = data.foodType
            amount = data.amount
            foodUnit = data.unit
            calories = data.calories
        case let .medicine(data):
            name = data.name
            dosage = data.dosage
            medicineUnit = data.unit
            savedMedicationID = data.savedOptionID
        case .litter: break
        }
    }

    var storedCalorieRate: Int? {
        guard case let .food(data) = original.data, data.unit == foodUnit else { return nil }
        return data.caloriesPerUnit.flatMap { $0 >= 0 ? $0 : nil }
    }

    mutating func recalculateCalories() {
        guard let rate = storedCalorieRate, amount.isFinite, amount >= 0,
              (amount * Double(rate)).rounded() < Double(Int.max) else { return }
        calories = FoodEventDataValidator.calories(amount: amount, caloriesPerUnit: rate)
    }

    func canSave(pets: [Pet]) -> Bool {
        guard timestamp.timeIntervalSinceReferenceDate.isFinite else { return false }
        let validPet = petID.map { id in pets.contains { $0.id == id } } ?? false
        switch original.type {
        case .food:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && amount.isFinite && amount >= 0 && calories >= 0
                && FoodUnit.options(for: foodType).contains(foodUnit)
                && (petID == nil || validPet)
        case .medicine:
            return validPet && dosage.isFinite && dosage > 0
                && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !medicineUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .litter: return true
        }
    }

    func makeEvent(pets: [Pet]) -> CareEvent? {
        guard canSave(pets: pets) else { return nil }
        var edited = original
        edited.startTime = timestamp
        edited.petID = petID
        switch original.type {
        case .food:
            var rate = storedCalorieRate
            if let candidate = rate {
                let calculated = amount * Double(candidate)
                if !calculated.isFinite || calculated.rounded() >= Double(Int.max)
                    || Int(calculated.rounded()) != calories { rate = nil }
            }
            edited.data = .food(FoodEventData(name: name, foodType: foodType, amount: amount,
                                             unit: foodUnit, calories: calories, caloriesPerUnit: rate))
        case .medicine:
            let previous = original.data
            var interval: MedicationDoseInterval?
            if case let .medicine(data) = previous, data.savedOptionID == savedMedicationID { interval = data.doseInterval }
            edited.data = .medicine(MedicineEventData(name: name, dosage: dosage, unit: medicineUnit,
                                                     savedOptionID: savedMedicationID, doseInterval: interval))
        case .litter:
            edited.petID = nil
        }
        return edited
    }
}
