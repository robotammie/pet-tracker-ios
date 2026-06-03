import SwiftUI

struct PetListView: View {
    @EnvironmentObject private var store: PetCareStore

    var body: some View {
        List {
            if store.pets.isEmpty {
                ContentUnavailableView("No pets yet", systemImage: "pawprint")
            } else {
                ForEach(store.pets) { pet in
                    NavigationLink {
                        PetDetailView(pet: pet)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pet.name)
                                .font(.headline)

                            if let goal = pet.caloriesPerDay {
                                Text("\(goal) cal/day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Pets")
    }
}

#Preview {
    NavigationStack {
        PetListView()
            .environmentObject(PetCareStore.preview)
    }
}
