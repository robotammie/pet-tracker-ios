import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var isDueExpanded = true
    @State private var isRecentExpanded = true
    @State private var creationRoute: EventCreationRoute?

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
        .sheet(item: $creationRoute) { route in
            EventCreationSheet(route: route)
                .environmentObject(store)
        }
    }

    private var quickAddButtons: some View {
        HStack(spacing: 12) {
            quickAddButton("Food", systemImage: "fork.knife", type: .food)
            quickAddButton("Medicine", systemImage: "pills", type: .medicine)
            quickAddButton("Litter", systemImage: "sparkles", type: .litter)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    }

    private func quickAddButton(_ title: String, systemImage: String, type: CareEventType) -> some View {
        Button {
            creationRoute = .event(type)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var dueSoonContent: some View {
        let reminders = store.upcomingReminders()

        if reminders.isEmpty {
            ContentUnavailableView("No reminders due soon", systemImage: "bell.slash")
        } else {
            ForEach(reminders) { reminder in
                ReminderSummaryRow(reminder: reminder)
            }
        }
    }

    @ViewBuilder
    private var recentByCategoryContent: some View {
        let events = store.mostRecentEventByType()

        if events.isEmpty {
            ContentUnavailableView("No care events yet", systemImage: "calendar.badge.exclamationmark")
        } else {
            ForEach(events) { event in
                EventSummaryRow(event: event, petName: store.petName(for: event.petID))
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(PetCareStore.preview)
    }
}
