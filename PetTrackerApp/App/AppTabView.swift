import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                EventListView()
            }
            .tabItem {
                Label("Events", systemImage: "list.bullet")
            }

            NavigationStack {
                PetListView()
            }
            .tabItem {
                Label("Pets", systemImage: "pawprint")
            }

            NavigationStack {
                NotificationsView()
            }
            .tabItem {
                Label("Reminders", systemImage: "bell")
            }

            NavigationStack {
                SettingsView()
            }
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
