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

    func testInlineNewOptionAppliesNewDoseUnitIdentityAndPreservesPetAndTime() {
        let petID = UUID()
        let viewModel = MedicineEventFormViewModel()
        viewModel.timestamp = Date(timeIntervalSince1970: 1_000_000)
        viewModel.togglePet(petID)
        let old = SavedEventOption(eventType: .medicine, data: .medicine(SavedMedicineData(name: "Old", dosage: 1, unit: "tablet")))
        viewModel.selectSavedOption(old)
        let interval = MedicationDoseInterval(minimumHours: 8, maximumHours: 12)
        let option = SavedEventOption(eventType: .medicine, data: .medicine(SavedMedicineData(name: "New", dosage: 2, unit: "mL", doseInterval: interval)))
        viewModel.selectNewSavedOption(option)
        let event = viewModel.makeEvents().first
        XCTAssertEqual(event?.petID, petID)
        XCTAssertEqual(event?.startTime, viewModel.timestamp)
        guard case let .medicine(data) = event?.data else { return XCTFail("Expected dose") }
        XCTAssertEqual(data.dosage, 2)
        XCTAssertEqual(data.unit, "mL")
        XCTAssertEqual(data.savedOptionID, option.id)
        XCTAssertEqual(data.doseInterval, interval)
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
