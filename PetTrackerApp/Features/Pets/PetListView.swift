import SwiftUI

struct PetListView: View {
    @EnvironmentObject private var store: PetCareStore

    @State private var editorRoute: PetEditorRoute?

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editorRoute = PetEditorRoute() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add pet").accessibilityIdentifier("pets.add")
            }
        }
        .sheet(item: $editorRoute) { route in PetEditorView(pet: route.pet) }
    }
}

#Preview {
    NavigationStack {
        PetListView()
            .environmentObject(PetCareStore.preview)
    }
}
