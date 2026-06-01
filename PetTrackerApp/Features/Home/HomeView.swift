import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PetCareStore

    var body: some View {
        List {
            Section("Due Soon") {
                let reminders = store.upcomingReminders()

                if reminders.isEmpty {
                    ContentUnavailableView("No reminders due soon", systemImage: "bell.slash")
                } else {
                    ForEach(reminders) { reminder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.headline)
                            Text(reminder.dueAt, style: .date)
                                + Text(" at ")
                                + Text(reminder.dueAt, style: .time)
                        }
                    }
                }
            }

            Section("Recent Care") {
                ForEach(store.recentEvents()) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(store.petName(for: event.petID))
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            RelativeTimeText(date: event.startTime)
                        }

                        EventSummaryText(event: event)
                    }
                }
            }
        }
        .navigationTitle("Pet Tracker")
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(PetCareStore.preview)
    }
}
