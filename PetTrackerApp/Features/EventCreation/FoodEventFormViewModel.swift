import Foundation

final class FoodEventFormViewModel: ObservableObject {
    enum Destination: Equatable {
        case household
        case pets(Set<UUID>)
    }

    @Published var selectedFood: SavedFoodData?
    @Published var destination: Destination = .household
    @Published var timestamp: Date = .now
    @Published var householdAmount: Double = 0
    @Published var petAmounts: [UUID: Double] = [:]

    var selectedPetIDs: Set<UUID> {
        if case let .pets(ids) = destination {
            return ids
        }

        return []
    }

    var isHouseholdSelected: Bool {
        destination == .household
    }

    func selectHousehold() {
        destination = .household
        petAmounts.removeAll()
    }

    func togglePet(_ petID: UUID) {
        var ids = selectedPetIDs

        if ids.contains(petID) {
            ids.remove(petID)
            petAmounts[petID] = nil
        } else {
            ids.insert(petID)
        }

        destination = ids.isEmpty ? .household : .pets(ids)
    }

    func calories(for amount: Double) -> Int {
        guard let selectedFood else {
            return 0
        }

        return FoodEventDataValidator.calories(
            amount: amount,
            caloriesPerUnit: selectedFood.caloriesPerUnit
        )
    }
}
