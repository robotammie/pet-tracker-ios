import Foundation

final class PetCareStore: ObservableObject {
    @Published var pets: [Pet]
    @Published var events: [CareEvent]
    @Published var healthEntries: [HealthEntry]
    @Published var savedOptions: [SavedEventOption]
    @Published var reminders: [Reminder]
    @Published var settings: UserSettings
    @Published var medicationTimingPrompt: MedicationTimingPrompt?

    private struct PendingMedicationWrite {
        var presentation: MedicationTimingPresentation
        var candidates: [CareEvent]
        var warnings: [MedicationTimingWarning]
        var commit: ([CareEvent]) -> Bool
        var onSaved: (() -> Void)?
    }
    private var pendingMedicationWrite: PendingMedicationWrite?

    private var petRepository: PetRepository?
    private var healthRepository: HealthEntryRepository?
    private var eventRepository: CareEventRepository?
    private var savedOptionRepository: SavedEventOptionRepository?
    private var reminderRepository: ReminderRepository?
    private let notificationScheduler: NotificationScheduling
    private var developmentResetAction: (() -> Void)?

    init(
        pets: [Pet] = [],
        events: [CareEvent] = [],
        healthEntries: [HealthEntry] = [],
        savedOptions: [SavedEventOption] = [],
        reminders: [Reminder] = [],
        settings: UserSettings = .defaults,
        notificationScheduler: NotificationScheduling = LocalNotificationScheduler()
    ) {
        self.pets = pets
        self.events = events
        self.healthEntries = healthEntries
        self.savedOptions = savedOptions
        self.reminders = reminders
        self.settings = settings
        self.notificationScheduler = notificationScheduler
    }

    func configurePersistence(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository,
        healthRepository: HealthEntryRepository? = nil
    ) {
        self.healthRepository = healthRepository
        self.petRepository = petRepository
        self.eventRepository = eventRepository
        self.savedOptionRepository = savedOptionRepository
        self.reminderRepository = reminderRepository
    }

