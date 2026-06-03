import Foundation

final class MedicineEventFormViewModel: ObservableObject {
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
        }
    }
}
