import Foundation
import SwiftData

struct SyncState: Codable {
    var formatVersion = 1
    var writer = UUID()
    var clock: UInt64 = 0
    var scope = SyncScope.personal
    var cloudInitialized = false
    var accountID: String?
    var records: [String: SyncEnvelope] = [:]
    var baseline: SyncSnapshot
    var pending: Set<String> = []

    mutating func set(_ payload: SyncPayload?, key: String) throws {
        guard clock < UInt64.max else { throw SyncError.unsupportedState }
        clock += 1
        let calendar: Calendar?
        if case .reminder = payload { calendar = records[key]?.calendar ?? .current } else { calendar = nil }
        let envelope = SyncEnvelope(
            key: key, version: SyncVersion(counter: clock, writer: writer),
            calendar: calendar, payload: payload?.normalized)
        // A deleted ID cannot accidentally be restored by an offline edit.
        records[key] = try records[key]?.merging(envelope) ?? envelope
        pending.insert(key)
    }

    mutating func capture(_ snapshot: SyncSnapshot, ignoring: Set<String> = []) throws {
        for key in Set(baseline.payloads.keys).union(snapshot.payloads.keys).sorted() {
            guard !ignoring.contains(key), baseline.payloads[key] != snapshot.payloads[key] else { continue }
            try set(snapshot.payloads[key], key: key)
        }
        baseline = snapshot
    }

    mutating func receive(_ incoming: [SyncEnvelope]) throws {
        for incomingRecord in incoming {
            let record = try incomingRecord.validated()
            clock = max(clock, record.version.counter)
            let merged = try records[record.key]?.merging(record) ?? record
            records[record.key] = merged
            if merged == record { pending.remove(record.key) } else { pending.insert(record.key) }
        }
    }

    func projectedSnapshot() -> SyncSnapshot {
        var payloads = records.compactMapValues(\.payload)
        let completions = payloads.values.compactMap { value -> SyncCompletion? in
            if case .completion(let completion) = value { return completion }
            return nil
        }.sorted { a, b in
            if a.original.dueAt != b.original.dueAt { return a.original.dueAt < b.original.dueAt }
            return SyncIdentity.occurrence(a.original) < SyncIdentity.occurrence(b.original)
        }
        for completion in completions {
            for outcome in completion.outcomes {
                guard let canonical = outcome.event else { continue }
                let key = SyncPayload.event(canonical).key
                if let envelope = records[key] {
                    guard let payload = envelope.payload else { continue }
                    // Preserve authored historical edits; otherwise use the canonical completion.
                    guard
                        completion.outcomes.contains(where: {
                            $0.event.map(SyncPayload.event) == payload
                                || $0.alternatives.map(SyncPayload.event).contains(payload)
                        })
                    else { continue }
                }
                payloads[key] = .event(canonical)
            }
            var original = completion.original
            original.targets = original.targets.map { target in
                var value = target
                if let outcome = completion.outcomes.first(where: { $0.petID == target.petID }) {
                    value.completedAt = outcome.completedAt
                }
                return value
            }
            guard
                let latest =
                    (completion.outcomes.map(\.completedAt) + original.targets.compactMap(\.completedAt))
                    .max()
            else { continue }
            let result: ReminderCompletionResult
            if original.targets.isEmpty || original.incompleteTargets.isEmpty {
                result = ReminderActionService.complete(
                    original, completedPetIDs: [], completionTime: latest,
                    createsEvent: false, calendar: completion.calendar)
            } else {
                result = ReminderCompletionResult(updatedReminder: original, historyReminder: nil, events: [])
            }
            if let history = result.historyReminder {
                let key = SyncPayload.reminder(history).key
                if records[key] == nil { payloads[key] = .reminder(history) }
            }
            let key = SyncPayload.reminder(original).key
            // Completion projects onto the definition it used, never a newer manual edit/delete.
            if let definition = records[key], definition.payload != nil,
                definition.version == completion.definitionVersion
            {
                payloads[key] = .reminder(result.updatedReminder)
            }
        }
        let skips = payloads.values.compactMap { value -> SyncReminderSkip? in
            if case .skip(let skip) = value { return skip }
            return nil
        }.sorted { SyncIdentity.occurrence($0.original) < SyncIdentity.occurrence($1.original) }
        for skip in skips {
            let key = SyncPayload.reminder(skip.original).key
            guard records[key]?.payload != nil,
                  case .reminder(var reminder) = payloads[key],
                  reminder.dueAt == skip.original.dueAt,
                  let nextDueAt = skip.nextDueAt else { continue }
            reminder.dueAt = nextDueAt
            reminder.completedAt = nil
            reminder.ignoredUntil = nil
            reminder.targets = reminder.targets.map {
                ReminderTarget(petID: $0.petID, eventData: $0.eventData)
            }
            payloads[key] = .reminder(reminder)
        }
        payloads = payloads.filter {
            switch $0.value {
            case .completion, .skip: false
            default: true
            }
        }
        return SyncSnapshot(payloads: payloads)
    }
}

