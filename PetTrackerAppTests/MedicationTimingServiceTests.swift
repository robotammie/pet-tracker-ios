import SwiftData
import XCTest
@testable import PetTrackerApp

final class MedicationTimingServiceTests: XCTestCase {
    private let pet = Pet(name: "Cat")
    private let time = Date(timeIntervalSince1970: 100_000)
    private let interval = MedicationDoseInterval(minimumHours: 8, maximumHours: 12)

    private func option(name: String = "Medicine", petIntervals: [PetMedicationDoseInterval] = []) -> SavedEventOption {
        SavedEventOption(eventType: .medicine, data: .medicine(SavedMedicineData(name: name, dosage: 1, unit: "tablet", doseInterval: interval, petDoseIntervals: petIntervals)))
    }

    private func dose(_ option: SavedEventOption, hours: Double = 0, petID: UUID? = nil, linked: Bool = true) -> CareEvent {
        guard case let .medicine(saved) = option.data else { fatalError() }
        return CareEvent(type: .medicine, petID: petID ?? pet.id, startTime: time.addingTimeInterval(hours * 3_600), data: .medicine(MedicineEventData(name: saved.name, dosage: 1, unit: "tablet", savedOptionID: linked ? option.id : nil)))
    }

    private func warnings(_ candidates: [CareEvent], history: [CareEvent], options: [SavedEventOption]) -> [MedicationTimingWarning] {
        MedicationTimingService.warnings(for: candidates, existing: history, options: options, pets: [pet])
    }

    func testMinimumBoundaryAndDifferentPetOrMedication() {
        let medicine = option()
        let other = option(name: "Other")
        let history = [dose(medicine)]
        XCTAssertEqual(warnings([dose(medicine, hours: 7.99)], history: history, options: [medicine]).count, 1)
        XCTAssertTrue(warnings([dose(medicine, hours: 8)], history: history, options: [medicine]).isEmpty)
        XCTAssertTrue(warnings([dose(medicine, hours: 1, petID: UUID()), dose(other, hours: 1)], history: history, options: [medicine, other]).isEmpty)
    }

    func testBackdateFollowingNeighborAndEditingExcludesSelf() {
        let medicine = option()
        let next = dose(medicine, hours: 9)
        let earlier = dose(medicine, hours: 3)
        XCTAssertEqual(warnings([earlier], history: [next], options: [medicine]).count, 1)
        XCTAssertTrue(warnings([next], history: [next], options: [medicine]).isEmpty)
        var edit = next
        edit.startTime = time.addingTimeInterval(4 * 3_600)
        XCTAssertEqual(warnings([edit], history: [dose(medicine), next], options: [medicine]).count, 1)
    }

    func testBatchChecksCandidatesAndPerPetPrescription() {
        let medicine = option(petIntervals: [PetMedicationDoseInterval(petID: pet.id, interval: MedicationDoseInterval(minimumHours: 12, maximumHours: 12))])
        XCTAssertEqual(warnings([dose(medicine), dose(medicine, hours: 9)], history: [], options: [medicine]).count, 2)
        let resolved = MedicationTimingService.resolved(dose(medicine), options: [medicine])
        XCTAssertEqual(MedicationTimingService.nextDoseWindow(for: resolved, options: [medicine])?.lowerBound, time.addingTimeInterval(12 * 3_600))
    }

    func testLegacyUniqueMatchAndAmbiguousHistoryRequireAcknowledgement() {
        let medicine = option()
        let legacy = dose(medicine, linked: false)
        XCTAssertEqual(warnings([dose(medicine, hours: 1)], history: [legacy], options: [medicine]).count, 1)
        let duplicate = option()
        XCTAssertNil({ () -> UUID? in
            if case let .medicine(data) = MedicationTimingService.resolved(legacy, options: [medicine, duplicate]).data { return data.savedOptionID }
            return nil
        }())
        XCTAssertEqual(warnings([dose(medicine, hours: 1)], history: [legacy], options: [medicine, duplicate]).count, 1)
        XCTAssertEqual(warnings([dose(medicine, hours: 1, linked: false)], history: [], options: [medicine, duplicate]).count, 1)
    }

