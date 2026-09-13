import SwiftData
import SwiftUI

struct PersistentRootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = PetCareStore()
    @State private var didLoad = false

    private let settingsRepository = UserDefaultsSettingsRepository()

    var body: some View {
        AppTabView()
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
            reminderRepository: reminderRepository
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
        store.requestNotificationAuthorization()
        store.syncLocalNotifications()
    }

    private func seedInitialData(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository
    ) {
        let preview = PetCareStore.preview

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
