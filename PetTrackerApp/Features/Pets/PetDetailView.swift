import SwiftUI

private enum PetDetailSection { case care, health }

struct PetDetailView: View {
    @EnvironmentObject private var store: PetCareStore
    let pet: Pet
    @State private var selectedSection: PetDetailSection

    init(pet: Pet, initialHealth: Bool = false) {
        self.pet = pet
        _selectedSection = State(initialValue: initialHealth ? .health : .care)
    }

    private var events: [CareEvent] {
        store.events(for: pet)
    }

    private var eventSections: [(day: Date, events: [CareEvent])] {
        events.groupedByDay()
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("History", selection: $selectedSection) {
                Text("Care").tag(PetDetailSection.care)
                Text("Health").tag(PetDetailSection.health)
            }
            .pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8)
            .accessibilityIdentifier("petDetail.history")
            if selectedSection == .health { HealthTimelineView(pet: pet) }
            else { careList }
        }
        .navigationTitle(pet.name)
    }

    private var careList: some View {
        List {
            Section {
                HStack {
                    Text("Daily goal")
                    Spacer()
                    Text(goalSummary)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if events.isEmpty {
                    ContentUnavailableView("No events yet", systemImage: "pawprint")
                }
            }

            ForEach(eventSections, id: \.day) { section in
                Section {
                    ForEach(section.events) { event in
                        EventSummaryRow(event: event, petName: store.petName(for: event.petID))
                    }
                } header: {
                    Text(dayHeader(for: section.day))
                }
            }
        }
    }

    private var goalSummary: String {
        guard let goal = pet.caloriesPerDay else {
            return "Not set"
        }

        return "\(goal) cal"
    }

    private func dayHeader(for day: Date) -> String {
        let calories = store.calories(for: pet, on: day)
        let date = day.formatted(date: .abbreviated, time: .omitted)

        guard let goal = pet.caloriesPerDay else {
            return "\(date) · \(calories) cal"
        }

        return "\(date) · \(calories) / \(goal) cal"
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: PetCareStore.preview.pets[0])
            .environmentObject(PetCareStore.preview)
    }
}
