import XCTest
@testable import PetTrackerApp

final class MedicineEventFormViewModelTests: XCTestCase {
    func testSelectingMedicineDefaultsDoseForSelectedPets() {
        let petID = UUID()
        let viewModel = MedicineEventFormViewModel()
        let option = SavedEventOption(
            eventType: .medicine,
            data: .medicine(SavedMedicineData(
                name: "Pill",
                dosage: 0.5,
                unit: "tablet"
            ))
        )

        viewModel.selectSavedOption(option)
        viewModel.togglePet(petID)

        XCTAssertEqual(viewModel.petDosages[petID], 0.5)
    }

    func testMedicineCreatesOneEventPerSelectedPetWithNonzeroDose() {
        let appaID = UUID()
        let tupoID = UUID()
        let viewModel = MedicineEventFormViewModel()
        let option = SavedEventOption(
            eventType: .medicine,
            data: .medicine(SavedMedicineData(
                name: "Pill",
                dosage: 1,
                unit: "tablet"
            ))
        )

        viewModel.selectSavedOption(option)
        viewModel.togglePet(appaID)
        viewModel.togglePet(tupoID)
        viewModel.petDosages[appaID] = 2
        viewModel.petDosages[tupoID] = 0

        let events = viewModel.makeEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.petID, appaID)

        guard case let .medicine(data) = events.first?.data else {
            return XCTFail("Expected medicine event data")
        }

        XCTAssertEqual(data.name, "Pill")
        XCTAssertEqual(data.dosage, 2)
        XCTAssertEqual(data.unit, "tablet")
    }
}
