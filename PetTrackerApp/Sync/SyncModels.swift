import CryptoKit
import Foundation

enum SyncIdentity {
    static func uuid(_ value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(("PetTracker/v1/" + value).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }
    static func occurrence(_ reminder: Reminder) -> String {
        "\(reminder.id.uuidString)/\(reminder.dueAt.timeIntervalSince1970.bitPattern)"
    }
    static func history(_ reminder: Reminder) -> UUID { uuid("history/" + occurrence(reminder)) }
    static func history(reminderID: UUID, dueAt: Date) -> UUID {
        uuid("history/\(reminderID.uuidString)/\(dueAt.timeIntervalSince1970.bitPattern)")
    }
    static func isHistory(_ reminder: Reminder, of reminderID: UUID) -> Bool {
        reminder.status == .completed && reminder.id == history(reminderID: reminderID, dueAt: reminder.dueAt)
    }
    static func event(_ reminder: Reminder, petID: UUID?) -> UUID {
        uuid("event/" + occurrence(reminder) + "/" + (petID?.uuidString ?? "household"))
    }
    static func scheduledEvent(scheduleID: UUID, scheduledAt: Date) -> UUID {
        uuid("scheduled-event/\(scheduleID.uuidString)/\(scheduledAt.timeIntervalSince1970.bitPattern)")
    }
}

struct SyncVersion: Codable, Hashable, Comparable {
    var counter: UInt64
    var writer: UUID
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.counter == rhs.counter ? lhs.writer.uuidString < rhs.writer.uuidString : lhs.counter < rhs.counter
    }
}

struct SyncScope: Codable, Hashable {
    enum Database: String, Codable { case `private`, shared }
    enum Environment: String, Codable {
        case development = "Development"
        case production = "Production"
    }
    var environment = Environment.development
    var containerIdentifier: String? = nil
    var database: Database
    var zoneName: String
    var ownerName: String
    // Future invitations select a shared scope; domain/UI code never chooses a CKDatabase.
    static let personal = SyncScope(
        database: .private, zoneName: "PetTrackerHousehold", ownerName: "currentUser")
}

struct SyncCompletion: Codable, Hashable {
    struct Outcome: Codable, Hashable {
        var petID: UUID?
        var completedAt: Date
        var event: CareEvent?
        var alternatives: [CareEvent] = []
        var key: String { petID?.uuidString ?? "household" }
    }
    var original: Reminder
    var definitionVersion: SyncVersion
    var calendar: Calendar = .current
    var outcomes: [Outcome]

    func merging(_ other: Self) -> Self {
        var result: Self
        if definitionVersion != other.definitionVersion {
            result = definitionVersion < other.definitionVersion ? other : self
        } else {
            let left =
                (try? (SyncCoding.encode(original) + SyncCoding.encode(calendar)).base64EncodedString()) ?? ""
            let right =
                (try? (SyncCoding.encode(other.original) + SyncCoding.encode(other.calendar))
                    .base64EncodedString()) ?? ""
            result = left < right ? self : other
        }
        let grouped = Dictionary(grouping: outcomes + other.outcomes, by: \.key)
        result.outcomes = grouped.values.compactMap { values in
            var canonical = values.min { a, b in
                if a.completedAt != b.completedAt { return a.completedAt < b.completedAt }
                let left = (try? SyncCoding.encode(a.event).base64EncodedString()) ?? ""
                let right = (try? SyncCoding.encode(b.event).base64EncodedString()) ?? ""
                return left < right
            }
            let candidates = values.flatMap { $0.alternatives + ($0.event.map { [$0] } ?? []) }
            canonical?.alternatives = Array(Set(candidates)).sorted {
                ((try? SyncCoding.encode($0).base64EncodedString()) ?? "")
                    < ((try? SyncCoding.encode($1).base64EncodedString()) ?? "")
            }
            return canonical
        }.sorted { $0.key < $1.key }
        return result
    }
}

struct SyncReminderSkip: Codable, Hashable {
    var original: Reminder
    var nextDueAt: Date?
}

enum SyncPayload: Codable, Hashable {
    case pet(Pet)
    case event(CareEvent)
    case health(HealthEntry)
    case option(SavedEventOption)
    case reminder(Reminder)
    case schedule(ScheduledEvent)
    case skip(SyncReminderSkip)
    case completion(SyncCompletion)

