import SwiftUI

struct EventListView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var selectedType = CareEventType.food

    private var filteredEvents: [CareEvent] {
        store.events
            .filter { $0.type == selectedType }
            .sorted { $0.startTime > $1.startTime }
    }

    private var eventSections: [(day: Date, events: [CareEvent])] {
        filteredEvents.groupedByDay()
    }

    var body: some View {
        List {
            Picker("Event type", selection: $selectedType) {
                ForEach(CareEventType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Section(selectedType.rawValue) {
                if filteredEvents.isEmpty {
                    ContentUnavailableView("No events yet", systemImage: "calendar.badge.exclamationmark")
                }
            }

            ForEach(eventSections, id: \.day) { section in
                Section {
                    ForEach(section.events) { event in
                        EventSummaryRow(event: event, petName: store.petName(for: event.petID))
                    }
                } header: {
                    Text(section.day.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .navigationTitle("Events")
    }
}

#Preview {
    NavigationStack {
        EventListView()
            .environmentObject(PetCareStore.preview)
    }
}
