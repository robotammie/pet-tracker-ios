import Foundation

final class PetCareStore: ObservableObject {
    @Published var pets: [Pet]
    @Published var events: [CareEvent]
    @Published var healthEntries: [HealthEntry]
    @Published var savedOptions: [SavedEventOption]
    @Published var reminders: [Reminder]
    @Published var scheduledEvents: [ScheduledEvent]
    @Published var settings: UserSettings
    @Published var persistenceError: String?
    @Published var syncStatus = "On this device"
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
    private var scheduledEventRepository: ScheduledEventRepository?
    private let notificationScheduler: NotificationScheduling
    private var persistenceTransaction: ((() throws -> Void) throws -> Void)?
    var onReminderCompleted: ((Reminder, Set<UUID>, Date, [CareEvent]) -> Void)?
    var onReminderOccurrenceSkipped: ((Reminder, Date?) -> Void)?
    var requestSyncAction: (() -> Void)?
    var allowsDevelopmentReset = true
    var onPersistenceChanged: (() -> Void)?
    private var developmentResetAction: (() -> Void)?

    init(
        pets: [Pet] = [],
        events: [CareEvent] = [],
        healthEntries: [HealthEntry] = [],
        savedOptions: [SavedEventOption] = [],
        reminders: [Reminder] = [],
        scheduledEvents: [ScheduledEvent] = [],
        settings: UserSettings = .defaults,
        notificationScheduler: NotificationScheduling = LocalNotificationScheduler()
    ) {
        self.pets = pets
        self.events = events
        self.healthEntries = healthEntries
        self.savedOptions = savedOptions
        self.reminders = reminders
        self.scheduledEvents = scheduledEvents
        self.settings = settings
        self.notificationScheduler = notificationScheduler
    }

    func configurePersistence(
        petRepository: PetRepository,
        eventRepository: CareEventRepository,
        savedOptionRepository: SavedEventOptionRepository,
        reminderRepository: ReminderRepository,
        healthRepository: HealthEntryRepository? = nil,
        scheduledEventRepository: ScheduledEventRepository? = nil,
        performTransaction: ((() throws -> Void) throws -> Void)? = nil
    ) {
        self.persistenceTransaction = performTransaction
        self.healthRepository = healthRepository
        self.petRepository = petRepository
        self.eventRepository = eventRepository
        self.savedOptionRepository = savedOptionRepository
        self.reminderRepository = reminderRepository
        self.scheduledEventRepository = scheduledEventRepository
    }

    @discardableResult
    func refreshFromPersistence() -> Bool {
        do {
            // Publish only after all fetches succeed; failure must not look like an empty store.
            let loadedPets = try petRepository?.listPets() ?? pets
            let loadedEvents = try eventRepository?.listEvents() ?? events
            let loadedOptions = try savedOptionRepository?.listSavedOptions(includeDeleted: true) ?? savedOptions
            let loadedReminders = try reminderRepository?.listReminders(includeMuted: true) ?? reminders
            let loadedScheduledEvents = try scheduledEventRepository?.listScheduledEvents() ?? scheduledEvents
            let loadedHealth = try healthRepository?.listHealthEntries() ?? healthEntries
            pets = loadedPets
            events = loadedEvents
            savedOptions = loadedOptions
            reminders = loadedReminders
            scheduledEvents = loadedScheduledEvents
            healthEntries = loadedHealth
            persistenceError = nil
            return true
        } catch {
            LocalPersistence.report(error, operation: "Fetch")
            persistenceError = "Couldn’t load your data. Please try again."
            return false
        }
    }

    @discardableResult
    private func writePersistence(_ action: () throws -> Void) -> Bool {
        do {
            if let persistenceTransaction { try persistenceTransaction(action) }
            else { try action() }
            guard refreshFromPersistence() else { return false }
            onPersistenceChanged?()
            return true
        } catch {
            LocalPersistence.report(error, operation: "Save")
            persistenceError = "Couldn’t save your changes. Please try again."
            return false
        }
    }

    @discardableResult
    func savePetAndRefresh(_ pet: Pet) -> Bool {
        let saved = writePersistence {
            if let petRepository { try petRepository.savePet(pet) }
            else { savePet(pet) }
        }
        return saved
    }