    var key: String {
        switch self {
        case .pet(let value): "pet-" + value.id.uuidString
        case .event(let value): "event-" + value.id.uuidString
        case .health(let value): "health-" + value.id.uuidString
        case .option(let value): "option-" + value.id.uuidString
        case .reminder(let value): "reminder-" + value.id.uuidString
        case .schedule(let value): "schedule-" + value.id.uuidString
        case .skip(let value):
            "skip-" + SyncIdentity.uuid(SyncIdentity.occurrence(value.original)).uuidString
        case .completion(let value):
            "completion-" + SyncIdentity.uuid(SyncIdentity.occurrence(value.original)).uuidString
        }
    }
    var normalized: Self {
        func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
        func optional(_ value: String?) -> String? { value.map(clean).flatMap { $0.isEmpty ? nil : $0 } }
        func data(_ value: CareEventData) -> CareEventData {
            switch value {
            case .food(var food):
                food.name = clean(food.name)
                return .food(food)
            case .medicine(var medicine):
                medicine.name = clean(medicine.name)
                medicine.unit = clean(medicine.unit)
                return .medicine(medicine)
            case .litter: return value
            }
        }
        func rule(_ value: RecurrenceRule?) -> RecurrenceRule? {
            if case .timesPerDay(let count, let times) = value {
                return .timesPerDay(
                    count: count, times: times.map { DateComponents(hour: $0.hour, minute: $0.minute ?? 0) })
            }
            return value
        }
        switch self {
        case .completion(var value):
            if case .reminder(let original) = SyncPayload.reminder(value.original).normalized {
                value.original = original
            }
            value.outcomes.sort { $0.key < $1.key }
            return .completion(value)
        case .event(var value):
            value.data = data(value.data)
            return .event(value)
        case .reminder(var value):
            value.title = clean(value.title)
            value.eventData = value.eventData.map(data)
            value.targets = value.targets.map { target in
                var target = target
                target.eventData = target.eventData.map(data)
                return target
            }.sorted { $0.petID.uuidString < $1.petID.uuidString }
            if var schedule = value.schedule {
                schedule.recurrenceRule = rule(schedule.recurrenceRule)
                value.schedule = schedule
            }
            return .reminder(value)
        case .schedule(var value):
            value.title = clean(value.title)
            value.food.name = clean(value.food.name)
            if var schedule = value.schedule {
                schedule.recurrenceRule = rule(schedule.recurrenceRule)
                value.schedule = schedule
            }
            return .schedule(value)
        case .skip(var value):
            if case .reminder(let original) = SyncPayload.reminder(value.original).normalized {
                value.original = original
            }
            return .skip(value)
        case .option(var value):
            switch value.data {
            case .medicine(var medicine):
                medicine.name = clean(medicine.name)
                medicine.unit = clean(medicine.unit)
                medicine.purpose = optional(medicine.purpose)
                medicine.petDoseIntervals.sort { $0.petID.uuidString < $1.petID.uuidString }
                if var cadence = medicine.cadence, let recurrence = rule(cadence.rule) {
                    cadence.rule = recurrence
                    medicine.cadence = cadence
                }
                value.data = .medicine(medicine)
            case .food(var food):
                food.name = clean(food.name)
                food.officialName = optional(food.officialName)
                value.data = .food(food)
            }
            return .option(value)
        default: return self
        }
    }

}

struct SyncEnvelope: Codable, Hashable {
    var formatVersion = 1
    var key: String
    var version: SyncVersion
    var calendar: Calendar?
    var payload: SyncPayload?  // nil is a durable tombstone, never a missing fetch result.

    func validated() throws -> Self {
        guard formatVersion == 1, payload == nil || payload?.key == key,
            ["pet-", "event-", "health-", "option-", "reminder-", "schedule-", "skip-", "completion-"].contains(
                String(key.dropLast(36))),
            UUID(uuidString: String(key.suffix(36))) != nil
        else { throw SyncError.invalidRecord }
        if case .reminder = payload, calendar == nil { throw SyncError.invalidRecord }
        try payload?.validate()
        var value = self
        value.payload = payload?.normalized
        return value
    }

    func merging(_ other: Self) throws -> Self {
        let left = try validated()
        let right = try other.validated()
        guard left.key == right.key else { throw SyncError.invalidRecord }
        func preferred() throws -> Self {
            if left.version != right.version { return left.version < right.version ? right : left }
            // Restoring a device backup can clone its writer identity/counter.
            // Equal versions still need a commutative value tie-break.
            return try SyncCoding.encode(left).base64EncodedString()
                < SyncCoding.encode(right).base64EncodedString() ? right : left
        }
        if left.payload == nil || right.payload == nil {
            if left.payload == nil && right.payload == nil { return try preferred() }
            return left.payload == nil ? left : right
        }
        var winner = try preferred()
        if case .completion(let a) = left.payload, case .completion(let b) = right.payload {
            winner.payload = .completion(a.merging(b)).normalized
        }
        return winner
    }

}

