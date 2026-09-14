import SwiftData
import SwiftUI

struct PersistentRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PetCareStore(
        notificationScheduler: UITestConfiguration.isEnabled
            ? UITestNotificationScheduler() : LocalNotificationScheduler()
    )
    @State private var didLoad = false
    @State private var syncCoordinator: SyncCoordinator?

    private let settingsRepository = UserDefaultsSettingsRepository(
        defaults: UITestConfiguration.isEnabled
            ? UserDefaults(suiteName: UITestConfiguration.defaultsSuite)!
            : .standard
    )

    private var defaults: UserDefaults {
        UITestConfiguration.isEnabled
            ? UserDefaults(suiteName: UITestConfiguration.defaultsSuite)! : .standard
    }

    var body: some View {
        AppTabView()
            .medicationTimingAlert(.main)
            .persistenceErrorBanner(onRetry: {
                if didLoad {
                    if store.refreshFromPersistence() { store.syncLocalNotifications() }
                } else {
                    loadIfNeeded()
                }
            })
            .environmentObject(store)
            .task(id: scenePhase) {
                loadIfNeeded()
                guard scenePhase == .active, didLoad else { return }
                if store.refreshFromPersistence() { store.syncLocalNotifications() }
                configureSyncIfAvailable()
                guard let syncCoordinator else { return }
                while !Task.isCancelled {
                    await syncCoordinator.syncNow()
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                }
            }
            .onChange(of: store.settings) { _, settings in
                settingsRepository.saveSettings(settings)
                store.syncLocalNotifications()
            }
    }

    @MainActor
    private func loadIfNeeded() {
        guard !didLoad else {
            return
        }

        modelContext.autosaveEnabled = false

        do {
            let petRepository = SwiftDataPetRepository(context: modelContext, savesImmediately: false)
            let eventRepository = SwiftDataCareEventRepository(context: modelContext, savesImmediately: false)
            let savedOptionRepository = SwiftDataSavedEventOptionRepository(
                context: modelContext, savesImmediately: false)
            let reminderRepository = SwiftDataReminderRepository(
                context: modelContext, savesImmediately: false)

            store.configurePersistence(
                petRepository: petRepository,
                eventRepository: eventRepository,
                savedOptionRepository: savedOptionRepository,
                reminderRepository: reminderRepository,
                healthRepository: SwiftDataHealthEntryRepository(
                    context: modelContext, savesImmediately: false),
                performTransaction: { action in
                    try LocalPersistence.transaction(context: modelContext, action)
                }
            )

            #if DEBUG
                store.allowsDevelopmentReset = SyncBuildConfiguration.containerIdentifier == nil
                if store.allowsDevelopmentReset {
                    store.configureDevelopmentReset {
                        resetAndReseedDevelopmentData(
                            petRepository: petRepository,
                            eventRepository: eventRepository,
                            savedOptionRepository: savedOptionRepository,
                            reminderRepository: reminderRepository
                        )
                    }
                }
            #endif

            #if DEBUG
                if UITestConfiguration.resetsData {
                    UserDefaults(suiteName: UITestConfiguration.defaultsSuite)?
                        .removePersistentDomain(forName: UITestConfiguration.defaultsSuite)
                    try LocalPersistence.transaction(context: modelContext) {
                        try deleteAll(HealthEntryRecord.self)
                        try deleteAll(ReminderTargetRecord.self)
                        try deleteAll(ReminderRecord.self)
                        try deleteAll(SavedEventOptionRecord.self)
                        try deleteAll(CareEventRecord.self)
                        try deleteAll(PetRecord.self)
                    }
                }
            #endif

            let hasData = try LocalPersistence.hasRecords(context: modelContext)
            if InitialDataPolicy.shouldSeed(
                hasLocalData: hasData,
                initialized: defaults.bool(forKey: "PetTrackerApp.didInitializeLocalStore"),
                syncConfigured: SyncBuildConfiguration.containerIdentifier != nil)
            {
                try LocalPersistence.transaction(context: modelContext) {
                    try seedInitialData(
                        petRepository: petRepository,
                        eventRepository: eventRepository,
                        savedOptionRepository: savedOptionRepository,
                        reminderRepository: reminderRepository
                    )
                }

            }
            guard store.refreshFromPersistence() else { return }
            defaults.set(true, forKey: "PetTrackerApp.didInitializeLocalStore")
            didLoad = true
            store.settings = settingsRepository.loadSettings()
            if !UITestConfiguration.isEnabled {
                store.requestNotificationAuthorization()
                store.syncLocalNotifications()
            }
        } catch {
            LocalPersistence.report(error, operation: "Initial load")
            modelContext.rollback()
            store.persistenceError = "Couldn’t load your data. Please try again."
        }
    }

    @MainActor
    private func configureSyncIfAvailable() {
        guard syncCoordinator == nil, let containerID = SyncBuildConfiguration.containerIdentifier else {
            return
        }
        do {
            var scope = SyncScope.personal
            scope.containerIdentifier = containerID
            guard let environment = SyncBuildConfiguration.environment else { return }
            scope.environment = environment
            let journal = try SyncJournal(
                url: URL.applicationSupportDirectory.appendingPathComponent(
                    "SyncState-v1-" + SyncIdentity.uuid(containerID + "/" + environment.rawValue).uuidString
                        + ".json"),
                initial: SyncJournal.snapshot(context: modelContext), scope: scope)
            let coordinator = SyncCoordinator(
                journal: journal,
                transport: CloudKitTransport(containerIdentifier: containerID, environment: environment),
                context: modelContext, store: store)
            store.configurePersistence(
                petRepository: SwiftDataPetRepository(context: modelContext, savesImmediately: false),
                eventRepository: SwiftDataCareEventRepository(context: modelContext, savesImmediately: false),
                savedOptionRepository: SwiftDataSavedEventOptionRepository(
                    context: modelContext, savesImmediately: false),
                reminderRepository: SwiftDataReminderRepository(
                    context: modelContext, savesImmediately: false),
                healthRepository: SwiftDataHealthEntryRepository(
                    context: modelContext, savesImmediately: false),
                performTransaction: { action in try journal.transaction(context: modelContext, action: action)
                })
            store.onReminderCompleted = { original, pets, time, events in
                journal.stageCompletion(original, pets: pets, at: time, events: events)
            }
            store.onPersistenceChanged = { [weak coordinator] in coordinator?.requestSync() }
            store.requestSyncAction = { [weak coordinator] in coordinator?.requestSync() }
            syncCoordinator = coordinator
        } catch {
            store.syncStatus = "Couldn’t prepare iCloud sync. Your local data is available."
        }
    }

    private func seedInitialData(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository
    ) throws {
        let preview: PetCareStore
        if UITestConfiguration.isEnabled {
            preview = SeedData.store!
            // Start with no history so a newly saved event is unambiguous.
            preview.events = []
            if ProcessInfo.processInfo.arguments.contains("-uiTestingDoseTiming"),
                let index = preview.savedOptions.firstIndex(where: { $0.eventType == .medicine }),
                case .medicine(var medicine) = preview.savedOptions[index].data,
                let pet = preview.pets.first
            {
                medicine.doseInterval = MedicationDoseInterval(minimumHours: 8, maximumHours: 12)
                preview.savedOptions[index].data = .medicine(medicine)
                let payload = MedicineEventData(
                    name: medicine.name, dosage: medicine.dosage, unit: medicine.unit,
                    savedOptionID: preview.savedOptions[index].id, doseInterval: medicine.doseInterval)
                preview.reminders.append(
                    Reminder(
                        id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                        title: "Timing test medicine", mode: .reminderToEvent, eventType: .medicine,
                        dueAt: .now, dueStyle: .timestamp,
                        targets: [ReminderTarget(petID: pet.id, eventData: .medicine(payload))]))
            }
        } else {
            preview = PetCareStore.preview
        }

        try preview.pets.forEach(petRepository.savePet)
        try preview.events.forEach(eventRepository.saveEvent)
        try preview.savedOptions.forEach(savedOptionRepository.saveSavedOption)
        try preview.reminders.forEach(reminderRepository.saveReminder)
    }

    #if DEBUG
        private func resetAndReseedDevelopmentData(
            petRepository: PetRepository,
            eventRepository: CareEventRepository,
            savedOptionRepository: SavedEventOptionRepository,
            reminderRepository: ReminderRepository
        ) {
            do {
                try LocalPersistence.transaction(context: modelContext) {
                    try deleteAll(HealthEntryRecord.self)
                    try deleteAll(ReminderTargetRecord.self)
                    try deleteAll(ReminderRecord.self)
                    try deleteAll(SavedEventOptionRecord.self)
                    try deleteAll(CareEventRecord.self)
                    try deleteAll(PetRecord.self)
                    try seedInitialData(
                        petRepository: petRepository, eventRepository: eventRepository,
                        savedOptionRepository: savedOptionRepository, reminderRepository: reminderRepository)
                }
                store.refreshFromPersistence()
            } catch {
                store.persistenceError = "Couldn’t reset your data. Please try again."
            }
        }

        private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
            let records = try modelContext.fetch(FetchDescriptor<T>())
            records.forEach(modelContext.delete)
        }
    #endif
}

#Preview {
    AppTabView()
        .environmentObject(PetCareStore.preview)
}

private struct UITestNotificationScheduler: NotificationScheduling {
    func requestAuthorization() {}
    func sync(reminders: [Reminder], settings: UserSettings) {}
    func resetScheduledNotifications() {}
}

private struct PersistenceErrorBanner: ViewModifier {
    @EnvironmentObject var store: PetCareStore
    var onRetry: (() -> Void)?
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top) {
            if let error = store.persistenceError {
                HStack {
                    Text(error).font(.callout)
                    Spacer()
                    Button("Try Again") {
                        if let onRetry {
                            onRetry()
                        } else if store.refreshFromPersistence() {
                            store.syncLocalNotifications()
                        }
                    }.frame(minHeight: 44)
                }
                .padding(.horizontal).background(.regularMaterial)
                .accessibilityIdentifier("persistence.error")
            }
        }
    }
}

extension View {
    func persistenceErrorBanner(onRetry: (() -> Void)? = nil) -> some View {
        modifier(PersistenceErrorBanner(onRetry: onRetry))
    }
}
