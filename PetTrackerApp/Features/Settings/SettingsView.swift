import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PetCareStore

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle(
                    "Banners",
                    isOn: $store.settings.globalNotificationPreferences.showsBanner
                )
                Toggle(
                    "Sounds",
                    isOn: $store.settings.globalNotificationPreferences.playsSound
                )
                Toggle(
                    "Badges",
                    isOn: $store.settings.globalNotificationPreferences.updatesBadge
                )

                Stepper(value: $store.settings.defaultDayOnlyNotificationHour, in: 0...23) {
                    Text("Daily reminder time: \(formattedHour(store.settings.defaultDayOnlyNotificationHour))")
                }
            }

            Section {
                Text("iOS system notification settings may override app-level preferences.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
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

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(PetCareStore.preview)
    }
}
