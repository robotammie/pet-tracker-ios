import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Form {
            Section("Storage") {
                Text(store.syncStatus).accessibilityIdentifier("settings.sync.status")
                if let requestSync = store.requestSyncAction {
                    Button("Sync Now", action: requestSync).accessibilityIdentifier("settings.sync.now")
                }
            }
            NavigationLink("Notifications") { NotificationSettingsView() }
                .accessibilityIdentifier("settings.notifications")

            Section("Saved Options") {
                NavigationLink {
                    SavedOptionsListView(eventType: .food)
                } label: {
                    Label("Food", systemImage: "fork.knife")
                }
                .accessibilityIdentifier("settings.savedOptions.Food")

                NavigationLink {
                    SavedOptionsListView(eventType: .medicine)
                } label: {
                    Label("Medicine", systemImage: "pills")
                }
                .accessibilityIdentifier("settings.savedOptions.Medicine")
            }

#if DEBUG
            if store.allowsDevelopmentReset {
            Section("Development") {
                Button("Reset and Reseed Local Data", role: .destructive) {
                    isShowingResetConfirmation = true
                }
                .accessibilityIdentifier("settings.development.resetAndReseed")
            }
            }
#endif
        }
        .navigationTitle("Settings")
#if DEBUG
        .confirmationDialog(
            "Reset local development data?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset and Reseed", role: .destructive) {
                store.resetDevelopmentData()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears local SwiftData records, reseeds from your configured seed data, clears pending local notifications, and resets the app badge.")
        }
#endif
    }

}

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: PetCareStore
    var body: some View {
        Form {
            Section {
                Stepper(value: $store.settings.defaultDayOnlyNotificationHour, in: 0...23) {
                    let time = Calendar.current.date(bySettingHour: store.settings.defaultDayOnlyNotificationHour,
                        minute: 0, second: 0, of: .now) ?? .now
                    Text("Daily reminder time: \(time.formatted(date: .omitted, time: .shortened))")
                }
                .accessibilityIdentifier("settings.defaultDayOnlyNotificationHour")
            } footer: {
                Text("Used for reminders with a date but no specific time. iPhone Settings controls notification permissions and presentation.")
            }
            ForEach(CareEventType.allCases) { type in
                Section(type.rawValue) {
                    Toggle("Use default", isOn: Binding(
                        get: { !store.settings.hasNotificationOverride(for: type) },
                        set: { useDefault in
                            store.settings.setNotificationPreferences(useDefault ? nil : .defaults, for: type)
                        }
                    ))
                    .accessibilityIdentifier("settings.\(type.rawValue).useDefault")
                    Toggle("Banners", isOn: preference(type, \.showsBanner))
                        .accessibilityIdentifier("settings.\(type.rawValue).showsBanner")
                    Toggle("Sounds", isOn: preference(type, \.playsSound))
                        .accessibilityIdentifier("settings.\(type.rawValue).playsSound")
                    Toggle("Badges", isOn: preference(type, \.updatesBadge))
                        .accessibilityIdentifier("settings.\(type.rawValue).updatesBadge")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func preference(_ type: CareEventType, _ keyPath: WritableKeyPath<NotificationPresentationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.settings.notificationPreferences(for: type)[keyPath: keyPath] },
            set: { value in
                var preferences = store.settings.notificationPreferences(for: type)
                preferences[keyPath: keyPath] = value
                store.settings.setNotificationPreferences(preferences, for: type)
            }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(PetCareStore.preview)
    }
}
