import SwiftData
import SwiftUI

struct PersistentRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = PetCareStore(
        notificationScheduler: UITestConfiguration.isEnabled
            ? UITestNotificationScheduler() : LocalNotificationScheduler()
    )
    @State private var didLoad = false

    private let settingsRepository = UserDefaultsSettingsRepository(
        defaults: UITestConfiguration.isEnabled
            ? UserDefaults(suiteName: UITestConfiguration.defaultsSuite)!
            : .standard
    )

    var body: some View {
        AppTabView()
            .medicationTimingAlert(.main)
            .environmentObject(store)
            .task {
                loadIfNeeded()
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

        didLoad = true

        let petRepository = SwiftDataPetRepository(context: modelContext)
        let eventRepository = SwiftDataCareEventRepository(context: modelContext)
        let savedOptionRepository = SwiftDataSavedEventOptionRepository(context: modelContext)
        let reminderRepository = SwiftDataReminderRepository(context: modelContext)

        store.configurePersistence(
            petRepository: petRepository,
            eventRepository: eventRepository,
            savedOptionRepository: savedOptionRepository,
            reminderRepository: reminderRepository,
            healthRepository: SwiftDataHealthEntryRepository(context: modelContext)
        )

#if DEBUG
        store.configureDevelopmentReset {
            resetAndReseedDevelopmentData(
                petRepository: petRepository,
                eventRepository: eventRepository,
                savedOptionRepository: savedOptionRepository,
                reminderRepository: reminderRepository
            )
        }
#endif

#if DEBUG
        if UITestConfiguration.resetsData {
            UserDefaults(suiteName: UITestConfiguration.defaultsSuite)?
                .removePersistentDomain(forName: UITestConfiguration.defaultsSuite)
            deleteAll(HealthEntryRecord.self)
            deleteAll(ReminderTargetRecord.self)
            deleteAll(ReminderRecord.self)
            deleteAll(SavedEventOptionRecord.self)
            deleteAll(CareEventRecord.self)
            deleteAll(PetRecord.self)
        }
#endif

        if petRepository.listPets().isEmpty {
            seedInitialData(
                petRepository: petRepository,
                eventRepository: eventRepository,
                savedOptionRepository: savedOptionRepository,
                reminderRepository: reminderRepository
            )
        }

        store.refreshFromPersistence()
        store.settings = settingsRepository.loadSettings()
        if !UITestConfiguration.isEnabled {
            store.requestNotificationAuthorization()
            store.syncLocalNotifications()
        }
    }

    private func seedInitialData(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository
    ) {
        let preview: PetCareStore
        if UITestConfiguration.isEnabled {
            preview = SeedData.store!
            // Start with no history so a newly saved event is unambiguous.
            preview.events = []
            if ProcessInfo.processInfo.arguments.contains("-uiTestingDoseTiming"),
               let index = preview.savedOptions.firstIndex(where: { $0.eventType == .medicine }),
               case var .medicine(medicine) = preview.savedOptions[index].data,
               let pet = preview.pets.first {
                medicine.doseInterval = MedicationDoseInterval(minimumHours: 8, maximumHours: 12)
                preview.savedOptions[index].data = .medicine(medicine)
                let payload = MedicineEventData(name: medicine.name, dosage: medicine.dosage, unit: medicine.unit,
                    savedOptionID: preview.savedOptions[index].id, doseInterval: medicine.doseInterval)
                preview.reminders.append(Reminder(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                    title: "Timing test medicine", mode: .reminderToEvent, eventType: .medicine,
                    dueAt: .now, dueStyle: .timestamp,
                    targets: [ReminderTarget(petID: pet.id, eventData: .medicine(payload))]))
            }
        } else {
            preview = PetCareStore.preview
        }

        preview.pets.forEach(petRepository.savePet)
        preview.events.forEach(eventRepository.saveEvent)
        preview.savedOptions.forEach(savedOptionRepository.saveSavedOption)
        preview.reminders.forEach(reminderRepository.saveReminder)
    }

#if DEBUG
    private func resetAndReseedDevelopmentData(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository
    ) {
        deleteAll(HealthEntryRecord.self)
        deleteAll(ReminderTargetRecord.self)
        deleteAll(ReminderRecord.self)
        deleteAll(SavedEventOptionRecord.self)
        deleteAll(CareEventRecord.self)
        deleteAll(PetRecord.self)

        seedInitialData(
            petRepository: petRepository,
            eventRepository: eventRepository,
            savedOptionRepository: savedOptionRepository,
            reminderRepository: reminderRepository
        )

        store.refreshFromPersistence()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let records = (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
        records.forEach(modelContext.delete)
        try? modelContext.save()
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