enum SyncCoding {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

enum SyncError: Error {
    case invalidRecord, unsupportedState, accountChanged, unavailable, unexpectedRemoteDeletion,
        recordTooLarge
}

struct SyncSnapshot: Codable, Hashable {
    var payloads: [String: SyncPayload]
    init(
        pets: [Pet], events: [CareEvent], health: [HealthEntry], options: [SavedEventOption],
        reminders: [Reminder], schedules: [ScheduledEvent] = []
    ) {
        let values =
            pets.map(SyncPayload.pet) + events.map(SyncPayload.event) + health.map(SyncPayload.health)
            + options.map(SyncPayload.option) + reminders.map(SyncPayload.reminder)
            + schedules.map(SyncPayload.schedule)
        payloads = Dictionary(uniqueKeysWithValues: values.map { ($0.key, $0.normalized) })
    }
}

extension SyncPayload {
    func validate() throws {
        func require(_ condition: Bool) throws { if !condition { throw SyncError.invalidRecord } }
        func finite(_ date: Date?) -> Bool { date == nil || date!.timeIntervalSince1970.isFinite }
        func data(_ value: CareEventData, type: CareEventType) throws {
            switch (type, value) {
            case (.food, .food(let food)):
                try require(
                    !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && food.amount.isFinite && food.amount > 0 && food.calories >= 0
                        && (food.caloriesPerUnit == nil || food.caloriesPerUnit! >= 0))
            case (.medicine, .medicine(let medicine)):
                try require(
                    !medicine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && medicine.dosage.isFinite && medicine.dosage > 0
                        && !medicine.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && (medicine.doseInterval == nil || medicine.doseInterval!.isValid))
            case (.litter, .litter): break
            default: throw SyncError.invalidRecord
            }
        }
        func type(of value: CareEventData) -> CareEventType {
            switch value {
            case .food: .food
            case .medicine: .medicine
            case .litter: .litter
            }
        }
        func rule(_ value: RecurrenceRule?) throws {
            switch value {
            case .every(let count, _): try require(count > 0)
            case .timesPerDay(let count, let times):
                try require(
                    count > 0 && count == times.count
                        && times.allSatisfy {
                            (0..<24).contains($0.hour ?? -1) && (0..<60).contains($0.minute ?? 0)
                        })
            case nil: break
            }
        }
        switch self {
        case .pet(let value):
            try require(
                !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && (value.caloriesPerDay == nil || value.caloriesPerDay! >= 0))
        case .event(let value):
            try require(
                finite(value.createdAt) && finite(value.startTime) && finite(value.endTime)
                    && finite(value.doseTimingOverrideAt))
            try data(value.data, type: value.type)
        case .health(let value):
            try require(value.isValid && finite(value.createdAt) && finite(value.updatedAt))
        case .option(let value):
            try require(finite(value.createdAt) && finite(value.updatedAt) && finite(value.deletedAt))
            switch value.data {
            case .food(let food):
                try require(
                    value.eventType == .food
                        && !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && food.caloriesPerUnit >= 0)
            case .medicine(let medicine):
                try require(
                    value.eventType == .medicine
                        && !medicine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !medicine.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && medicine.dosage.isFinite && medicine.dosage > 0
                        && (medicine.doseInterval == nil || medicine.doseInterval!.isValid)
                        && medicine.petDoseIntervals.allSatisfy { $0.interval.isValid }
                        && Set(medicine.petDoseIntervals.map(\.petID)).count
                            == medicine.petDoseIntervals.count
                )
                try rule(medicine.cadence?.rule)
            }
        case .reminder(let value):
            try require(
                !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && finite(value.dueAt)
                    && finite(value.completedAt)
                    && finite(value.ignoredUntil) && finite(value.schedule?.endDate)
                    && Set(value.targets.map(\.petID)).count == value.targets.count)
            try rule(value.schedule?.recurrenceRule)
            try require(value.mode != .reminderToEvent || value.eventType != nil)
            if let eventData = value.eventData {
                try data(eventData, type: value.eventType ?? type(of: eventData))
            }
            for target in value.targets {
                try require(finite(target.completedAt))
                if let eventData = target.eventData {
                    try data(eventData, type: value.eventType ?? type(of: eventData))
                }
            }
        case .schedule(let value):
            try require(
                !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && finite(value.nextDueAt) && finite(value.createdAt) && finite(value.updatedAt)
                    && finite(value.schedule?.endDate)
            )
            try data(.food(value.food), type: .food)
            try rule(value.schedule?.recurrenceRule)
            if let endDate = value.schedule?.endDate, let nextDueAt = value.nextDueAt {
                try require(nextDueAt <= endDate)
            }
        case .skip(let value):
            try SyncPayload.reminder(value.original).validate()
            try require(value.original.isRecurring && finite(value.nextDueAt))
            if let nextDueAt = value.nextDueAt { try require(nextDueAt > value.original.dueAt) }
        case .completion(let value):
            try SyncPayload.reminder(value.original).validate()
            try require(
                !value.outcomes.isEmpty && Set(value.outcomes.map(\.key)).count == value.outcomes.count)
            for outcome in value.outcomes {
                try require(finite(outcome.completedAt))
                for event in outcome.alternatives + (outcome.event.map { [$0] } ?? []) {
                    try require(
                        event.id == SyncIdentity.event(value.original, petID: outcome.petID)
                            && event.petID == outcome.petID && event.type == value.original.eventType)
                    try SyncPayload.event(event).validate()
                }
            }
        }
    }
}
