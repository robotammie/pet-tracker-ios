import XCTest
@testable import PetTrackerApp

final class SavedOptionFormViewModelTests: XCTestCase {
    func testWetFoodCanUsesDisplayNameAndCaloriesPerCan() throws {
        let viewModel = SavedOptionFormViewModel(eventType: .food)
        viewModel.name = "Hill's"
        viewModel.officialFoodName = "  Hill's Gastrointestinal Biome for Adult Cats  "
        viewModel.foodType = .wet
        viewModel.foodUnit = .can
        viewModel.caloriesPerUnit = 90
        let option = try XCTUnwrap(viewModel.makeOption())
        let creation = FoodEventFormViewModel()
        creation.selectSavedOption(option)
        creation.householdAmount = 0.5
        guard case let .food(data) = creation.makeEvents().first?.data else {
            return XCTFail("Expected food event")
        }
        XCTAssertEqual(data.name, "Hill's")
        XCTAssertEqual(data.unit, .can)
        XCTAssertEqual(data.calories, 45)
        viewModel.foodType = .dry
        XCTAssertFalse(viewModel.canSave())
        XCTAssertFalse(FoodUnit.options(for: .treat).contains(.can))
    }

    func testMedicinePurposeEditPreservesCadence() throws {
        let cadence = MedicineCadence(rule: .every(value: 12, unit: .hour))
        let original = SavedEventOption(eventType: .medicine,
            data: .medicine(SavedMedicineData(name: "Pill", dosage: 1, unit: "tablet", cadence: cadence)))
        let viewModel = SavedOptionFormViewModel(option: original)
        viewModel.medicinePurpose = "  Antibiotic  "
        let saved = try XCTUnwrap(viewModel.makeOption(existing: original))
        guard case let .medicine(data) = saved.data else { return XCTFail("Expected medicine") }
        XCTAssertEqual(data.purpose, "Antibiotic")
        XCTAssertEqual(data.cadence, cadence)
    }
    func testFoodOptionRequiresNameAndCalories() {
        let viewModel = SavedOptionFormViewModel(eventType: .food)

        viewModel.name = "Wet Food"
        viewModel.caloriesPerUnit = 0

        XCTAssertFalse(viewModel.canSave())

        viewModel.caloriesPerUnit = 80

        XCTAssertTrue(viewModel.canSave())
    }

    func testFoodOptionPreservesExistingIDWhenEdited() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let option = SavedEventOption(
            id: id,
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Dry Food",
                unit: .cup,
                caloriesPerUnit: 300,
                foodType: .dry
            )),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let viewModel = SavedOptionFormViewModel(option: option)

        viewModel.name = "Edited Dry Food"
        let edited = viewModel.makeOption(existing: option, at: updatedAt)

        XCTAssertEqual(edited?.id, id)
        XCTAssertEqual(edited?.createdAt, createdAt)
        XCTAssertEqual(edited?.updatedAt, updatedAt)

        guard case let .food(data) = edited?.data else {
            return XCTFail("Expected food option data")
        }

        XCTAssertEqual(data.name, "Edited Dry Food")
    }

    func testMedicineOptionRequiresNameDoseAndUnit() {
        let viewModel = SavedOptionFormViewModel(eventType: .medicine)

        viewModel.name = "Pill"
        viewModel.dosage = 1
        viewModel.medicineUnit = ""

        XCTAssertFalse(viewModel.canSave())

        viewModel.medicineUnit = "tablet"

        XCTAssertTrue(viewModel.canSave())
    }

    func testMedicineOptionDoesNotAddCadenceWithoutScheduleControls() {
        let viewModel = SavedOptionFormViewModel(eventType: .medicine)
        viewModel.name = "Pill"
        viewModel.dosage = 1
        viewModel.medicineUnit = "tablet"

        let option = viewModel.makeOption()

        guard case let .medicine(data) = option?.data else {
            return XCTFail("Expected medicine option data")
        }

        XCTAssertNil(data.cadence)
    }
}