extension SyncSnapshot {
    init(payloads: [String: SyncPayload]) { self.payloads = payloads.mapValues(\.normalized) }
}

@MainActor
final class SyncJournal {
    private struct Prepared: Codable { var state: SyncState }
    private(set) var state: SyncState
    private let url: URL
    private var preparedURL: URL { url.appendingPathExtension("prepared") }
    private var stagedCompletion: (Reminder, Set<UUID>, Date, [CareEvent])?
    private var stagedSkip: SyncReminderSkip?

    init(url: URL, initial: SyncSnapshot, scope: SyncScope = .personal) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            state = try SyncCoding.decode(SyncState.self, from: Data(contentsOf: url))
            guard state.formatVersion == 1, state.scope == scope else { throw SyncError.unsupportedState }
            for (key, record) in state.records {
                guard key == record.key else { throw SyncError.invalidRecord }
                _ = try record.validated()
            }
        } else {
            state = SyncState(scope: scope, baseline: SyncSnapshot(payloads: [:]))
        }
        try recover(current: initial)
        var candidate = state
        try candidate.capture(initial)
        try commit(candidate)
    }

    func markCloudInitialized(context: ModelContext) throws {
        try recover(current: Self.snapshot(context: context))
        var candidate = state
        candidate.cloudInitialized = true
        try commit(candidate)
    }

    func bind(accountID: String, context: ModelContext) throws {
        try recover(current: Self.snapshot(context: context))
        if let previous = state.accountID, previous != accountID { throw SyncError.accountChanged }
        var candidate = state
        candidate.accountID = accountID
        try commit(candidate)
    }

    func stageCompletion(_ reminder: Reminder, pets: Set<UUID>, at time: Date, events: [CareEvent]) {
        stagedCompletion = (reminder, pets, time, events)
    }

    func stageSkip(_ reminder: Reminder, nextDueAt: Date?) {
        stagedSkip = SyncReminderSkip(original: reminder, nextDueAt: nextDueAt)
    }

    func transaction(context: ModelContext, action: () throws -> Void) throws {
        try recover(current: Self.snapshot(context: context))
        var saved = false
        do {
            try action()
            let snapshot = try Self.snapshot(context: context)
            var candidate = state
            var ignored: Set<String> = []
            if let (reminder, pets, time, events) = stagedCompletion {
                let reminderKey = SyncPayload.reminder(reminder).key
                if candidate.records[reminderKey] == nil {
                    try candidate.set(.reminder(reminder), key: reminderKey)
                }
                guard let version = candidate.records[reminderKey]?.version else {
                    throw SyncError.invalidRecord
                }
                let outcomes: [SyncCompletion.Outcome]
                if reminder.targets.isEmpty {
                    outcomes = [.init(petID: reminder.eventPetID, completedAt: time, event: events.first)]
                } else {
                    outcomes = reminder.targets.filter { pets.contains($0.petID) && $0.completedAt == nil }
                        .map { target in
                            .init(
                                petID: target.petID, completedAt: time,
                                event: events.first { $0.petID == target.petID })
                        }
                }
                let payload = SyncPayload.completion(
                    SyncCompletion(
                        original: reminder,
                        definitionVersion: version,
                        calendar: candidate.records[reminderKey]?.calendar ?? .current, outcomes: outcomes))
                try candidate.set(payload, key: payload.key)
                ignored = [reminderKey, "reminder-" + SyncIdentity.history(reminder).uuidString]
            }
            stagedCompletion = nil
            if let stagedSkip {
                let payload = SyncPayload.skip(stagedSkip)
                try candidate.set(payload, key: payload.key)
            }
            stagedSkip = nil
            try candidate.capture(snapshot, ignoring: ignored)
            let desired = candidate.projectedSnapshot()
            if desired != snapshot { try Self.apply(desired, context: context) }
            candidate.baseline = desired
            try prepare(candidate)
            guard try Self.snapshot(context: context) == desired else { throw SyncError.invalidRecord }
            try context.save()
            saved = true
            // If metadata commit fails, the prepared file survives for recovery. Local data is saved.
            do { try commit(candidate) } catch { return }
        } catch {
            stagedCompletion = nil
            stagedSkip = nil
            if !saved {
                context.rollback()
                try? FileManager.default.removeItem(at: preparedURL)
            }
            throw error
        }
    }

    func receive(_ incoming: [SyncEnvelope], context: ModelContext) throws {
        try recover(current: Self.snapshot(context: context))
        var candidate = state
        try candidate.receive(incoming)
        let desired = candidate.projectedSnapshot()
        candidate.baseline = desired
        try prepare(candidate)
        do {
            if try Self.snapshot(context: context) != desired {
                try Self.apply(desired, context: context)
                guard try Self.snapshot(context: context) == desired else { throw SyncError.invalidRecord }
                try context.save()
            }
        } catch {
            context.rollback()
            try? FileManager.default.removeItem(at: preparedURL)
            throw error
        }
        try commit(candidate)
    }

    func acknowledge(_ sent: [SyncEnvelope], context: ModelContext) throws {
        try recover(current: Self.snapshot(context: context))
        var candidate = state
        for envelope in sent where candidate.records[envelope.key] == envelope {
            candidate.pending.remove(envelope.key)
        }
        try commit(candidate)
    }

    func pending(context: ModelContext) throws -> [SyncEnvelope] {
        try recover(current: Self.snapshot(context: context))
        return state.pending.sorted().compactMap { state.records[$0] }
    }

    private func recover(current: SyncSnapshot) throws {
        guard FileManager.default.fileExists(atPath: preparedURL.path) else { return }
        let prepared = try SyncCoding.decode(Prepared.self, from: Data(contentsOf: preparedURL))
        guard prepared.state.formatVersion == 1, prepared.state.scope == state.scope,
            prepared.state.writer == state.writer
        else { throw SyncError.unsupportedState }
        for (key, record) in prepared.state.records {
            guard key == record.key else { throw SyncError.invalidRecord }
            _ = try record.validated()
        }
        if prepared.state.baseline == current {
            try commit(prepared.state)
        } else {
            try FileManager.default.removeItem(at: preparedURL)
        }
    }

    private func prepare(_ candidate: SyncState) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try SyncCoding.encode(Prepared(state: candidate)).write(to: preparedURL, options: .atomic)
    }

    private func commit(_ candidate: SyncState) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try SyncCoding.encode(candidate).write(to: url, options: .atomic)
        state = candidate
        if FileManager.default.fileExists(atPath: preparedURL.path) {
            try FileManager.default.removeItem(at: preparedURL)
        }
    }

    static func snapshot(context: ModelContext) throws -> SyncSnapshot {
        try SyncSnapshot(
            pets: SwiftDataPetRepository(context: context).listPets(),
            events: SwiftDataCareEventRepository(context: context).listEvents(),
            health: SwiftDataHealthEntryRepository(context: context).listHealthEntries(),
            options: SwiftDataSavedEventOptionRepository(context: context).listSavedOptions(
                includeDeleted: true),
            reminders: SwiftDataReminderRepository(context: context).listReminders(includeMuted: true),
            schedules: SwiftDataScheduledEventRepository(context: context).listScheduledEvents())
    }

    static func apply(_ snapshot: SyncSnapshot, context: ModelContext) throws {
        func removeMissing<T: PersistentModel>(_ type: T.Type, key: (T) -> String) throws {
            for record in try context.fetch(FetchDescriptor<T>()) where snapshot.payloads[key(record)] == nil
            {
                context.delete(record)
            }
        }
        try removeMissing(PetRecord.self) { "pet-" + $0.id.uuidString }
        try removeMissing(CareEventRecord.self) { "event-" + $0.id.uuidString }
        try removeMissing(HealthEntryRecord.self) { "health-" + $0.id.uuidString }
        try removeMissing(SavedEventOptionRecord.self) { "option-" + $0.id.uuidString }
        try removeMissing(ScheduledEventRecord.self) { "schedule-" + $0.id.uuidString }
        let reminders = SwiftDataReminderRepository(context: context, savesImmediately: false)
        for record in try context.fetch(FetchDescriptor<ReminderRecord>())
        where snapshot.payloads["reminder-" + record.id.uuidString] == nil {
            try reminders.deleteReminder(id: record.id)
        }
        for payload in snapshot.payloads.values {
            switch payload {
            case .pet(let value):
                try SwiftDataPetRepository(context: context, savesImmediately: false).savePet(value)
            case .event(let value):
                try SwiftDataCareEventRepository(context: context, savesImmediately: false).saveEvent(value)
            case .health(let value):
                try SwiftDataHealthEntryRepository(context: context, savesImmediately: false).saveHealthEntry(
                    value)
            case .option(let value):
                try SwiftDataSavedEventOptionRepository(context: context, savesImmediately: false)
                    .saveSavedOption(value)
            case .reminder(let value): try reminders.saveReminder(value)
            case .schedule(let value):
                try SwiftDataScheduledEventRepository(context: context, savesImmediately: false)
                    .saveScheduledEvent(value)
            case .completion, .skip: break
            }
        }
    }
}
