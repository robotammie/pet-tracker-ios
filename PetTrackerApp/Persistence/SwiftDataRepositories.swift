import Foundation
import SwiftData
import OSLog

final class SwiftDataPetRepository: PetRepository {
    private let context: ModelContext
    private let savesImmediately: Bool

    init(context: ModelContext, savesImmediately: Bool = true) {
        self.savesImmediately = savesImmediately
        self.context = context
    }

    func listPets() throws -> [Pet] {
        try records(PetRecord.self).map(SwiftDataMapper.pet(from:))
    }

    func savePet(_ pet: Pet) throws {
        let record = try records(PetRecord.self).first { $0.id == pet.id } ?? PetRecord(name: pet.name)
        record.id = pet.id
        SwiftDataMapper.update(record, with: pet)
        insertIfNeeded(record)
        try save()
    }

    func deletePet(id: UUID) throws {
        try records(PetRecord.self)
            .filter { $0.id == id }
            .forEach(context.delete)
        try save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() throws {
        guard savesImmediately else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

final class SwiftDataCareEventRepository: CareEventRepository {
    private let context: ModelContext
    private let savesImmediately: Bool

    init(context: ModelContext, savesImmediately: Bool = true) {
        self.savesImmediately = savesImmediately
        self.context = context
    }

    func listEvents() throws -> [CareEvent] {
        try records(CareEventRecord.self).map { record in
            guard let value = SwiftDataMapper.event(from: record) else { throw SyncError.invalidRecord }
            try LocalPersistence.validateDose(minimum: record.medicineMinimumDoseHours, maximum: record.medicineMaximumDoseHours)
            try SyncPayload.event(value).validate()
            return value
        }
    }

    func saveEvent(_ event: CareEvent) throws {
        let record = try records(CareEventRecord.self).first { $0.id == event.id } ?? CareEventRecord(
            typeRawValue: event.type.rawValue,
            petID: event.petID,
            createdAt: event.createdAt,
            startTime: event.startTime,
            endTime: event.endTime
        )
        record.id = event.id
        SwiftDataMapper.update(record, with: event)
        insertIfNeeded(record)
        try save()
    }

    func deleteEvent(id: UUID) throws {
        try records(CareEventRecord.self)
            .filter { $0.id == id }
            .forEach(context.delete)
        try save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() throws {
        guard savesImmediately else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

final class SwiftDataSavedEventOptionRepository: SavedEventOptionRepository {
    private let context: ModelContext
    private let savesImmediately: Bool

    init(context: ModelContext, savesImmediately: Bool = true) {
        self.savesImmediately = savesImmediately
        self.context = context
    }

    func listSavedOptions(includeDeleted: Bool = false) throws -> [SavedEventOption] {
        try records(SavedEventOptionRecord.self)
            .map { record in
                guard let value = SwiftDataMapper.savedOption(from: record) else { throw SyncError.invalidRecord }
                if let json = record.medicinePetDoseIntervalsJSON {
                    _ = try JSONDecoder().decode([PetMedicationDoseInterval].self, from: Data(json.utf8))
                }
                if record.medicineRecurrenceKind != nil {
                    guard case .medicine(let medicine) = value.data, medicine.cadence != nil else { throw SyncError.invalidRecord }
                }
                try LocalPersistence.validateDose(minimum: record.medicineMinimumDoseHours, maximum: record.medicineMaximumDoseHours)
                try SyncPayload.option(value).validate()
                return value
            }
            .filter { includeDeleted || !$0.isDeleted }
    }

    func saveSavedOption(_ option: SavedEventOption) throws {
        let record = try records(SavedEventOptionRecord.self).first { $0.id == option.id } ?? SavedEventOptionRecord(
            eventTypeRawValue: option.eventType.rawValue,
            createdAt: option.createdAt,
            updatedAt: option.updatedAt,
            deletedAt: option.deletedAt
        )
        record.id = option.id
        SwiftDataMapper.update(record, with: option)
        insertIfNeeded(record)
        try save()
    }

    func softDeleteSavedOption(id: UUID, at date: Date = .now) throws {
        guard let record = try records(SavedEventOptionRecord.self).first(where: { $0.id == id }) else {
            return
        }

        record.deletedAt = date
        record.updatedAt = date
        try save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() throws {
        guard savesImmediately else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

final class SwiftDataReminderRepository: ReminderRepository {
    private let context: ModelContext
    private let savesImmediately: Bool

    init(context: ModelContext, savesImmediately: Bool = true) {
        self.savesImmediately = savesImmediately
        self.context = context
    }

    func listReminders(includeMuted: Bool = false) throws -> [Reminder] {
        let targetRecordsByReminderID = Dictionary(
            grouping: try records(ReminderTargetRecord.self),
            by: \.reminderID
        )

        return try records(ReminderRecord.self)
            .map { record in
                let targets = targetRecordsByReminderID[record.id] ?? []
                guard let value = SwiftDataMapper.reminder(from: record, targetRecords: targets),
                      record.eventTypeRawValue == nil || value.eventType != nil,
                      record.recurrenceKind == nil || value.schedule?.recurrenceRule != nil else { throw SyncError.invalidRecord }
                try LocalPersistence.validateDose(minimum: record.medicineMinimumDoseHours, maximum: record.medicineMaximumDoseHours)
                for target in targets {
                    try LocalPersistence.validateDose(minimum: target.medicineMinimumDoseHours, maximum: target.medicineMaximumDoseHours)
                    if target.foodName != nil || target.medicineName != nil {
                        guard value.targets.first(where: { $0.petID == target.petID })?.eventData != nil else { throw SyncError.invalidRecord }
                    }
                }
                try SyncPayload.reminder(value).validate()
                return value
            }
            .filter { includeMuted || $0.status != .muted }
    }

    func saveReminder(_ reminder: Reminder) throws {
        let record = try records(ReminderRecord.self).first { $0.id == reminder.id } ?? ReminderRecord(
            title: reminder.title,
            modeRawValue: reminder.mode.rawValue,
            eventTypeRawValue: reminder.eventType?.rawValue,
            dueAt: reminder.dueAt,
            dueStyleRawValue: reminder.dueStyle.rawValue,
            statusRawValue: reminder.status.rawValue
        )
        record.id = reminder.id
        SwiftDataMapper.update(record, with: reminder)
        insertIfNeeded(record)
        try replaceTargets(for: reminder)
        try save()
    }

    func muteReminder(id: UUID) throws {
        guard let record = try records(ReminderRecord.self).first(where: { $0.id == id }) else {
            return
        }

        record.statusRawValue = ReminderStatus.muted.rawValue
        try save()
    }

    func deleteReminder(id: UUID) throws {
        try records(ReminderRecord.self)
            .filter { $0.id == id }
            .forEach(context.delete)
        try records(ReminderTargetRecord.self)
            .filter { $0.reminderID == id }
            .forEach(context.delete)
        try save()
    }

    private func replaceTargets(for reminder: Reminder) throws {
        try records(ReminderTargetRecord.self)
            .filter { $0.reminderID == reminder.id }
            .forEach(context.delete)

        reminder.targets
            .map { SwiftDataMapper.targetRecord(from: $0, reminderID: reminder.id) }
            .forEach(context.insert)
    }

    private func records<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() throws {
        guard savesImmediately else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

final class SwiftDataScheduledEventRepository: ScheduledEventRepository {
    private let context: ModelContext
    private let savesImmediately: Bool

    init(context: ModelContext, savesImmediately: Bool = true) {
        self.context = context
        self.savesImmediately = savesImmediately
    }

    func listScheduledEvents() throws -> [ScheduledEvent] {
        try context.fetch(FetchDescriptor<ScheduledEventRecord>()).map { record in
            guard let value = SwiftDataMapper.scheduledEvent(from: record) else {
                throw SyncError.invalidRecord
            }
            try SyncPayload.schedule(value).validate()
            return value
        }
    }

    func saveScheduledEvent(_ scheduledEvent: ScheduledEvent) throws {
        let records = try context.fetch(FetchDescriptor<ScheduledEventRecord>())
        let record = records.first { $0.id == scheduledEvent.id } ?? ScheduledEventRecord(
            title: scheduledEvent.title,
            petID: scheduledEvent.petID,
            createdAt: scheduledEvent.createdAt,
            updatedAt: scheduledEvent.updatedAt,
            nextDueAt: scheduledEvent.nextDueAt,
            calendarJSON: (try? String(
                data: JSONEncoder().encode(scheduledEvent.calendar), encoding: .utf8
            )) ?? "{}",
            foodName: scheduledEvent.food.name,
            foodTypeRawValue: scheduledEvent.food.foodType.rawValue,
            foodAmount: scheduledEvent.food.amount,
            foodUnitRawValue: scheduledEvent.food.unit.rawValue,
            foodCalories: scheduledEvent.food.calories
        )
        record.id = scheduledEvent.id
        SwiftDataMapper.update(record, with: scheduledEvent)
        if record.modelContext == nil { context.insert(record) }
        try save()
    }

    func deleteScheduledEvent(id: UUID) throws {
        try context.fetch(FetchDescriptor<ScheduledEventRecord>())
            .filter { $0.id == id }
            .forEach(context.delete)
        try save()
    }

    private func save() throws {
        guard savesImmediately else { return }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

// SwiftData remains the local database; explicit sync owns CloudKit record identity.
// Additive models use SwiftData's lightweight upgrade path and are covered by the populated-store test.
enum LocalPersistence {
    static var schema: Schema {
        Schema([PetRecord.self, HealthEntryRecord.self, CareEventRecord.self,
                SavedEventOptionRecord.self, ReminderRecord.self, ReminderTargetRecord.self,
                ScheduledEventRecord.self])
    }

    static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = schema
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func hasRecords(context: ModelContext) throws -> Bool {
        try context.fetchCount(FetchDescriptor<PetRecord>()) > 0
            || context.fetchCount(FetchDescriptor<CareEventRecord>()) > 0
            || context.fetchCount(FetchDescriptor<HealthEntryRecord>()) > 0
            || context.fetchCount(FetchDescriptor<SavedEventOptionRecord>()) > 0
            || context.fetchCount(FetchDescriptor<ReminderRecord>()) > 0
            || context.fetchCount(FetchDescriptor<ReminderTargetRecord>()) > 0
            || context.fetchCount(FetchDescriptor<ScheduledEventRecord>()) > 0
    }

    static func validateDose(minimum: Double?, maximum: Double?) throws {
        if minimum == nil && maximum == nil { return }
        guard let minimum, let maximum,
              MedicationDoseInterval(minimumHours: minimum, maximumHours: maximum).isValid else {
            throw SyncError.invalidRecord
        }
    }

    static func report(_ error: Error, operation: String) {
        let error = error as NSError
        // Log diagnostic codes without titles, notes, or private seed/store contents.
        Logger(subsystem: "com.tammie.PetTrackerApp", category: "Persistence")
            .error("\(operation, privacy: .public) failed: \(error.domain, privacy: .public) code \(error.code)")
    }

    static func transaction(context: ModelContext, _ action: () throws -> Void) throws {
        do {
            try action()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum InitialDataPolicy {
    static func shouldSeed(hasLocalData: Bool, initialized: Bool, syncConfigured: Bool) -> Bool {
        !hasLocalData && !initialized && !syncConfigured
    }
}
