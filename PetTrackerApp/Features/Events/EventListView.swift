import SwiftUI

struct EventListView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var selectedType = CareEventType.food
    @State private var petFilter = EventPetFilter.all
    @State private var editingEvent: CareEvent?
    @State private var creationRoute: EventCreationRoute?
    @State private var deletingEvent: CareEvent?
    @State private var isRecurringExpanded = false
    @State private var scheduledEventRoute: ScheduledEventEditorRoute?
    @State private var deletingSchedule: ScheduledEvent?

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

    private var recurringEvents: [ScheduledEvent] {
        store.scheduledEvents.filter { schedule in
            guard schedule.isActive, schedule.type == selectedType else { return false }
            switch petFilter {
            case .all: return true
            case .household: return schedule.petID == nil
            case let .pet(id): return schedule.petID == id
            }
        }.sorted { ($0.nextDueAt ?? .distantFuture) < ($1.nextDueAt ?? .distantFuture) }
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

            Section {
                HStack {
                    Text(selectedType.rawValue).font(.title2.bold())
                    Spacer()
                    Button { creationRoute = .event(selectedType) } label: {
                        Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add \(selectedType.rawValue.lowercased()) event")
                    .accessibilityIdentifier("events.add")
                }
                DisclosureGroup("Recurring", isExpanded: $isRecurringExpanded) {
                    if recurringEvents.isEmpty { Text("No active recurring events").foregroundStyle(.secondary) }
                    ForEach(recurringEvents) { schedule in
                        Button { scheduledEventRoute = ScheduledEventEditorRoute(scheduledEvent: schedule) } label: {
                            ScheduledEventSummaryRow(scheduledEvent: schedule)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("scheduledEvent.row.\(schedule.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete") { deletingSchedule = schedule }.tint(.red)
                                .accessibilityIdentifier("scheduledEvent.delete")
                            Button("Edit") { scheduledEventRoute = ScheduledEventEditorRoute(scheduledEvent: schedule) }
                        }
                    }
                }
                .accessibilityIdentifier("events.recurring")
            }
            Section {
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete") { deletingEvent = event }.tint(.red)
                                .accessibilityIdentifier("events.delete")
                        }
                    }
                } header: {
                    Text(section.day.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .navigationTitle("Events")
        .onChange(of: selectedType) { _, _ in isRecurringExpanded = false }
        .sheet(item: $scheduledEventRoute) { route in
            ScheduledEventEditorView(scheduledEvent: route.scheduledEvent)
        }
        .alert("Delete recurring event?", isPresented: Binding(
            get: { deletingSchedule != nil }, set: { if !$0 { deletingSchedule = nil } }
        ), presenting: deletingSchedule) { schedule in
            Button("Delete", role: .destructive) { store.deleteScheduledEventAndRefresh(id: schedule.id) }
            Button("Cancel", role: .cancel) { }
        } message: { _ in Text("Future events will stop. Events already logged are kept.") }
        .sheet(item: $creationRoute) { route in EventCreationSheet(route: route) }
        .alert("Delete event?", isPresented: Binding(
            get: { deletingEvent != nil }, set: { if !$0 { deletingEvent = nil } }), presenting: deletingEvent) { event in
            Button("Delete", role: .destructive) { store.deleteCareEventAndRefresh(id: event.id) }
                .accessibilityIdentifier("events.confirmDelete")
            Button("Cancel", role: .cancel) { }.accessibilityIdentifier("events.cancelDelete")
        } message: { _ in
            Text("This permanently removes the logged event. Reminder completion history stays as recorded.")
        }
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
