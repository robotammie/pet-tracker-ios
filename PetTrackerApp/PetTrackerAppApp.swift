import SwiftUI

@main
struct PetTrackerAppApp: App {
    @StateObject private var store = PetCareStore.preview

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environmentObject(store)
        }
    }
}
