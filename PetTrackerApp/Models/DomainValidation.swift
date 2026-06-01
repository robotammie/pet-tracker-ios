import Foundation

enum PayloadValidationError: Error, Equatable {
    case missingRequiredField(String)
}

enum FoodEventDataValidator {
    static func calories(amount: Double, caloriesPerUnit: Int) -> Int {
        max(0, Int((amount * Double(max(0, caloriesPerUnit))).rounded()))
    }

    static func make(
        name: String,
        foodType: FoodType = .dry,
        amount: Double = 0,
        unit: FoodUnit = .cup,
        caloriesPerUnit: Int = 0
    ) throws -> FoodEventData {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            throw PayloadValidationError.missingRequiredField("name")
        }

        return FoodEventData(
            name: cleanName,
            foodType: foodType,
            amount: amount,
            unit: unit,
            calories: calories(amount: amount, caloriesPerUnit: caloriesPerUnit)
        )
    }
}

enum MedicineEventDataValidator {
    static func make(name: String, dosage: Double, unit: String) throws -> MedicineEventData {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            throw PayloadValidationError.missingRequiredField("name")
        }

        guard dosage > 0 else {
            throw PayloadValidationError.missingRequiredField("dosage")
        }

        guard !cleanUnit.isEmpty else {
            throw PayloadValidationError.missingRequiredField("unit")
        }

        return MedicineEventData(name: cleanName, dosage: dosage, unit: cleanUnit)
    }
}

enum MultiPetFoodEventFactory {
    static func makeEvents(
        petAmounts: [UUID: Double],
        food: SavedFoodData,
        timestamp: Date
    ) -> [CareEvent] {
        petAmounts.compactMap { petID, amount in
            guard amount > 0 else {
                return nil
            }

            let data = FoodEventData(
                name: food.name,
                foodType: food.foodType,
                amount: amount,
                unit: food.unit,
                calories: FoodEventDataValidator.calories(
                    amount: amount,
                    caloriesPerUnit: food.caloriesPerUnit
                )
            )

            return CareEvent(
                type: .food,
                petID: petID,
                startTime: timestamp,
                data: .food(data)
            )
        }
    }
}