    func refreshFromPersistence() {
        if let healthRepository { healthEntries = healthRepository.listHealthEntries() }
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

    func savePetAndRefresh(_ pet: Pet) {
        if let petRepository {
            petRepository.savePet(pet)
            refreshFromPersistence()
        } else {
            savePet(pet)
        }
    }

    func healthEntries(for petID: UUID) -> [HealthEntry] {
        healthEntries.filter { $0.petID == petID }.sorted { $0.happenedAt > $1.happenedAt }
    }

    func saveHealthEntryAndRefresh(_ entry: HealthEntry) throws {
        guard entry.isValid, pets.contains(where: { $0.id == entry.petID }) else {
            throw HealthSaveError.invalidEntry
        }
        if let healthRepository {
            try healthRepository.saveHealthEntry(entry)
            refreshFromPersistence()
        } else {
            upsert(entry, in: &healthEntries)
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
            .filter { $0.isActive && $0.displayDueAt(now: now) <= tomorrow }
            .sorted { $0.displayDueAt(now: now) < $1.displayDueAt(now: now) }
    }

    func activeSavedOptions(for eventType: CareEventType) -> [SavedEventOption] {
        savedOptions
            .filter { $0.eventType == eventType && !$0.isDeleted }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func saveCareEventAndRefresh(_ event: CareEvent, presentation: MedicationTimingPresentation = .main, onSaved: (() -> Void)? = nil) -> Bool {
        saveCareEventsAndRefresh([event], presentation: presentation, onSaved: onSaved)
    }

    @discardableResult
    func saveCareEventsAndRefresh(_ candidates: [CareEvent], presentation: MedicationTimingPresentation = .main, onSaved: (() -> Void)? = nil) -> Bool {
        medicationCheckedWrite(candidates, presentation: presentation, onSaved: onSaved) { [weak self] accepted in
            guard let self else { return false }
            self.persistEvents(accepted)
            self.refreshFromPersistence()
            return true
        }
    }

    func cancelMedicationTimingWrite() {
        pendingMedicationWrite = nil
        medicationTimingPrompt = nil
    }

    func confirmMedicationTimingWrite(at date: Date = .now) {
        guard var pending = pendingMedicationWrite else { return }
        let candidates = pending.candidates.map { MedicationTimingService.resolved($0, options: savedOptions) }
        let currentWarnings = MedicationTimingService.warnings(for: candidates, existing: events, options: savedOptions, pets: pets)
        if currentWarnings != pending.warnings {
            // A changed prescription/history requires a fresh acknowledgement.
            pending.candidates = candidates
            pending.warnings = currentWarnings
            pendingMedicationWrite = pending
            if !currentWarnings.isEmpty {
                medicationTimingPrompt = MedicationTimingPrompt(warnings: currentWarnings, presentation: pending.presentation)
                return
            }
        }
        let accepted = candidates.map { candidate in
            var event = candidate
            let messages = currentWarnings.filter { $0.eventID == event.id }.map(\.message)
            if !messages.isEmpty {
                event.doseTimingOverrideAt = date
                event.doseTimingOverrideMessage = messages.joined(separator: "\n\n")
            }
            return event
        }
        cancelMedicationTimingWrite()
        if pending.commit(accepted) { pending.onSaved?() }
    }

    private func medicationCheckedWrite(_ candidates: [CareEvent], presentation: MedicationTimingPresentation, onSaved: (() -> Void)?, commit: @escaping ([CareEvent]) -> Bool) -> Bool {
        let resolved = candidates.map { MedicationTimingService.resolved($0, options: savedOptions) }
        let warnings = MedicationTimingService.warnings(for: resolved, existing: events, options: savedOptions, pets: pets)
        guard warnings.isEmpty else {
            pendingMedicationWrite = PendingMedicationWrite(presentation: presentation, candidates: resolved, warnings: warnings, commit: commit, onSaved: onSaved)
            medicationTimingPrompt = MedicationTimingPrompt(warnings: warnings, presentation: presentation)
            return false
        }
        if commit(resolved) {
            onSaved?()
            return true
        }
        return false
    }

    private func persistEvents(_ accepted: [CareEvent]) {
        if let eventRepository {
            accepted.forEach(eventRepository.saveEvent)
        } else {
            accepted.forEach(saveEvent)
        }
    }

    func deleteCareEventAndRefresh(id: UUID) {
        if let eventRepository {
            eventRepository.deleteEvent(id: id)
            refreshFromPersistence()
        } else {
            deleteEvent(id: id)
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

    func saveReminderAndRefresh(_ reminder: Reminder) {
        if let reminderRepository {
            reminderRepository.saveReminder(reminder)
            refreshFromPersistence()
        } else {
            saveReminder(reminder)
        }

        syncLocalNotifications()
    }

    func completeReminderNowAndRefresh(id: UUID, now: Date = .now) {
        guard let reminder = reminders.first(where: { $0.id == id && $0.isActive }) else {
            return
        }
        completeReminderAndRefresh(
            reminder,
            completedPetIDs: Set(reminder.incompleteTargets.map(\.petID)),
            completionTime: now,
            createsEvent: reminder.mode == .reminderToEvent
        )
    }

    @discardableResult
    func completeReminderAndRefresh(
        _ reminder: Reminder,
        completedPetIDs: Set<UUID>,
        completionTime: Date,
        createsEvent: Bool,
        presentation: MedicationTimingPresentation = .main,
        onSaved: (() -> Void)? = nil
    ) -> Bool {
        guard let current = reminders.first(where: { $0.id == reminder.id && $0.isActive }) else { return false }
        let result = ReminderActionService.complete(
            current,
            completedPetIDs: completedPetIDs,
            completionTime: completionTime,
            createsEvent: createsEvent
        )
        return medicationCheckedWrite(result.events, presentation: presentation, onSaved: onSaved) { [weak self] accepted in
            guard let self, self.reminders.first(where: { $0.id == current.id }) == current else { return false }
            self.persistEvents(accepted)
            if let repository = self.reminderRepository {
                repository.saveReminder(result.updatedReminder)
                if let history = result.historyReminder { repository.saveReminder(history) }
            } else {
                self.saveReminder(result.updatedReminder)
                if let history = result.historyReminder { self.saveReminder(history) }
            }
            self.refreshFromPersistence()
            self.syncLocalNotifications()
            return true
        }
    }

    func ignoreReminderAndRefresh(
        _ reminder: Reminder,
        until ignoreUntil: Date,
        updateFutureNotifications: Bool
    ) {
        saveReminderAndRefresh(ReminderActionService.ignore(
            reminder,
            until: ignoreUntil,
            updateFutureNotifications: updateFutureNotifications
        ))
    }

    func softDeleteSavedOptionAndRefresh(id: UUID, at date: Date = .now) {
        if let savedOptionRepository {
            savedOptionRepository.softDeleteSavedOption(id: id, at: date)
            refreshFromPersistence()
        } else {
            softDeleteSavedOption(id: id, at: date)
        }
    }

    func muteReminderAndRefresh(id: UUID) {
        if let reminderRepository {
            reminderRepository.muteReminder(id: id)
            refreshFromPersistence()
        } else {
            muteReminder(id: id)
        }

        syncLocalNotifications()
    }

    func deleteReminderAndRefresh(id: UUID) {
        if let reminderRepository {
            reminderRepository.deleteReminder(id: id)
            refreshFromPersistence()
        } else {
            deleteReminder(id: id)
        }

        syncLocalNotifications()
    }

    func syncLocalNotifications() {
        notificationScheduler.sync(reminders: reminders, settings: settings)
    }

    func requestNotificationAuthorization() {
        notificationScheduler.requestAuthorization()
    }

#if DEBUG
    func configureDevelopmentReset(_ action: @escaping () -> Void) {
        developmentResetAction = action
    }

    func resetDevelopmentData() {
        cancelMedicationTimingWrite()
        if let developmentResetAction {
            developmentResetAction()
        } else {
            pets.removeAll()
            events.removeAll()
            healthEntries.removeAll()
            savedOptions.removeAll()
            reminders.removeAll()
            let preview = PetCareStore.preview
            pets = preview.pets
            events = preview.events
            savedOptions = preview.savedOptions
            reminders = preview.reminders
        }

        notificationScheduler.resetScheduledNotifications()
        syncLocalNotifications()
    }
#endif
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

private enum HealthSaveError: LocalizedError {
    case invalidEntry
    var errorDescription: String? { "Choose a pet, enter a title, and use a positive weight when recording a weight entry." }
}
