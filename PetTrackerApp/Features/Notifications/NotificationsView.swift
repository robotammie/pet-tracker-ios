import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var store: PetCareStore

    var body: some View {
        List {
            Section("Active") {
                let reminders = store.reminders.filter(\.isActive).sorted { $0.dueAt < $1.dueAt }

                if reminders.isEmpty {
                    ContentUnavailableView("No active reminders", systemImage: "bell.slash")
                } else {
                    ForEach(reminders) { reminder in
                        ReminderSummaryRow(reminder: reminder)
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
