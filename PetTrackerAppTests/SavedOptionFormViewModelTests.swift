import XCTest
@testable import PetTrackerApp

final class SavedOptionFormViewModelTests: XCTestCase {
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
}
