import XCTest
@testable import PetTrackerApp

final class DomainValidationTests: XCTestCase {
    func testFoodCaloriesAreRoundedAndStored() throws {
        let data = try FoodEventDataValidator.make(
            name: "Hills Dry",
            foodType: .dry,
            amount: 0.25,
            unit: .cup,
            caloriesPerUnit: 381
        )

        XCTAssertEqual(data.calories, 95)
    }

    func testFoodValidationRequiresName() {
        XCTAssertThrowsError(
            try FoodEventDataValidator.make(name: "   ", caloriesPerUnit: 100)
        ) { error in
            XCTAssertEqual(error as? PayloadValidationError, .missingRequiredField("name"))
        }
    }

    func testMultiPetFoodCreationIgnoresBlankOrZeroAmounts() {
        let lunaID = UUID()
        let misoID = UUID()
        let food = SavedFoodData(
            name: "Dinner",
            unit: .cup,
            caloriesPerUnit: 200,
            foodType: .dry
        )

        let events = MultiPetFoodEventFactory.makeEvents(
            petAmounts: [
                lunaID: 0.5,
                misoID: 0
            ],
            food: food,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.petID, lunaID)

        guard case let .food(data) = events.first?.data else {
            return XCTFail("Expected food event data")
        }

        XCTAssertEqual(data.calories, 100)
    }

    func testMedicineValidationRequiresDosageAndUnit() {
        XCTAssertThrowsError(
            try MedicineEventDataValidator.make(name: "Antibiotic", dosage: 0, unit: "tablet")
        ) { error in
            XCTAssertEqual(error as? PayloadValidationError, .missingRequiredField("dosage"))
        }

        XCTAssertThrowsError(
            try MedicineEventDataValidator.make(name: "Antibiotic", dosage: 1, unit: " ")
        ) { error in
            XCTAssertEqual(error as? PayloadValidationError, .missingRequiredField("unit"))
        }
    }
}
