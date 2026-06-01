import SwiftUI
import SwiftData

@main
struct PetTrackerAppApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            PetRecord.self,
            CareEventRecord.self,
            SavedEventOptionRecord.self,
            ReminderRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            PersistentRootView()
        }
        .modelContainer(modelContainer)
    }
}
