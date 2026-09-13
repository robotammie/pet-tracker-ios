import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var expandedEventTypes: Set<CareEventType> = []
    @State private var isShowingResetConfirmation = false

    var body: some View {
        Form {
            Section("Notifications") {
                notificationPreferenceControls(
                    preferences: $store.settings.globalNotificationPreferences,
                    accessibilityPrefix: "settings.global"
                )

                Stepper(value: $store.settings.defaultDayOnlyNotificationHour, in: 0...23) {
                    Text("Daily reminder time: \(formattedHour(store.settings.defaultDayOnlyNotificationHour))")
                }
                .accessibilityIdentifier("settings.defaultDayOnlyNotificationHour")
            }

            Section("Notification Overrides") {
                ForEach(CareEventType.allCases) { eventType in
                    DisclosureGroup(
                        isExpanded: bindingForExpandedEventType(eventType)
                    ) {
                        Toggle("Customize", isOn: bindingForOverrideEnabled(eventType))
                            .accessibilityIdentifier("settings.\(eventType.rawValue).customizeNotifications")

                        if store.settings.hasNotificationOverride(for: eventType) {
                            notificationPreferenceControls(
                                preferences: bindingForEventTypePreferences(eventType),
                                accessibilityPrefix: "settings.\(eventType.rawValue)"
                            )
                        }
                    } label: {
                        Label(eventType.rawValue, systemImage: eventType.systemImage)
                    }
                }

                Text("iOS system notification settings may override app-level preferences.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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
            Section("Development") {
                Button("Reset and Reseed Local Data", role: .destructive) {
                    isShowingResetConfirmation = true
                }
                .accessibilityIdentifier("settings.development.resetAndReseed")
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

    private func notificationPreferenceControls(
        preferences: Binding<NotificationPresentationPreferences>,
        accessibilityPrefix: String
    ) -> some View {
        Group {
            Toggle("Banners", isOn: preferences.showsBanner)
                .accessibilityIdentifier("\(accessibilityPrefix).showsBanner")
            Toggle("Sounds", isOn: preferences.playsSound)
                .accessibilityIdentifier("\(accessibilityPrefix).playsSound")
            Toggle("Badges", isOn: preferences.updatesBadge)
                .accessibilityIdentifier("\(accessibilityPrefix).updatesBadge")
        }
    }

    private func bindingForExpandedEventType(_ eventType: CareEventType) -> Binding<Bool> {
        Binding(
            get: { expandedEventTypes.contains(eventType) },
            set: { isExpanded in
                if isExpanded {
                    expandedEventTypes.insert(eventType)
                } else {
                    expandedEventTypes.remove(eventType)
                }
            }
        )
    }

    private func bindingForOverrideEnabled(_ eventType: CareEventType) -> Binding<Bool> {
        Binding(
            get: { store.settings.hasNotificationOverride(for: eventType) },
            set: { isEnabled in
                if isEnabled {
                    store.settings.setNotificationPreferences(
                        store.settings.globalNotificationPreferences,
                        for: eventType
                    )
                } else {
                    store.settings.setNotificationPreferences(nil, for: eventType)
                }
            }
        )
    }

    private func bindingForEventTypePreferences(_ eventType: CareEventType) -> Binding<NotificationPresentationPreferences> {
        Binding(
            get: {
                store.settings.notificationPreferences(for: eventType)
            },
            set: { preferences in
                store.settings.setNotificationPreferences(preferences, for: eventType)
            }
        )
    }

    private func formattedHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour

        guard let date = Calendar.current.date(from: components) else {
            return "\(hour):00"
        }

        return date.formatted(date: .omitted, time: .shortened)
    }
}

private extension CareEventType {
    var systemImage: String {
        switch self {
        case .food:
            return "fork.knife"
        case .litter:
            return "tray"
        case .medicine:
            return "pills"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(PetCareStore.preview)
    }
}
