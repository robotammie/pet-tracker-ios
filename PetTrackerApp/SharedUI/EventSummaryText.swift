import SwiftUI

struct EventSummaryText: View {
    let event: CareEvent

    var body: some View {
        switch event.data {
        case let .food(data):
            Text("\(data.name) · \(data.amount.formatted()) \(data.unit.rawValue) · \(data.calories) cal")
        case .litter:
            Text("Litter cleaned")
        case let .medicine(data):
            Text("\(data.name) · \(data.dosage.formatted()) \(data.unit)")
        }
    }
}
