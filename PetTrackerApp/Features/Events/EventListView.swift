import SwiftUI

struct EventListView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var selectedType = CareEventType.food
    @State private var petFilter = EventPetFilter.all
    @State private var editingEvent: CareEvent?

    init(initialSelectedType: CareEventType = .food) {
        _selectedType = State(initialValue: initialSelectedType)
    }

    private var filteredEvents: [CareEvent] {
        store.events
            .filter { $0.type == selectedType && petFilter.includes($0) }
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

            Picker("For", selection: $petFilter) {
                Text("All pets").tag(EventPetFilter.all)
                Text("Household").tag(EventPetFilter.household)
                ForEach(store.pets) { pet in
                    Text(pet.name).tag(EventPetFilter.pet(pet.id))
                }
            }
            .accessibilityIdentifier("events.petFilter")

            Section(selectedType.rawValue) {
                if filteredEvents.isEmpty {
                    ContentUnavailableView("No events yet", systemImage: "calendar.badge.exclamationmark")
                }
            }

            ForEach(eventSections, id: \.day) { section in
                Section {
                    ForEach(section.events) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            EventSummaryRow(event: event, petName: store.petName(for: event.petID))
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("events.edit.\(event.id.uuidString)")
                    }
                } header: {
                    Text(section.day.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .navigationTitle("Events")
        .sheet(item: $editingEvent) { event in
            CareEventEditorView(event: event)
                .environmentObject(store)
        }
    }
}

enum EventPetFilter: Hashable {
    case all
    case household
    case pet(UUID)

    func includes(_ event: CareEvent) -> Bool {
        switch self {
        case .all: return true
        case .household: return event.petID == nil
        case let .pet(id): return event.petID == id
        }
    }
}

#Preview {
    NavigationStack {
        EventListView()
            .environmentObject(PetCareStore.preview)
    }
}
