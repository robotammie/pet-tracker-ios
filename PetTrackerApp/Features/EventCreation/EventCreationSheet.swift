import SwiftUI

struct EventCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: EventCreationRoute

    var body: some View {
        NavigationStack {
            destination
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var destination: some View {
        switch route {
        case let .event(type):
            switch type {
            case .food:
                FoodEventCreationView()
            case .medicine:
                MedicineEventCreationView()
            case .litter:
                LitterEventCreationView()
            }
        case let .savedOptions(type):
            SavedOptionsListView(eventType: type)
        }
    }
}

#Preview {
    EventCreationSheet(route: .event(.food))
        .environmentObject(PetCareStore.preview)
}
