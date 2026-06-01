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

        if petRepository.listPets().isEmpty {
            seedInitialData(
                petRepository: petRepository,
                eventRepository: eventRepository,
                savedOptionRepository: savedOptionRepository,
                reminderRepository: reminderRepository
            )
        }

        store.pets = petRepository.listPets()
        store.events = eventRepository.listEvents()
        store.savedOptions = savedOptionRepository.listSavedOptions(includeDeleted: true)
        store.reminders = reminderRepository.listReminders(includeMuted: true)
        store.settings = settingsRepository.loadSettings()
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
}

#Preview {
    AppTabView()
        .environmentObject(PetCareStore.preview)
}
