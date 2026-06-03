import Foundation

final class PetCareStore: ObservableObject {
    @Published var pets: [Pet]
    @Published var events: [CareEvent]
    @Published var savedOptions: [SavedEventOption]
    @Published var reminders: [Reminder]
    @Published var settings: UserSettings

    private var petRepository: PetRepository?
    private var eventRepository: CareEventRepository?
    private var savedOptionRepository: SavedEventOptionRepository?
    private var reminderRepository: ReminderRepository?

    init(
        pets: [Pet] = [],
        events: [CareEvent] = [],
        savedOptions: [SavedEventOption] = [],
        reminders: [Reminder] = [],
        settings: UserSettings = .defaults
    ) {
        self.pets = pets
        self.events = events
        self.savedOptions = savedOptions
        self.reminders = reminders
        self.settings = settings
    }

    func configurePersistence(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository
    ) {
        self.petRepository = petRepository
        self.eventRepository = eventRepository
        self.savedOptionRepository = savedOptionRepository
        self.reminderRepository = reminderRepository
    }

    func refreshFromPersistence() {
        if let petRepository {
            pets = petRepository.listPets()
        }

        if let eventRepository {
            events = eventRepository.listEvents()
        }

        if let savedOptionRepository {
            savedOptions = savedOptionRepository.listSavedOptions(includeDeleted: true)
        }

        if let reminderRepository {
            reminders = reminderRepository.listReminders(includeMuted: true)
        }
    }

    func petName(for petID: UUID?) -> String {
        guard let petID else {
            return "Household"
        }

        return pets.first(where: { $0.id == petID })?.name ?? "Unknown Pet"
    }

    func events(for pet: Pet) -> [CareEvent] {
        events
            .filter { event in
                switch event.type {
                case .food:
                    return event.petID == pet.id || event.petID == nil
                case .medicine:
                    return event.petID == pet.id
                case .litter:
                    return false
                }
            }
            .sorted { $0.startTime > $1.startTime }
    }

    func calories(for pet: Pet, on day: Date, calendar: Calendar = .current) -> Int {
        events.reduce(0) { total, event in
            guard event.type == .food,
                  event.petID == pet.id,
                  calendar.isDate(event.startTime, inSameDayAs: day),
                  case let .food(data) = event.data
            else {
                return total
            }

            return total + data.calories
        }
    }

    func recentEvents(limit: Int = 5) -> [CareEvent] {
        Array(events.sorted { $0.startTime > $1.startTime }.prefix(limit))
    }

    func mostRecentEventByType() -> [CareEvent] {
        CareEventType.allCases.compactMap { type in
            events
                .filter { $0.type == type }
                .sorted { $0.startTime > $1.startTime }
                .first
        }
    }

    func upcomingReminders(now: Date = .now) -> [Reminder] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

        return reminders
            .filter { $0.isActive && $0.dueAt <= tomorrow }
            .sorted { $0.dueAt < $1.dueAt }
    }

    func activeSavedOptions(for eventType: CareEventType) -> [SavedEventOption] {
        savedOptions
            .filter { $0.eventType == eventType && !$0.isDeleted }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveCareEventAndRefresh(_ event: CareEvent) {
        if let eventRepository {
            eventRepository.saveEvent(event)
            refreshFromPersistence()
        } else {
            saveEvent(event)
        }
    }

    func saveCareEventsAndRefresh(_ events: [CareEvent]) {
        if let eventRepository {
            events.forEach(eventRepository.saveEvent)
            refreshFromPersistence()
        } else {
            events.forEach(saveEvent)
        }
    }

    func saveSavedOptionAndRefresh(_ option: SavedEventOption) {
        if let savedOptionRepository {
            savedOptionRepository.saveSavedOption(option)
            refreshFromPersistence()
        } else {
            saveSavedOption(option)
        }
    }

    func softDeleteSavedOptionAndRefresh(id: UUID, at date: Date = .now) {
        if let savedOptionRepository {
            savedOptionRepository.softDeleteSavedOption(id: id, at: date)
            refreshFromPersistence()
        } else {
            softDeleteSavedOption(id: id, at: date)
        }
    }
}

extension PetCareStore: PetRepository {
    func listPets() -> [Pet] {
        pets
    }

    func savePet(_ pet: Pet) {
        upsert(pet, in: &pets)
    }

    func deletePet(id: UUID) {
        pets.removeAll { $0.id == id }
    }
}

extension PetCareStore: CareEventRepository {
    func listEvents() -> [CareEvent] {
        events
    }

    func saveEvent(_ event: CareEvent) {
        upsert(event, in: &events)
    }

    func deleteEvent(id: UUID) {
        events.removeAll { $0.id == id }
    }
}

extension PetCareStore: SavedEventOptionRepository {
    func listSavedOptions(includeDeleted: Bool = false) -> [SavedEventOption] {
        savedOptions.filter { includeDeleted || !$0.isDeleted }
    }

    func saveSavedOption(_ option: SavedEventOption) {
        upsert(option, in: &savedOptions)
    }

    func softDeleteSavedOption(id: UUID, at date: Date = .now) {
        guard let index = savedOptions.firstIndex(where: { $0.id == id }) else {
            return
        }

        savedOptions[index].deletedAt = date
        savedOptions[index].updatedAt = date
    }
}

extension PetCareStore: ReminderRepository {
    func listReminders(includeMuted: Bool = false) -> [Reminder] {
        reminders.filter { includeMuted || $0.status != .muted }
    }

    func saveReminder(_ reminder: Reminder) {
        upsert(reminder, in: &reminders)
    }

    func muteReminder(id: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else {
            return
        }

        reminders[index].status = .muted
    }

    func deleteReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
    }
}

extension PetCareStore: UserSettingsRepository {
    func loadSettings() -> UserSettings {
        settings
    }

    func saveSettings(_ settings: UserSettings) {
        self.settings = settings
    }
}

private extension PetCareStore {
    func upsert<T: Identifiable>(_ item: T, in collection: inout [T]) where T.ID == UUID {
        if let index = collection.firstIndex(where: { $0.id == item.id }) {
            collection[index] = item
        } else {
            collection.append(item)
        }
    }
}
