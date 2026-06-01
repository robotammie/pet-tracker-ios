import Foundation
import SwiftData

final class SwiftDataPetRepository: PetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func listPets() -> [Pet] {
        records(PetRecord.self).map(SwiftDataMapper.pet(from:))
    }

    func savePet(_ pet: Pet) {
        let record = records(PetRecord.self).first { $0.id == pet.id } ?? PetRecord(name: pet.name)
        record.id = pet.id
        SwiftDataMapper.update(record, with: pet)
        insertIfNeeded(record)
        save()
    }

    func deletePet(id: UUID) {
        records(PetRecord.self)
            .filter { $0.id == id }
            .forEach(context.delete)
        save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() {
        try? context.save()
    }
}

final class SwiftDataCareEventRepository: CareEventRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func listEvents() -> [CareEvent] {
        records(CareEventRecord.self).compactMap(SwiftDataMapper.event(from:))
    }

    func saveEvent(_ event: CareEvent) {
        let record = records(CareEventRecord.self).first { $0.id == event.id } ?? CareEventRecord(
            typeRawValue: event.type.rawValue,
            petID: event.petID,
            createdAt: event.createdAt,
            startTime: event.startTime,
            endTime: event.endTime
        )
        record.id = event.id
        SwiftDataMapper.update(record, with: event)
        insertIfNeeded(record)
        save()
    }

    func deleteEvent(id: UUID) {
        records(CareEventRecord.self)
            .filter { $0.id == id }
            .forEach(context.delete)
        save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() {
        try? context.save()
    }
}

final class SwiftDataSavedEventOptionRepository: SavedEventOptionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func listSavedOptions(includeDeleted: Bool = false) -> [SavedEventOption] {
        records(SavedEventOptionRecord.self)
            .compactMap(SwiftDataMapper.savedOption(from:))
            .filter { includeDeleted || !$0.isDeleted }
    }

    func saveSavedOption(_ option: SavedEventOption) {
        let record = records(SavedEventOptionRecord.self).first { $0.id == option.id } ?? SavedEventOptionRecord(
            eventTypeRawValue: option.eventType.rawValue,
            createdAt: option.createdAt,
            updatedAt: option.updatedAt,
            deletedAt: option.deletedAt
        )
        record.id = option.id
        SwiftDataMapper.update(record, with: option)
        insertIfNeeded(record)
        save()
    }

    func softDeleteSavedOption(id: UUID, at date: Date = .now) {
        guard let record = records(SavedEventOptionRecord.self).first(where: { $0.id == id }) else {
            return
        }

        record.deletedAt = date
        record.updatedAt = date
        save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() {
        try? context.save()
    }
}

final class SwiftDataReminderRepository: ReminderRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func listReminders(includeMuted: Bool = false) -> [Reminder] {
        records(ReminderRecord.self)
            .compactMap(SwiftDataMapper.reminder(from:))
            .filter { includeMuted || $0.status != .muted }
    }

    func saveReminder(_ reminder: Reminder) {
        let record = records(ReminderRecord.self).first { $0.id == reminder.id } ?? ReminderRecord(
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
        save()
    }

    func muteReminder(id: UUID) {
        guard let record = records(ReminderRecord.self).first(where: { $0.id == id }) else {
            return
        }

        record.statusRawValue = ReminderStatus.muted.rawValue
        save()
    }

    func deleteReminder(id: UUID) {
        records(ReminderRecord.self)
            .filter { $0.id == id }
            .forEach(context.delete)
        save()
    }

    private func records<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func insertIfNeeded<T: PersistentModel>(_ record: T) {
        if record.modelContext == nil {
            context.insert(record)
        }
    }

    private func save() {
        try? context.save()
    }
}
