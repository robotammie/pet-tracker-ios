import Foundation

protocol PetRepository {
    func listPets() -> [Pet]
    func savePet(_ pet: Pet)
    func deletePet(id: UUID)
}

protocol CareEventRepository {
    func listEvents() -> [CareEvent]
    func saveEvent(_ event: CareEvent)
    func deleteEvent(id: UUID)
}

protocol SavedEventOptionRepository {
    func listSavedOptions(includeDeleted: Bool) -> [SavedEventOption]
    func saveSavedOption(_ option: SavedEventOption)
    func softDeleteSavedOption(id: UUID, at date: Date)
}

protocol ReminderRepository {
    func listReminders(includeMuted: Bool) -> [Reminder]
    func saveReminder(_ reminder: Reminder)
    func muteReminder(id: UUID)
    func deleteReminder(id: UUID)
}

protocol UserSettingsRepository {
    func loadSettings() -> UserSettings
    func saveSettings(_ settings: UserSettings)
}