    func testOldMedicineJSONStillDecodesWithoutTimingFields() throws {
        let data = try JSONDecoder().decode(MedicineEventData.self, from: Data(#"{"name":"Pill","dosage":1,"unit":"tablet"}"#.utf8))
        XCTAssertNil(data.savedOptionID)
        XCTAssertNil(data.doseInterval)
    }

    func testStoreCancelAndOverrideAreDeferredAndExactlyOnce() {
        let medicine = option()
        let original = dose(medicine)
        let candidate = dose(medicine, hours: 1)
        let store = PetCareStore(pets: [pet], events: [original], savedOptions: [medicine], notificationScheduler: TimingSilentScheduler())
        var saves = 0
        XCTAssertFalse(store.saveCareEventAndRefresh(candidate, onSaved: { saves += 1 }))
        XCTAssertEqual(store.events, [original])
        XCTAssertNotNil(store.medicationTimingPrompt)
        store.cancelMedicationTimingWrite()
        store.confirmMedicationTimingWrite()
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(store.events, [original])
        XCTAssertFalse(store.saveCareEventAndRefresh(candidate, onSaved: { saves += 1 }))
        store.confirmMedicationTimingWrite(at: time)
        store.confirmMedicationTimingWrite(at: time)
        XCTAssertEqual(saves, 1)
        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events.first { $0.id == candidate.id }?.doseTimingOverrideAt, time)
        XCTAssertNotNil(store.events.first { $0.id == candidate.id }?.doseTimingOverrideMessage)
    }

    func testChangedHistoryRequiresFreshAcknowledgement() {
        let medicine = option()
        let store = PetCareStore(pets: [pet], events: [dose(medicine)], savedOptions: [medicine], notificationScheduler: TimingSilentScheduler())
        let candidate = dose(medicine, hours: 1)
        store.saveCareEventAndRefresh(candidate)
        store.saveEvent(dose(medicine, hours: 0.5))
        store.confirmMedicationTimingWrite()
        XCTAssertEqual(store.events.count, 2)
        XCTAssertNotNil(store.medicationTimingPrompt)
        store.confirmMedicationTimingWrite()
        XCTAssertEqual(store.events.count, 3)
    }

    func testReminderCompleteNowBlocksAllPetsBeforeAnyStateChanges() {
        let medicine = option()
        let secondPet = Pet(name: "Other cat")
        let payload = dose(medicine).data
        let reminder = Reminder(title: "Dose", mode: .reminderToEvent, eventType: .medicine, dueAt: time, dueStyle: .timestamp, targets: [ReminderTarget(petID: pet.id, eventData: payload), ReminderTarget(petID: secondPet.id, eventData: payload)])
        let store = PetCareStore(pets: [pet, secondPet], events: [dose(medicine)], savedOptions: [medicine], reminders: [reminder], notificationScheduler: TimingSilentScheduler())
        let now = time.addingTimeInterval(3_600)
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        XCTAssertEqual(store.reminders, [reminder])
        XCTAssertEqual(store.events.count, 1)
        store.cancelMedicationTimingWrite()
        XCTAssertEqual(store.reminders, [reminder])
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        store.confirmMedicationTimingWrite(at: now)
        XCTAssertEqual(store.events.count, 3)
        XCTAssertEqual(store.reminders.first?.status, .completed)
        let new = store.events.filter { $0.startTime == now }
        XCTAssertEqual(new.count, 2)
        XCTAssertEqual(new.filter { $0.doseTimingOverrideAt != nil }.map(\.petID), [pet.id])
    }

    func testStaleReminderCannotCommitAfterWarning() {
        let medicine = option()
        let reminder = Reminder(title: "Dose", mode: .reminderToEvent, eventType: .medicine, eventPetID: pet.id, eventData: dose(medicine).data, dueAt: time, dueStyle: .timestamp)
        let store = PetCareStore(events: [dose(medicine)], savedOptions: [medicine], reminders: [reminder], notificationScheduler: TimingSilentScheduler())
        store.completeReminderNowAndRefresh(id: reminder.id, now: time.addingTimeInterval(3_600))
        store.deleteReminder(id: reminder.id)
        store.confirmMedicationTimingWrite()
        XCTAssertEqual(store.events.count, 1)
    }

    func testIntervalValidationDoesNotInferDefaults() {
        let model = SavedOptionFormViewModel(eventType: .medicine)
        model.name = "Pill"; model.dosage = 1; model.medicineUnit = "tablet"
        XCTAssertTrue(model.canSave())
        model.usesDoseTiming = true
        XCTAssertFalse(model.canSave())
        model.minimumDoseHours = 8; model.maximumDoseHours = 12
        XCTAssertTrue(model.canSave())
        model.maximumDoseHours = 7
        XCTAssertFalse(model.canSave())
        model.maximumDoseHours = .infinity
        XCTAssertFalse(model.canSave())
        model.maximumDoseHours = 12
        model.setPetDoseIntervalEnabled(true, petID: pet.id)
        XCTAssertFalse(model.canSave())
        model.setPetDoseHours(10, petID: pet.id, minimum: true)
        model.setPetDoseHours(10, petID: pet.id, minimum: false)
        XCTAssertTrue(model.canSave())
    }

    func testMedicationEditBlocksAndOverridesWithoutDuplicatingEvent() throws {
        let medicine = option()
        let first = dose(medicine)
        let second = dose(medicine, hours: 10)
        let store = PetCareStore(pets: [pet], events: [first, second], savedOptions: [medicine], notificationScheduler: TimingSilentScheduler())
        var draft = CareEventEditDraft(event: second)
        draft.timestamp = time.addingTimeInterval(4 * 3_600)
        draft.name = "Corrected label"
        let edited = try XCTUnwrap(draft.makeEvent(pets: [pet]))
        XCTAssertFalse(store.saveCareEventAndRefresh(edited))
        XCTAssertEqual(store.events, [first, second])
        store.confirmMedicationTimingWrite(at: time)
        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events.first { $0.id == second.id }?.startTime, draft.timestamp)
        XCTAssertEqual(store.events.first { $0.id == second.id }?.createdAt, second.createdAt)
        XCTAssertNotNil(store.events.first { $0.id == second.id }?.doseTimingOverrideMessage)
    }

