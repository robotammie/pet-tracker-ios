import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var store: PetCareStore

    var body: some View {
        List {
            Section("Active") {
                let reminders = store.reminders.filter { !$0.isCompleted }.sorted { $0.dueAt < $1.dueAt }

                if reminders.isEmpty {
                    ContentUnavailableView("No active reminders", systemImage: "bell.slash")
                } else {
                    ForEach(reminders) { reminder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.headline)
                            Text(reminder.mode.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(reminder.dueAt, style: .date)
                                + Text(" at ")
                                + Text(reminder.dueAt, style: .time)
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(PetCareStore.preview)
    }
}
