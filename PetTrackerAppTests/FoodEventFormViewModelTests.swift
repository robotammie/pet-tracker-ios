import XCTest
@testable import PetTrackerApp

final class FoodEventFormViewModelTests: XCTestCase {
    func testHouseholdSelectionClearsSelectedPetsAndAmounts() {
        let petID = UUID()
        let viewModel = FoodEventFormViewModel()

        viewModel.togglePet(petID)
        viewModel.petAmounts[petID] = 1
        viewModel.selectHousehold()

        XCTAssertTrue(viewModel.isHouseholdSelected)
        XCTAssertTrue(viewModel.selectedPetIDs.isEmpty)
        XCTAssertTrue(viewModel.petAmounts.isEmpty)
    }

    func testPetSelectionClearsHouseholdMode() {
        let petID = UUID()
        let viewModel = FoodEventFormViewModel()

        viewModel.togglePet(petID)

        XCTAssertFalse(viewModel.isHouseholdSelected)
        XCTAssertEqual(viewModel.selectedPetIDs, [petID])
    }

    func testTappingSelectedPetUnselectsIt() {
        let petID = UUID()
        let viewModel = FoodEventFormViewModel()

        viewModel.togglePet(petID)
        viewModel.togglePet(petID)

        XCTAssertTrue(viewModel.isHouseholdSelected)
        XCTAssertTrue(viewModel.selectedPetIDs.isEmpty)
    }

    func testHouseholdFoodCreatesOneGlobalEventWithCalculatedCalories() {
        let viewModel = FoodEventFormViewModel()
        let option = SavedEventOption(
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Wet Food",
                unit: .ounce,
                caloriesPerUnit: 42,
                foodType: .wet
            ))
        )

        viewModel.selectSavedOption(option)
        viewModel.householdAmount = 2

        let events = viewModel.makeEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.petID)

        guard case let .food(data) = events.first?.data else {
            return XCTFail("Expected food event data")
        }

        XCTAssertEqual(data.name, "Wet Food")
        XCTAssertEqual(data.amount, 2)
        XCTAssertEqual(data.unit, .ounce)
        XCTAssertEqual(data.calories, 84)
    }

    func testPetFoodCreatesOneEventPerNonzeroPetAmount() {
        let appaID = UUID()
        let tupoID = UUID()
        let viewModel = FoodEventFormViewModel()
        let option = SavedEventOption(
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Dinner",
                unit: .cup,
                caloriesPerUnit: 100,
                foodType: .dry
            ))
        )

        viewModel.selectSavedOption(option)
        viewModel.togglePet(appaID)
        viewModel.togglePet(tupoID)
        viewModel.petAmounts[appaID] = 2
        viewModel.petAmounts[tupoID] = 0

        let events = viewModel.makeEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.petID, appaID)

        guard case let .food(data) = events.first?.data else {
            return XCTFail("Expected food event data")
        }

        XCTAssertEqual(data.calories, 200)
    }
}
