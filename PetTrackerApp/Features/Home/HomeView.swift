import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var isDueExpanded = true
    @State private var isRecentExpanded = true
    @State private var healthRoute: HealthEditorRoute?
    @State private var creationRoute: EventCreationRoute?
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
                    recentByCategoryContent
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
                    onCompleteNow: { store.completeReminderNowAndRefresh(id: reminder.id) }
                )
            }
        }
    }

    @ViewBuilder
    private var recentByCategoryContent: some View {
        let items = recentHomeItems()
        if items.isEmpty {
            ContentUnavailableView("No events yet", systemImage: "calendar.badge.exclamationmark")
        } else {
            ForEach(items) { item in
                switch item {
                case let .care(event):
                    NavigationLink { EventListView(initialSelectedType: event.type) } label: {
                        HomeRecentEventRow(event: event, petName: store.petName(for: event.petID))
                    }
                case let .health(entry):
                    if let pet = store.pets.first(where: { $0.id == entry.petID }) {
                        NavigationLink { PetDetailView(pet: pet, initialHealth: true) } label: {
                            HealthSummaryRow(entry: entry, petName: pet.name)
                        }
                        .accessibilityIdentifier("home.recentHealth.\(entry.id)")
                    }
                }
            }
        }
    }

    private func recentHomeItems(now: Date = .now) -> [HomeRecentItem] {
        (recentHomeEvents(now: now).map(HomeRecentItem.care)
            + HealthRecentService.entries(store.healthEntries, now: now).map(HomeRecentItem.health))
            .sorted { $0.date > $1.date }
    }

    private func recentHomeEvents(now: Date = .now) -> [CareEvent] {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let groupedEvents = Dictionary(grouping: store.events.filter { event in
            event.startTime >= cutoff && event.startTime <= now
        }) { event in
            RecentEventKey(type: event.type, petID: event.petID)
        }

        return groupedEvents.values
            .compactMap { events in events.max { $0.startTime < $1.startTime } }
            .sorted { $0.startTime > $1.startTime }
    }
}

private enum HomeRecentItem: Identifiable {
    case care(CareEvent)
    case health(HealthEntry)
    var id: String {
        switch self { case let .care(event): "care.\(event.id)"; case let .health(entry): "health.\(entry.id)" }
    }
    var date: Date {
        switch self { case let .care(event): event.startTime; case let .health(entry): entry.happenedAt }
    }
}

private struct RecentEventKey: Hashable {
    var type: CareEventType
    var petID: UUID?
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
