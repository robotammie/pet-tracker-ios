import SwiftUI

struct EventTimestampSection: View {
    @Binding var timestamp: Date

    var body: some View {
        Section("When") {
            DatePicker("Time", selection: $timestamp)
        }
    }
}

struct PetSelectionSection: View {
    let pets: [Pet]
    let selectedPetIDs: Set<UUID>
    let title: String
    var includesHousehold = false
    var isHouseholdSelected = false
    var householdTitle = "Household"
    var householdSystemImage = "house"
    let togglePet: (UUID) -> Void
    var selectHousehold: (() -> Void)?

    var body: some View {
        Section("For") {
            Menu {
                if includesHousehold {
                    Button {
                        selectHousehold?()
                    } label: {
                        Label(
                            householdTitle,
                            systemImage: isHouseholdSelected ? "checkmark" : householdSystemImage
                        )
                    }
                }

                ForEach(pets) { pet in
                    Button {
                        togglePet(pet.id)
                    } label: {
                        Label(
                            pet.name,
                            systemImage: selectedPetIDs.contains(pet.id) ? "checkmark" : "cat"
                        )
                    }
                }
            } label: {
                Label(title, systemImage: includesHousehold ? "person.2" : "person")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("eventCreation.destination")
        }
    }
}

enum EventCreationSelectionText {
    static func petNames(
        selectedPetIDs: Set<UUID>,
        pets: [Pet],
        emptyTitle: String = "Choose pets"
    ) -> String {
        let names = sortedSelectedPets(selectedPetIDs: selectedPetIDs, pets: pets).map(\.name)
        return names.isEmpty ? emptyTitle : names.joined(separator: ", ")
    }

    static func sortedSelectedPets(selectedPetIDs: Set<UUID>, pets: [Pet]) -> [Pet] {
        pets
            .filter { selectedPetIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
