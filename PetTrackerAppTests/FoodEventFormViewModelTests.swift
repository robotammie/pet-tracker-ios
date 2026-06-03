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
}
