import Foundation

protocol PetRepository {
    func listPets() throws -> [Pet]
    func savePet(_ pet: Pet) throws
    func deletePet(id: UUID) throws
}

protocol CareEventRepository {
    func listEvents() throws -> [CareEvent]
    func saveEvent(_ event: CareEvent) throws
    func deleteEvent(id: UUID) throws
}

protocol SavedEventOptionRepository {
    func listSavedOptions(includeDeleted: Bool) throws -> [SavedEventOption]
    func saveSavedOption(_ option: SavedEventOption) throws
    func softDeleteSavedOption(id: UUID, at date: Date) throws
}

protocol ReminderRepository {
    func listReminders(includeMuted: Bool) throws -> [Reminder]
    func saveReminder(_ reminder: Reminder) throws
    func muteReminder(id: UUID) throws
    func deleteReminder(id: UUID) throws
}

protocol ScheduledEventRepository {
    func listScheduledEvents() throws -> [ScheduledEvent]
    func saveScheduledEvent(_ scheduledEvent: ScheduledEvent) throws
    func deleteScheduledEvent(id: UUID) throws
}

protocol UserSettingsRepository {
    func loadSettings() -> UserSettings
    func saveSettings(_ settings: UserSettings)
}

protocol HealthEntryRepository {
    func listHealthEntries() throws -> [HealthEntry]
    func saveHealthEntry(_ entry: HealthEntry) throws
}
