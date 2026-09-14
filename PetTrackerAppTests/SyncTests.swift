import CloudKit
import SwiftData
import XCTest

@testable import PetTrackerApp

@MainActor
final class SyncTests: XCTestCase {
    private var directories: [URL] = []
    private let time = Date(timeIntervalSince1970: 1_000_000)

    private func journal(_ context: ModelContext) throws -> SyncJournal {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        directories.append(root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try SyncJournal(
            url: root.appendingPathComponent("state.json"),
            initial: SyncJournal.snapshot(context: context))
    }

    private func context() throws -> ModelContext {
        let context = ModelContext(try LocalPersistence.makeContainer(inMemory: true))
        context.autosaveEnabled = false
        return context
    }

    private func reminder(pets: [Pet], recurring: Bool = true) -> Reminder {
        let data = CareEventData.medicine(MedicineEventData(name: "Dose", dosage: 1, unit: "tablet"))
        return Reminder(
            title: "Medication", mode: .reminderToEvent, eventType: .medicine,
            dueAt: time, dueStyle: .timestamp,
            schedule: recurring
                ? ReminderSchedule(recurrenceRule: .every(value: 8, unit: .hour), endDate: nil) : nil,
            targets: pets.map { ReminderTarget(petID: $0.id, eventData: data) })
    }

    private func complete(
        _ reminder: Reminder, pets: Set<UUID>, at date: Date,
        context: ModelContext, journal: SyncJournal
    ) throws {
        let result = ReminderActionService.complete(
            reminder, completedPetIDs: pets, completionTime: date, createsEvent: true)
        try journal.transaction(context: context) {
            let events = SwiftDataCareEventRepository(context: context, savesImmediately: false)
            try result.events.forEach(events.saveEvent)
            let reminders = SwiftDataReminderRepository(context: context, savesImmediately: false)
            try reminders.saveReminder(result.updatedReminder)
            if let history = result.historyReminder { try reminders.saveReminder(history) }
            journal.stageCompletion(reminder, pets: pets, at: date, events: result.events)
        }
    }

    func testDeterministicCompletionIDsDistinguishPetsAndOccurrences() {
        let first = Pet(name: "A")
        let second = Pet(name: "B")
        let original = reminder(pets: [first, second])
        let a = ReminderActionService.complete(
            original, completedPetIDs: [first.id, second.id], completionTime: time, createsEvent: true)
        let b = ReminderActionService.complete(
            original, completedPetIDs: [first.id, second.id], completionTime: time.addingTimeInterval(10),
            createsEvent: true)
        XCTAssertEqual(a.events.map(\.id), b.events.map(\.id))
        XCTAssertEqual(a.historyReminder?.id, b.historyReminder?.id)
        XCTAssertNotEqual(a.events[0].id, a.events[1].id)
        XCTAssertNotEqual(
            SyncIdentity.event(original, petID: first.id),
            SyncIdentity.event(a.updatedReminder, petID: first.id))
    }

    func testConcurrentSamePetCompletionConvergesToOneEventHistoryAndNextOccurrence() throws {
        let a = try context()
        let b = try context()
        let pet = Pet(name: "A")
        let original = reminder(pets: [pet])
        try SwiftDataPetRepository(context: a).savePet(pet)
        try SwiftDataReminderRepository(context: a).saveReminder(original)
        let ja = try journal(a)
        let jb = try journal(b)
        try jb.receive(Array(ja.state.records.values), context: b)
        try complete(original, pets: [pet.id], at: time, context: a, journal: ja)
        try complete(original, pets: [pet.id], at: time.addingTimeInterval(30), context: b, journal: jb)
        try ja.receive(Array(jb.state.records.values), context: a)
        try jb.receive(Array(ja.state.records.values), context: b)
        XCTAssertEqual(try SyncJournal.snapshot(context: a), try SyncJournal.snapshot(context: b))
        let events = try SwiftDataCareEventRepository(context: a).listEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.startTime, time)
        let reminders = try SwiftDataReminderRepository(context: a).listReminders(includeMuted: true)
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.filter { $0.status == .completed }.first?.completedAt, time)
        XCTAssertEqual(reminders.filter { $0.isActive }.first?.dueAt, time.addingTimeInterval(8 * 3_600))
        // Replay is idempotent; authored event edits must survive later completion replay.
        var edited = try XCTUnwrap(events.first)
        edited.startTime = time.addingTimeInterval(-100)
        try ja.transaction(context: a) {
            try SwiftDataCareEventRepository(context: a, savesImmediately: false).saveEvent(edited)
        }
        try ja.receive(Array(jb.state.records.values), context: a)
        XCTAssertEqual(try SwiftDataCareEventRepository(context: a).listEvents(), [edited])
    }

    func testConcurrentDifferentPetCompletionMergesPartialTargets() throws {
        let a = try context()
        let b = try context()
        let first = Pet(name: "A")
        let second = Pet(name: "B")
        let original = reminder(pets: [first, second])
        try SwiftDataPetRepository(context: a).savePet(first)
        try SwiftDataPetRepository(context: a).savePet(second)
        try SwiftDataReminderRepository(context: a).saveReminder(original)
        let ja = try journal(a)
        let jb = try journal(b)
        try jb.receive(Array(ja.state.records.values), context: b)
        try complete(original, pets: [first.id], at: time, context: a, journal: ja)
        try complete(original, pets: [second.id], at: time.addingTimeInterval(20), context: b, journal: jb)
        try ja.receive(Array(jb.state.records.values), context: a)
        try jb.receive(Array(ja.state.records.values), context: b)
        XCTAssertEqual(try SyncJournal.snapshot(context: a), try SyncJournal.snapshot(context: b))
        XCTAssertEqual(try SwiftDataCareEventRepository(context: a).listEvents().count, 2)
        let reminders = try SwiftDataReminderRepository(context: a).listReminders(includeMuted: true)
        let history = try XCTUnwrap(reminders.first { $0.status == .completed })
        XCTAssertEqual(history.targets.first { $0.petID == first.id }?.completedAt, time)
        XCTAssertEqual(
            history.targets.first { $0.petID == second.id }?.completedAt, time.addingTimeInterval(20))
        XCTAssertEqual(reminders.first { $0.isActive }?.dueAt, time.addingTimeInterval(20 + 8 * 3_600))
    }

    func testDeleteWinsOverOfflineEditAndReplay() throws {
        let a = try context()
        let b = try context()
        let event = CareEvent(
            type: .litter, petID: nil, createdAt: time, startTime: time, data: .litter(LitterEventData()))
        try SwiftDataCareEventRepository(context: a).saveEvent(event)
        let ja = try journal(a)
        let jb = try journal(b)
        try jb.receive(Array(ja.state.records.values), context: b)
        try ja.transaction(context: a) {
            try SwiftDataCareEventRepository(context: a, savesImmediately: false).deleteEvent(id: event.id)
        }
        var edited = event
        edited.startTime = time.addingTimeInterval(100)
        try jb.transaction(context: b) {
            try SwiftDataCareEventRepository(context: b, savesImmediately: false).saveEvent(edited)
        }
        try ja.receive(Array(jb.state.records.values), context: a)
        try jb.receive(Array(ja.state.records.values), context: b)
        XCTAssertTrue(try SwiftDataCareEventRepository(context: a).listEvents().isEmpty)
        XCTAssertTrue(try SwiftDataCareEventRepository(context: b).listEvents().isEmpty)
    }

    func testEqualVersionEditsConvergeWithClonedBackupWriterIdentity() throws {
        let pet = Pet(name: "A")
        var edited = pet
        edited.name = "B"
        let version = SyncVersion(counter: 1, writer: UUID())
        let a = SyncEnvelope(key: SyncPayload.pet(pet).key, version: version, payload: .pet(pet))
        let b = SyncEnvelope(key: a.key, version: version, payload: .pet(edited))
        XCTAssertEqual(try a.merging(b), try b.merging(a))
        XCTAssertEqual(try a.merging(b).merging(a), try a.merging(b))
    }

    func testRestartRetainsPendingChangesAndStaleAcknowledgementDoesNotClearNewEdit() throws {
        let context = try context()
        let journal = try journal(context)
        let pet = Pet(name: "Original")
        try journal.transaction(context: context) {
            try SwiftDataPetRepository(context: context, savesImmediately: false).savePet(pet)
        }
        let sent = try journal.pending(context: context)
        var edited = pet
        edited.name = "Edited"
        try journal.transaction(context: context) {
            try SwiftDataPetRepository(context: context, savesImmediately: false).savePet(edited)
        }
        try journal.acknowledge(sent, context: context)
        let url = try XCTUnwrap(directories.last).appendingPathComponent("state.json")
        let reopened = try SyncJournal(url: url, initial: SyncJournal.snapshot(context: context))
        XCTAssertEqual(try reopened.pending(context: context).count, 1)
        XCTAssertEqual(reopened.state.records[SyncPayload.pet(pet).key]?.payload, .pet(edited))
        try reopened.acknowledge(reopened.pending(context: context), context: context)
        XCTAssertTrue(try reopened.pending(context: context).isEmpty)
    }

    func testAccountChangeIsRejectedAndScopeIsPartOfPersistedIdentity() throws {
        let context = try context()
        let journal = try journal(context)
        try journal.bind(accountID: "first", context: context)
        XCTAssertThrowsError(try journal.bind(accountID: "second", context: context))
        XCTAssertEqual(journal.state.accountID, "first")
        let url = try XCTUnwrap(directories.last).appendingPathComponent("state.json")
        let shared = SyncScope(database: .shared, zoneName: "Household", ownerName: "owner")
        XCTAssertThrowsError(
            try SyncJournal(url: url, initial: SyncJournal.snapshot(context: context), scope: shared))
        var production = SyncScope.personal
        production.environment = .production
        XCTAssertThrowsError(
            try SyncJournal(url: url, initial: SyncJournal.snapshot(context: context), scope: production))
    }

    func testInvalidCloudRecordIsRejectedWithoutLocalChanges() throws {
        let context = try context()
        let journal = try journal(context)
        let pet = Pet(name: "A")
        let invalid = SyncEnvelope(
            key: "pet-" + UUID().uuidString,
            version: .init(counter: 1, writer: UUID()), payload: .pet(pet))
        XCTAssertThrowsError(try journal.receive([invalid], context: context))
        XCTAssertTrue(try SwiftDataPetRepository(context: context).listPets().isEmpty)
        let record = CKRecord(
            recordType: CloudKitTransport.recordType, recordID: .init(recordName: invalid.key))
        record["envelope"] = try SyncCoding.encode(invalid) as CKRecordValue
        XCTAssertThrowsError(try CloudKitTransport.envelope(from: record))
        XCTAssertNil(SyncBuildConfiguration.containerIdentifier)
    }

    func testManualReminderEditWinsOverCompletionOfOlderDefinition() throws {
        let a = try context()
        let b = try context()
        let pet = Pet(name: "A")
        let original = reminder(pets: [pet])
        try SwiftDataPetRepository(context: a).savePet(pet)
        try SwiftDataReminderRepository(context: a).saveReminder(original)
        let ja = try journal(a)
        let jb = try journal(b)
        try jb.receive(Array(ja.state.records.values), context: b)
        try complete(original, pets: [pet.id], at: time, context: a, journal: ja)
        var edited = original
        edited.title = "Edited definition"
        edited.dueAt = time.addingTimeInterval(3_600)
        try jb.transaction(context: b) {
            try SwiftDataReminderRepository(context: b, savesImmediately: false).saveReminder(edited)
        }
        try ja.receive(Array(jb.state.records.values), context: a)
        try jb.receive(Array(ja.state.records.values), context: b)
        XCTAssertEqual(try SyncJournal.snapshot(context: a), try SyncJournal.snapshot(context: b))
        let reminders = try SwiftDataReminderRepository(context: a).listReminders(includeMuted: true)
        XCTAssertEqual(reminders.first { $0.id == original.id }, edited)
        XCTAssertEqual(reminders.filter { $0.status == .completed }.count, 1)
        XCTAssertEqual(try SwiftDataCareEventRepository(context: a).listEvents().count, 1)
    }

    func testRepeatedConcurrentOccurrencesKeepDistinctHistoryAndOnlyOneActiveReminder() throws {
        let a = try context()
        let b = try context()
        let pet = Pet(name: "A")
        let original = reminder(pets: [pet])
        try SwiftDataPetRepository(context: a).savePet(pet)
        try SwiftDataReminderRepository(context: a).saveReminder(original)
        let ja = try journal(a)
        let jb = try journal(b)
        try jb.receive(Array(ja.state.records.values), context: b)
        for _ in 0..<2 {
            let active = try XCTUnwrap(
                SwiftDataReminderRepository(context: a).listReminders().first { $0.isActive })
            try complete(active, pets: [pet.id], at: active.dueAt, context: a, journal: ja)
            try complete(
                active, pets: [pet.id], at: active.dueAt.addingTimeInterval(30), context: b, journal: jb)
            try ja.receive(Array(jb.state.records.values), context: a)
            try jb.receive(Array(ja.state.records.values), context: b)
        }
        XCTAssertEqual(try SyncJournal.snapshot(context: a), try SyncJournal.snapshot(context: b))
        let reminders = try SwiftDataReminderRepository(context: a).listReminders(includeMuted: true)
        XCTAssertEqual(reminders.filter { $0.isActive }.count, 1)
        XCTAssertEqual(reminders.filter { $0.status == .completed }.count, 2)
        XCTAssertEqual(try SwiftDataCareEventRepository(context: a).listEvents().count, 2)
    }

    func testPreparedJournalRecoversOnlyAfterMatchingLocalSave() throws {
        struct Prepared: Codable { var state: SyncState }
        let context = try context()
        let originalJournal = try journal(context)
        let url = try XCTUnwrap(directories.last).appendingPathComponent("state.json")
        let preparedURL = url.appendingPathExtension("prepared")
        let pet = Pet(name: "Recovered")
        var candidate = originalJournal.state
        let desired = SyncSnapshot(pets: [pet], events: [], health: [], options: [], reminders: [])
        try candidate.capture(desired)
        try SyncCoding.encode(Prepared(state: candidate)).write(to: preparedURL, options: .atomic)
        // No local save: discard preparation rather than uploading a failed write.
        let failedWrite = try SyncJournal(url: url, initial: SyncJournal.snapshot(context: context))
        XCTAssertTrue(try failedWrite.pending(context: context).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: preparedURL.path))
        // Local save succeeded, metadata commit did not: recover the durable pending change.
        try SwiftDataPetRepository(context: context).savePet(pet)
        try SyncCoding.encode(Prepared(state: candidate)).write(to: preparedURL, options: .atomic)
        let recovered = try SyncJournal(url: url, initial: SyncJournal.snapshot(context: context))
        XCTAssertEqual(try recovered.pending(context: context).map(\.payload), [.pet(pet)])
        XCTAssertFalse(FileManager.default.fileExists(atPath: preparedURL.path))
    }

    func testAcknowledgementRecoversPreparedEditBeforeClearingOldChange() throws {
        struct Prepared: Codable { var state: SyncState }
        let context = try context()
        let pet = Pet(name: "Original")
        try SwiftDataPetRepository(context: context).savePet(pet)
        let journal = try journal(context)
        let sent = try journal.pending(context: context)
        var edited = pet
        edited.name = "Prepared edit"
        try SwiftDataPetRepository(context: context).savePet(edited)
        var candidate = journal.state
        try candidate.capture(SyncJournal.snapshot(context: context))
        let url = try XCTUnwrap(directories.last).appendingPathComponent("state.json.prepared")
        try SyncCoding.encode(Prepared(state: candidate)).write(to: url, options: .atomic)
        try journal.acknowledge(sent, context: context)
        XCTAssertEqual(try journal.pending(context: context).map(\.payload), [.pet(edited)])
        try journal.bind(accountID: "test-account", context: context)
        XCTAssertEqual(journal.state.records[SyncPayload.pet(pet).key]?.payload, .pet(edited))
    }

    func testCorruptJournalDoesNotBecomeAnEmptySyncDataset() throws {
        let context = try context()
        let journal = try journal(context)
        let url = try XCTUnwrap(directories.last).appendingPathComponent("state.json")
        try Data("invalid JSON".utf8).write(to: url)
        XCTAssertThrowsError(try SyncJournal(url: url, initial: SyncJournal.snapshot(context: context)))
        XCTAssertEqual(journal.state.records.count, 0)
    }

    func testCompletionProjectionUsesPersistedSchedulingCalendar() throws {
        let pet = Pet(name: "A")
        var original = reminder(pets: [pet])
        original.schedule = ReminderSchedule(
            recurrenceRule: .timesPerDay(
                count: 2,
                times: [DateComponents(hour: 8), DateComponents(hour: 20)]), endDate: nil)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let version = SyncVersion(counter: 1, writer: UUID())
        let definition = SyncPayload.reminder(original)
        let completion = SyncPayload.completion(
            SyncCompletion(
                original: original, definitionVersion: version,
                calendar: calendar, outcomes: [.init(petID: pet.id, completedAt: time, event: nil)]))
        let state = SyncState(
            records: [
                definition.key: SyncEnvelope(
                    key: definition.key, version: version, calendar: calendar, payload: definition),
                completion.key: SyncEnvelope(
                    key: completion.key, version: .init(counter: 2, writer: version.writer),
                    payload: completion),
            ], baseline: SyncSnapshot(payloads: [:]))
        let expected = ReminderActionService.complete(
            original, completedPetIDs: [pet.id], completionTime: time,
            createsEvent: false, calendar: calendar)
        XCTAssertEqual(
            state.projectedSnapshot().payloads[definition.key], SyncPayload.reminder(expected.updatedReminder).normalized)
        XCTAssertEqual(
            state.projectedSnapshot().payloads["reminder-" + SyncIdentity.history(original).uuidString],
            expected.historyReminder.map { SyncPayload.reminder($0).normalized })
    }

    func testStoreCompletionJournalsInSameTransactionAndDeletionStaysDeleted() throws {
        let context = try context()
        let pet = Pet(name: "A")
        let original = reminder(pets: [pet])
        try SwiftDataPetRepository(context: context).savePet(pet)
        try SwiftDataReminderRepository(context: context).saveReminder(original)
        let journal = try journal(context)
        let store = PetCareStore(notificationScheduler: SyncSilentScheduler())
        store.configurePersistence(
            petRepository: SwiftDataPetRepository(context: context, savesImmediately: false),
            eventRepository: SwiftDataCareEventRepository(context: context, savesImmediately: false),
            savedOptionRepository: SwiftDataSavedEventOptionRepository(
                context: context, savesImmediately: false),
            reminderRepository: SwiftDataReminderRepository(context: context, savesImmediately: false),
            healthRepository: SwiftDataHealthEntryRepository(context: context, savesImmediately: false),
            performTransaction: { try journal.transaction(context: context, action: $0) })
        store.onReminderCompleted = { journal.stageCompletion($0, pets: $1, at: $2, events: $3) }
        store.refreshFromPersistence()
        store.completeReminderNowAndRefresh(id: original.id, now: time)
        XCTAssertEqual(
            journal.state.records.values.filter {
                if case .completion = $0.payload { return true }
                return false
            }.count, 1)
        XCTAssertEqual(store.events.count, 1)
        let event = try XCTUnwrap(store.events.first)
        XCTAssertTrue(store.deleteCareEventAndRefresh(id: event.id))
        try journal.receive(Array(journal.state.records.values), context: context)
        store.refreshFromPersistence()
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.reminders.filter { $0.status == .completed }.count, 1)
    }

    func testCoordinatorRetriesOfflineAndImportsHealthWithoutChangingDeviceSettings() async throws {
        let context = try context()
        let journal = try journal(context)
        let scheduler = SyncCountingScheduler()
        let store = PetCareStore(notificationScheduler: scheduler)
        store.settings.defaultDayOnlyNotificationHour = 7
        let pet = Pet(name: "A")
        try journal.transaction(context: context) {
            try SwiftDataPetRepository(context: context, savesImmediately: false).savePet(pet)
        }
        let transport = MemorySyncTransport()
        transport.available = false
        let coordinator = SyncCoordinator(
            journal: journal, transport: transport, context: context, store: store)
        await coordinator.syncNow()
        XCTAssertEqual(try journal.pending(context: context).count, 1)
        XCTAssertTrue(store.syncStatus.contains("unavailable"))
        transport.available = true
        let health = HealthEntry(petID: pet.id, happenedAt: time, title: "Visit", data: .vetVisit)
        let payload = SyncPayload.health(health)
        transport.records[payload.key] = SyncEnvelope(
            key: payload.key,
            version: .init(counter: 100, writer: UUID()), payload: payload)
        store.configurePersistence(
            petRepository: SwiftDataPetRepository(context: context),
            eventRepository: SwiftDataCareEventRepository(context: context),
            savedOptionRepository: SwiftDataSavedEventOptionRepository(context: context),
            reminderRepository: SwiftDataReminderRepository(context: context),
            healthRepository: SwiftDataHealthEntryRepository(context: context))
        await coordinator.syncNow()
        XCTAssertTrue(try journal.pending(context: context).isEmpty)
        XCTAssertEqual(store.healthEntries, [health])
        XCTAssertEqual(store.settings.defaultDayOnlyNotificationHour, 7)
        XCTAssertGreaterThan(scheduler.count, 0)
        XCTAssertEqual(store.syncStatus, "Up to date with iCloud")
        transport.identity = "other-account"
        await coordinator.syncNow()
        XCTAssertTrue(store.syncStatus.contains("account changed"))
        XCTAssertEqual(journal.state.accountID, "test-account")
    }

    func testUnsupportedSnapshotFieldRollsBackImportInsteadOfDroppingData() throws {
        let context = try context()
        let pet = Pet(name: "Kept")
        try SwiftDataPetRepository(context: context).savePet(pet)
        let journal = try journal(context)
        // Reminder templates in the existing local schema do not store this optional rate.
        let food = CareEventData.food(
            FoodEventData(
                name: "Food", foodType: .wet, amount: 1,
                unit: .can, calories: 90, caloriesPerUnit: 90))
        let reminder = Reminder(
            title: "Foreign template", mode: .reminderToEvent, eventType: .food,
            eventData: food, dueAt: time, dueStyle: .timestamp)
        let payload = SyncPayload.reminder(reminder)
        XCTAssertThrowsError(
            try journal.receive(
                [
                    SyncEnvelope(
                        key: payload.key,
                        version: .init(counter: 100, writer: UUID()), calendar: .current, payload: payload)
                ], context: context))
        XCTAssertEqual(try SwiftDataPetRepository(context: context).listPets(), [pet])
        XCTAssertTrue(
            try SwiftDataReminderRepository(context: context).listReminders(includeMuted: true).isEmpty)
        XCTAssertNil(journal.state.records[payload.key])
    }

    func testInvalidPayloadIsRejectedBeforeReplacingExistingData() throws {
        let context = try context()
        let pet = Pet(name: "Kept")
        try SwiftDataPetRepository(context: context).savePet(pet)
        let journal = try journal(context)
        var invalid = HealthEntry(
            petID: pet.id, title: "Weight", data: .weight(.init(value: 9, unit: .pound)))
        invalid.data = .weight(.init(value: -9, unit: .pound))
        let payload = SyncPayload.health(invalid)
        XCTAssertThrowsError(
            try journal.receive(
                [
                    SyncEnvelope(
                        key: payload.key,
                        version: .init(counter: 100, writer: UUID()), payload: payload)
                ], context: context))
        XCTAssertEqual(try SwiftDataPetRepository(context: context).listPets(), [pet])
        XCTAssertTrue(try SwiftDataHealthEntryRepository(context: context).listHealthEntries().isEmpty)
    }

    func testSyncPayloadRoundTripsHealthAndMedicationSnapshotsWithoutDeviceSettings() throws {
        let pet = Pet(name: "A")
        let health = HealthEntry(
            petID: pet.id, title: "Weight", notes: "Notes",
            data: .weight(WeightMeasurement(value: 9.5, unit: .pound)))
        let option = SavedEventOption(
            eventType: .medicine,
            data: .medicine(
                SavedMedicineData(
                    name: "Dose",
                    dosage: 2, unit: "mL",
                    cadence: MedicineCadence(
                        rule: .timesPerDay(
                            count: 2,
                            times: [DateComponents(hour: 8), DateComponents(hour: 20)])),
                    purpose: "As needed",
                    doseInterval: .init(minimumHours: 8, maximumHours: 12),
                    petDoseIntervals: [
                        .init(petID: pet.id, interval: .init(minimumHours: 10, maximumHours: 12))
                    ])))
        let snapshot = SyncSnapshot(
            pets: [pet], events: [], health: [health], options: [option], reminders: [reminder(pets: [pet])])
        XCTAssertEqual(try SyncCoding.decode(SyncSnapshot.self, from: SyncCoding.encode(snapshot)), snapshot)
        XCTAssertFalse(
            String(decoding: try SyncCoding.encode(snapshot), as: UTF8.self).contains(
                "NotificationPreferences"))
    }
}

private struct SyncSilentScheduler: NotificationScheduling {
    func requestAuthorization() {}
    func sync(reminders: [Reminder], settings: UserSettings) {}
    func resetScheduledNotifications() {}
}

private final class SyncCountingScheduler: NotificationScheduling {
    var count = 0
    func requestAuthorization() {}
    func sync(reminders: [Reminder], settings: UserSettings) { count += 1 }
    func resetScheduledNotifications() {}
}

@MainActor
private final class MemorySyncTransport: SyncTransport {
    var available = true
    var identity = "test-account"
    var records: [String: SyncEnvelope] = [:]
    func accountIdentity() async throws -> String {
        guard available else { throw SyncError.unavailable }
        return identity
    }
    func prepare(scope: SyncScope, mayCreateZone: Bool) async throws {}
    func fetch(scope: SyncScope) async throws -> [SyncEnvelope] { Array(records.values) }
    func send(_ changes: [SyncEnvelope], scope: SyncScope) async throws -> SyncSendResult {
        var reply = SyncSendResult()
        for change in changes {
            let merged = try records[change.key]?.merging(change) ?? change
            records[change.key] = merged
            if merged == change { reply.acknowledged.append(change) } else { reply.conflicts.append(merged) }
        }
        return reply
    }
}
