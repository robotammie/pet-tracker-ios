import SwiftUI

struct PetDetailView: View {
    @EnvironmentObject private var store: PetCareStore
    let pet: Pet

    private var events: [CareEvent] {
        store.events(for: pet)
    }

    var body: some View {
        List {
            Section("Today") {
                let calories = store.calories(for: pet, on: .now)

                HStack {
                    Text("Calories")
                    Spacer()
                    Text(calorieSummary(calories))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Care Events") {
                if events.isEmpty {
                    ContentUnavailableView("No events yet", systemImage: "pawprint")
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if event.petID == nil {
                                    Label("Household", systemImage: "house")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(pet.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Text(event.startTime, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            EventSummaryText(event: event)
                        }
                    }
                }
            }
        }
        .navigationTitle(pet.name)
    }

    private func calorieSummary(_ calories: Int) -> String {
        guard let goal = pet.caloriesPerDay else {
            return "\(calories) cal"
        }

        return "\(calories) / \(goal) cal"
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: PetCareStore.preview.pets[0])
            .environmentObject(PetCareStore.preview)
    }
}
