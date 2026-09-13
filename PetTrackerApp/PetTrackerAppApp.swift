import SwiftUI
import SwiftData

@main
struct PetTrackerAppApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            PetRecord.self,
            HealthEntryRecord.self,
            CareEventRecord.self,
            SavedEventOptionRecord.self,
            ReminderRecord.self,
            ReminderTargetRecord.self
        ])
        let configuration: ModelConfiguration
#if DEBUG
        if UITestConfiguration.isEnabled {
            configuration = ModelConfiguration(
                schema: schema,
                url: UITestConfiguration.storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
#else
        configuration = ModelConfiguration(schema: schema)
#endif

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

// UI automation uses its own persistent store and defaults, never personal seed data.
enum UITestConfiguration {
    static var isEnabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
#else
        false
#endif
    }

    static var resetsData: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains("-uiTestingReset")
    }

    static let defaultsSuite = "PetTrackerApp.UITests"
    static var storeURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("UITests.store")
    }
}