    func healthEntries(for petID: UUID) -> [HealthEntry] {
        healthEntries.filter { $0.petID == petID }.sorted { $0.happenedAt > $1.happenedAt }
    }

    func saveHealthEntryAndRefresh(_ entry: HealthEntry) throws {
        guard entry.isValid, pets.contains(where: { $0.id == entry.petID }) else {
            throw HealthSaveError.invalidEntry
        }
        guard writePersistence({
            if let healthRepository { try healthRepository.saveHealthEntry(entry) }
            else { upsert(entry, in: &healthEntries) }
        }) else { throw HealthSaveError.invalidEntry }
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
            return self.writePersistence { try self.persistEvents(accepted) }
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

    private func persistEvents(_ accepted: [CareEvent]) throws {
        if let eventRepository {
            try accepted.forEach(eventRepository.saveEvent)
        } else {
            accepted.forEach(saveEvent)
        }
    }

    @discardableResult
    func deleteCareEventAndRefresh(id: UUID) -> Bool {
        let saved = writePersistence {
            if let eventRepository { try eventRepository.deleteEvent(id: id) }
            else { deleteEvent(id: id) }
        }
        return saved
    }

    @discardableResult
    func saveSavedOptionAndRefresh(_ option: SavedEventOption, autoqueuedReminder: Reminder? = nil) -> Bool {
        let saved = writePersistence {
            if let savedOptionRepository { try savedOptionRepository.saveSavedOption(option) }
            else { saveSavedOption(option) }
            if let reminder = autoqueuedReminder {
                if let reminderRepository { try reminderRepository.saveReminder(reminder) }
                else { saveReminder(reminder) }
            }
        }
        if saved && autoqueuedReminder != nil { syncLocalNotifications() }
        return saved
    }

    @discardableResult
    func saveReminderAndRefresh(_ reminder: Reminder) -> Bool {
        let saved = writePersistence {
            if let reminderRepository { try reminderRepository.saveReminder(reminder) }
            else { saveReminder(reminder) }
        }
        if saved { syncLocalNotifications() }
        return saved
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
        guard current == reminder else {
            persistenceError = "This reminder changed. Close and reopen it before completing it."
            return false
        }
        guard !reminders.contains(where: { $0.id == SyncIdentity.history(current) && $0.status == .completed }) else {
            persistenceError = "This occurrence was already completed. Choose a different due time or use Quick Add."
            return false
        }
        let result = ReminderActionService.complete(
            current,
            completedPetIDs: completedPetIDs,
            completionTime: completionTime,
            createsEvent: createsEvent
        )
        guard !result.events.contains(where: { candidate in events.contains { $0.id == candidate.id } }) else {
            persistenceError = "This occurrence is already logged. Choose a different due time or use Quick Add."
            return false
        }
        return medicationCheckedWrite(result.events, presentation: presentation, onSaved: onSaved) { [weak self] accepted in
            guard let self, self.reminders.first(where: { $0.id == current.id }) == current else { return false }
            let saved = self.writePersistence {
                try self.persistEvents(accepted)
                if let repository = self.reminderRepository {
                    try repository.saveReminder(result.updatedReminder)
                    if let history = result.historyReminder { try repository.saveReminder(history) }
                } else {
                    self.saveReminder(result.updatedReminder)
                    if let history = result.historyReminder { self.saveReminder(history) }
                }
                self.onReminderCompleted?(current, completedPetIDs, completionTime, accepted)
            }
            if saved { self.syncLocalNotifications() }
            return saved
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

    @discardableResult
    func softDeleteSavedOptionAndRefresh(id: UUID, at date: Date = .now) -> Bool {
        let saved = writePersistence {
            if let savedOptionRepository { try savedOptionRepository.softDeleteSavedOption(id: id, at: date) }
            else { softDeleteSavedOption(id: id, at: date) }
        }
        return saved
    }

    @discardableResult
    func muteReminderAndRefresh(id: UUID) -> Bool {
        let saved = writePersistence {
            if let reminderRepository { try reminderRepository.muteReminder(id: id) }
            else { muteReminder(id: id) }
        }
        if saved { syncLocalNotifications() }
        return saved
    }

    @discardableResult
    func deleteReminderAndRefresh(id: UUID) -> Bool {
        let saved = writePersistence {
            if let reminderRepository { try reminderRepository.deleteReminder(id: id) }
            else { deleteReminder(id: id) }
        }
        if saved { syncLocalNotifications() }
        return saved
    }

    @discardableResult
    func deleteReminderOccurrenceAndRefresh(_ reminder: Reminder, calendar: Calendar = .current) -> Bool {
        guard let current = reminders.first(where: { $0.id == reminder.id && $0.isActive }),
              current == reminder else {
            persistenceError = "This reminder changed. Close and reopen it before deleting it."
            return false
        }

        guard let schedule = current.schedule,
              let nextDue = ReminderScheduler.nextDueDate(
                after: current.dueAt,
                schedule: schedule,
                calendar: calendar
              ) else {
            return deleteReminderAndRefresh(id: current.id)
        }

        var next = current
        next.dueAt = nextDue
        next.completedAt = nil
        next.ignoredUntil = nil
        next.targets = current.targets.map {
            ReminderTarget(petID: $0.petID, eventData: $0.eventData)
        }
        let saved = writePersistence {
            if let reminderRepository { try reminderRepository.saveReminder(next) }
            else { saveReminder(next) }
            onReminderOccurrenceSkipped?(current, nextDue)
        }
        if saved { syncLocalNotifications() }
        return saved
    }

    @discardableResult
    func deleteReminderSeriesAndRefresh(_ reminder: Reminder) -> Bool {
        guard let current = reminders.first(where: { $0.id == reminder.id && $0.isActive }),
              current == reminder else {
            persistenceError = "This reminder changed. Close and reopen it before deleting it."
            return false
        }

        let ids = reminders.compactMap { candidate in
            candidate.id == current.id || SyncIdentity.isHistory(candidate, of: current.id)
                ? candidate.id
                : nil
        }
        let saved = writePersistence {
            for id in ids {
                if let reminderRepository { try reminderRepository.deleteReminder(id: id) }
                else { deleteReminder(id: id) }
            }
        }
        if saved { syncLocalNotifications() }
        return saved
    }

    @discardableResult
    func saveScheduledEventAndRefresh(_ scheduledEvent: ScheduledEvent) -> Bool {
        writePersistence {
            if let scheduledEventRepository {
                try scheduledEventRepository.saveScheduledEvent(scheduledEvent)
            } else {
                saveScheduledEvent(scheduledEvent)
            }
        }
    }

    @discardableResult
    func deleteScheduledEventAndRefresh(id: UUID) -> Bool {
        writePersistence {
            if let scheduledEventRepository {
                try scheduledEventRepository.deleteScheduledEvent(id: id)
            } else {
                deleteScheduledEvent(id: id)
            }
        }
    }

    @discardableResult
    func materializeScheduledEvents(
        through now: Date = .now,
        limitPerSchedule: Int = 100,
        calendar: Calendar? = nil
    ) -> Bool {
        let results = scheduledEvents
            .filter { $0.nextDueAt.map { $0 <= now } ?? false }
            .map {
                ScheduledEventService.materialize(
                    $0,
                    through: now,
                    limit: limitPerSchedule,
                    calendar: calendar
                )
            }
        guard !results.isEmpty else { return true }

        return writePersistence {
            for result in results {
                try persistEvents(result.events)
                if let scheduledEventRepository {
                    try scheduledEventRepository.saveScheduledEvent(result.updatedSchedule)
                } else {
                    saveScheduledEvent(result.updatedSchedule)
                }
            }
        }
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
        guard allowsDevelopmentReset else { return }
        cancelMedicationTimingWrite()
        if let developmentResetAction {
            developmentResetAction()
        } else {
            pets.removeAll()
            events.removeAll()
            healthEntries.removeAll()
            savedOptions.removeAll()
            reminders.removeAll()
            scheduledEvents.removeAll()
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

extension PetCareStore: ScheduledEventRepository {
    func listScheduledEvents() -> [ScheduledEvent] { scheduledEvents }

    func saveScheduledEvent(_ scheduledEvent: ScheduledEvent) {
        upsert(scheduledEvent, in: &scheduledEvents)
    }

    func deleteScheduledEvent(id: UUID) {
        scheduledEvents.removeAll { $0.id == id }
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
