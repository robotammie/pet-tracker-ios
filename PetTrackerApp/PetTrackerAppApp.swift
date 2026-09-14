import SwiftData
import SwiftUI

@main
struct PetTrackerAppApp: App {
    var body: some Scene {
        WindowGroup { PersistenceStartupView() }
    }
}

struct PersistenceStartupView: View {
    @State private var container: ModelContainer?
    @State private var failed = false
    @State private var injectedStartupFailure = false

    var body: some View {
        Group {
            if let container {
                PersistentRootView().modelContainer(container)
            } else if failed {
                ContentUnavailableView {
                    Label("Couldn’t open your data", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Your existing data has not been reset. Try opening it again.")
                } actions: {
                    Button("Try Again", action: openStore)
                        .accessibilityIdentifier("persistence.retry")
                }
            } else {
                ProgressView("Opening your data…")
            }
        }
        .task { if container == nil && !failed { openStore() } }
    }

    private func openStore() {
        #if DEBUG
            if UITestConfiguration.isEnabled,
                ProcessInfo.processInfo.arguments.contains("-uiTestingStartupFailure"),
                !injectedStartupFailure
            {
                injectedStartupFailure = true
                failed = true
                return
            }
        #endif
        do {
            container = try LocalPersistence.makeContainer(
                url: UITestConfiguration.isEnabled ? UITestConfiguration.storeURL : nil)
            failed = false
        } catch {
            LocalPersistence.report(error, operation: "Open store")
            failed = true
        }
    }
}

// UI automation uses its own persistent store and defaults, never personal seed data.
enum UITestConfiguration {
    static func enabled(arguments: [String], isTestHost: Bool) -> Bool {
        arguments.contains("-uiTesting") || isTestHost
    }

    static var isEnabled: Bool {
        enabled(
            arguments: ProcessInfo.processInfo.arguments,
            isTestHost: NSClassFromString("XCTestCase") != nil
                || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
    }

    static var resetsData: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains("-uiTestingReset")
    }

    private static var usesUIArguments: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
    static var defaultsSuite: String {
        usesUIArguments ? "PetTrackerApp.UITests" : "PetTrackerApp.UnitTestHost"
    }
    static var storeURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent(
            usesUIArguments ? "UITests.store" : "UnitTestHost.store")
    }
}