    func testAutoqueuedReminderLinksMedicationAndPetIntervals() throws {
        let medicine = option(petIntervals: [PetMedicationDoseInterval(petID: pet.id,
            interval: MedicationDoseInterval(minimumHours: 10, maximumHours: 10))])
        let model = SavedOptionFormViewModel(option: medicine)
        model.shouldAutoqueueReminder = true
        model.reminderPetIDs = [pet.id]
        let reminder = try XCTUnwrap(model.makeAutoqueuedReminder(savedOption: medicine))
        guard case let .medicine(data) = reminder.targets.first?.eventData else { return XCTFail("Missing medicine") }
        XCTAssertEqual(data.savedOptionID, medicine.id)
        XCTAssertEqual(data.doseInterval?.minimumHours, 10)
        XCTAssertEqual(data.doseInterval?.maximumHours, 10)
    }

    func testTimingAndOverridePersistenceRoundTrip() throws {
        let schema = Schema([PetRecord.self, CareEventRecord.self, SavedEventOptionRecord.self, ReminderRecord.self, ReminderTargetRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let medicines = SwiftDataSavedEventOptionRepository(context: context)
        let events = SwiftDataCareEventRepository(context: context)
        let reminders = SwiftDataReminderRepository(context: context)
        let medicine = option(petIntervals: [PetMedicationDoseInterval(petID: pet.id, interval: interval)])
        try medicines.saveSavedOption(medicine)
        XCTAssertEqual(try medicines.listSavedOptions(includeDeleted: true), [medicine])
        var event = MedicationTimingService.resolved(dose(medicine), options: [medicine])
        event.doseTimingOverrideAt = time
        event.doseTimingOverrideMessage = "Acknowledged"
        try events.saveEvent(event)
        XCTAssertEqual(try events.listEvents(), [event])
        let reminder = Reminder(title: "Dose", mode: .reminderToEvent, eventType: .medicine, eventPetID: pet.id, eventData: event.data, dueAt: time, dueStyle: .timestamp, targets: [ReminderTarget(petID: pet.id, eventData: event.data)])
        try reminders.saveReminder(reminder)
        XCTAssertEqual(try reminders.listReminders(includeMuted: true), [reminder])
        let newContext = ModelContext(container)
        XCTAssertEqual(try SwiftDataCareEventRepository(context: newContext).listEvents(), [event])
        XCTAssertEqual(try SwiftDataReminderRepository(context: newContext).listReminders(includeMuted: true), [reminder])
    }
}

private struct TimingSilentScheduler: NotificationScheduling {
    func requestAuthorization() {}
    func sync(reminders: [Reminder], settings: UserSettings) {}
    func resetScheduledNotifications() {}
}
