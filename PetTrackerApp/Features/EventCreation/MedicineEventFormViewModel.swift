import Foundation

final class MedicineEventFormViewModel: ObservableObject {
    @Published var selectedSavedOptionID: UUID?
    @Published var selectedMedicine: SavedMedicineData?
    @Published var selectedPetIDs: Set<UUID> = []
    @Published var timestamp: Date = .now
    @Published var petDosages: [UUID: Double] = [:]

    func togglePet(_ petID: UUID) {
        if selectedPetIDs.contains(petID) {
            selectedPetIDs.remove(petID)
            petDosages[petID] = nil
        } else {
            selectedPetIDs.insert(petID)
            petDosages[petID] = selectedMedicine?.dosage ?? 0
        }
    }

    func selectSavedOption(_ option: SavedEventOption?) {
        selectedSavedOptionID = option?.id

        guard let option,
              case let .medicine(medicine) = option.data
        else {
            selectedMedicine = nil
            petDosages.removeAll()
            return
        }

        selectedMedicine = medicine

        selectedPetIDs.forEach { petID in
            if (petDosages[petID] ?? 0) == 0 {
                petDosages[petID] = medicine.dosage
            }
        }
    }

    func canSave() -> Bool {
        guard selectedMedicine != nil, !selectedPetIDs.isEmpty else {
            return false
        }

        return selectedPetIDs.contains { (petDosages[$0] ?? 0) > 0 }
    }

    func makeEvents() -> [CareEvent] {
        guard let selectedMedicine else {
            return []
        }

        return selectedPetIDs.compactMap { petID in
            let dosage = petDosages[petID] ?? 0

            guard dosage > 0 else {
                return nil
            }

            return CareEvent(
                type: .medicine,
                petID: petID,
                startTime: timestamp,
                data: .medicine(MedicineEventData(
                    name: selectedMedicine.name,
                    dosage: dosage,
                    unit: selectedMedicine.unit
                ))
            )
        }
    }
}
