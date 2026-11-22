import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var isDueExpanded = true
    @State private var isRecentExpanded = true
    @State private var healthRoute: HealthEditorRoute?
    @State private var creationRoute: EventCreationRoute?
    @State private var editingEvent: CareEvent?
    @State private var reminderRoute: ReminderEditorRoute?
    @State private var deletingReminder: Reminder?
    @State private var deletingItem: HomeRecentItem?
    private let calendar = Calendar.current

    var body: some View {
        List {
            Section("Quick Add") {
                quickAddButtons
            }

            Section {
                DisclosureGroup(isExpanded: $isDueExpanded) {
                    dueSoonContent
                } label: {
                    Label("Due", systemImage: "bell")
                        .font(.headline)
                }
            }

            Section {
                DisclosureGroup(isExpanded: $isRecentExpanded) {
                    recentContent
                } label: {
                    Label("Recent", systemImage: "clock")
                        .font(.headline)
                }
            }
        }
        .navigationTitle("Pet Tracker")
        .sheet(item: $healthRoute) { route in
            HealthEntryEditorView(entry: route.entry, petID: route.petID)
        }
        .sheet(item: $editingEvent) { event in
            CareEventEditorView(event: event)
        }
        .sheet(item: $reminderRoute) { route in
            ReminderEditorView(reminder: route.reminder)
        }
        .reminderDeletionAlert(reminder: $deletingReminder)
        .alert("Delete event?", isPresented: Binding(
            get: { deletingItem != nil },
            set: { if !$0 { deletingItem = nil } }
        ), presenting: deletingItem) { item in
            Button("Delete", role: .destructive) {
                switch item {
                case let .care(event): store.deleteCareEventAndRefresh(id: event.id)
                case let .health(entry): store.deleteHealthEntryAndRefresh(id: entry.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This permanently removes the logged entry. Reminder completion history stays as recorded.")
        }
        .sheet(item: $creationRoute) { route in
            EventCreationSheet(route: route)
                .environmentObject(store)
        }
    }

    private var quickAddButtons: some View {
        HStack(spacing: 12) {
            quickAddButton("Food", type: .food)
            quickAddButton("Medicine", type: .medicine)
            quickAddButton("Litter", type: .litter)
            Button { healthRoute = HealthEditorRoute() } label: {
                Image(systemName: "heart.text.square").frame(maxWidth: .infinity).frame(minHeight: 32)
            }
            .accessibilityLabel("Health").accessibilityIdentifier("home.quickAdd.Health")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    private func quickAddButton(_ title: String, type: CareEventType) -> some View {
        Button {
            creationRoute = .event(type)
        } label: {
            Image(systemName: type.homeSystemImage)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 32)
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier("home.quickAdd.\(type.rawValue)")
    }

    @ViewBuilder
    private var dueSoonContent: some View {
        let reminders = store.upcomingReminders()

        if reminders.isEmpty {
            ContentUnavailableView("No reminders due soon", systemImage: "bell.slash")
        } else {
            ForEach(reminders) { reminder in
                ReminderSummaryRow(
                    reminder: reminder,
                    showsEventIcon: true,
                    rowAccessibilityIdentifier: "home.reminder.\(reminder.id.uuidString)",
                    onCompleteNow: { store.completeReminderNowAndRefresh(id: reminder.id) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete") { deletingReminder = reminder }.tint(.red)
                        .accessibilityIdentifier("home.reminder.delete")
                    Button("Edit") { reminderRoute = ReminderEditorRoute(reminder: reminder) }
                        .tint(.blue)
                        .accessibilityIdentifier("home.reminder.edit")
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button("Skip Instance", systemImage: "forward.end") {
                        store.deleteReminderOccurrenceAndRefresh(reminder)
                    }
                    .tint(.orange)
                    .accessibilityIdentifier("home.reminder.skip")
                }
            }
        }
    }

    @ViewBuilder
    private var recentContent: some View {
        let sections = HomeRecentService.sections(
            events: store.events, health: store.healthEntries, calendar: calendar)
        if sections.isEmpty {
            ContentUnavailableView("No events yet", systemImage: "calendar.badge.exclamationmark")
        } else {
            ForEach(sections, id: \.day) { section in
                Text(section.day.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                ForEach(section.items) { item in
                    recentRow(item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete") { deletingItem = item }.tint(.red)
                                .accessibilityIdentifier("home.event.delete")
                            Button("Edit") {
                                switch item {
                                case let .care(event): editingEvent = event
                                case let .health(entry):
                                    healthRoute = HealthEditorRoute(entry: entry, petID: entry.petID)
                                }
                            }
                            .tint(.blue)
                            .accessibilityIdentifier("home.event.edit")
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func recentRow(_ item: HomeRecentItem) -> some View {
        Group {
            switch item {
            case let .care(event):
                HomeRecentEventRow(event: event, petName: store.petName(for: event.petID))
            case let .health(entry):
                HealthSummaryRow(entry: entry, petName: store.petName(for: entry.petID))
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.recent.\(item.id)")
    }
}

enum HomeRecentItem: Identifiable {
    case care(CareEvent)
    case health(HealthEntry)
    var id: String {
        switch self { case let .care(event): "care.\(event.id)"; case let .health(entry): "health.\(entry.id)" }
    }
    var date: Date {
        switch self { case let .care(event): event.startTime; case let .health(entry): entry.happenedAt }
    }
}

enum HomeRecentService {
    static func items(events: [CareEvent], health: [HealthEntry], now: Date = .now) -> [HomeRecentItem] {
        let combined: [HomeRecentItem] = events.map { .care($0) } + health.map { .health($0) }
        let past = combined.filter { $0.date <= now }
        let sorted = past.sorted { lhs, rhs in
            if lhs.date == rhs.date { return lhs.id < rhs.id }
            return lhs.date > rhs.date
        }
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        return sorted.enumerated().compactMap { index, item in
            index < 10 || item.date >= cutoff ? item : nil
        }
    }

    static func sections(events: [CareEvent], health: [HealthEntry], now: Date = .now,
                         calendar: Calendar = .current) -> [(day: Date, items: [HomeRecentItem])] {
        let grouped = Dictionary(grouping: items(events: events, health: health, now: now)) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.map { (day: $0.key, items: $0.value) }.sorted { $0.day > $1.day }
    }
}

private struct HomeRecentEventRow: View {
    let event: CareEvent
    let petName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.type.homeSystemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    scopeLabel
                    Spacer()
                    RelativeTimeText(date: event.startTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                eventText
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var scopeLabel: some View {
        if event.petID == nil {
            Label("Household", systemImage: "house")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            Text(petName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var eventText: some View {
        switch event.data {
        case let .food(data):
            Text("\(data.name) · \(data.amount.formatted()) \(data.unit.rawValue)")
        case .litter:
            Text("Litter cleaned")
        case let .medicine(data):
            Text("\(data.name) · \(data.dosage.formatted()) \(data.unit)")
        }
    }
}

extension CareEventType {
    var homeSystemImage: String {
        switch self {
        case .food:
            return "fork.knife"
        case .medicine:
            return "pills"
        case .litter:
            return "tray"
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(PetCareStore.preview)
    }
}
