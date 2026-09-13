import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .accessibilityIdentifier("tab.home")
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                EventListView()
            }
            .accessibilityIdentifier("tab.events")
            .tabItem {
                Label("Events", systemImage: "list.bullet")
            }

            NavigationStack {
                PetListView()
            }
            .accessibilityIdentifier("tab.pets")
            .tabItem {
                Label("Pets", systemImage: "pawprint")
            }

            NavigationStack {
                NotificationsView()
            }
            .accessibilityIdentifier("tab.reminders")
            .tabItem {
                Label("Reminders", systemImage: "bell")
            }

            NavigationStack {
                SettingsView()
            }
            .accessibilityIdentifier("tab.settings")
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    AppTabView()
        .environmentObject(PetCareStore.preview)
}
