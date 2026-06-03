import Foundation

final class SavedOptionFormViewModel: ObservableObject {
    @Published var eventType: CareEventType
    @Published var name: String
    @Published var foodType: FoodType
    @Published var foodUnit: FoodUnit
    @Published var caloriesPerUnit: Int
    @Published var dosage: Double
    @Published var medicineUnit: String

    init(option: SavedEventOption? = nil, eventType: CareEventType = .food) {
        self.eventType = option?.eventType ?? eventType
        self.name = ""
        self.foodType = .dry
        self.foodUnit = .cup
        self.caloriesPerUnit = 0
        self.dosage = 0
        self.medicineUnit = ""

        guard let option else {
            return
        }

        switch option.data {
        case let .food(data):
            name = data.name
            foodType = data.foodType
            foodUnit = data.unit
            caloriesPerUnit = data.caloriesPerUnit
        case let .medicine(data):
            name = data.name
            dosage = data.dosage
            medicineUnit = data.unit
        }
    }
}
