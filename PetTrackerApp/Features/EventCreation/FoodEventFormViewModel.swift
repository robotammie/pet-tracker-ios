import Foundation

final class FoodEventFormViewModel: ObservableObject {
    enum Destination: Equatable {
        case household
        case pets(Set<UUID>)
    }

    @Published var selectedSavedOptionID: UUID?
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

    func selectSavedOption(_ option: SavedEventOption?) {
        selectedSavedOptionID = option?.id

        guard let option,
              case let .food(food) = option.data
        else {
            selectedFood = nil
            return
        }

        selectedFood = food
    }

    func canSave() -> Bool {
        guard selectedFood != nil else {
            return false
        }

        switch destination {
        case .household:
            return householdAmount > 0
        case let .pets(ids):
            return ids.contains { (petAmounts[$0] ?? 0) > 0 }
        }
    }

    func makeEvents() -> [CareEvent] {
        guard let selectedFood else {
            return []
        }

        switch destination {
        case .household:
            guard householdAmount > 0 else {
                return []
            }

            return [
                CareEvent(
                    type: .food,
                    petID: nil,
                    startTime: timestamp,
                    data: .food(FoodEventData(
                        name: selectedFood.name,
                        foodType: selectedFood.foodType,
                        amount: householdAmount,
                        unit: selectedFood.unit,
                        calories: calories(for: householdAmount)
                    ))
                )
            ]

        case .pets:
            return MultiPetFoodEventFactory.makeEvents(
                petAmounts: petAmounts,
                food: selectedFood,
                timestamp: timestamp
            )
        }
    }
}
