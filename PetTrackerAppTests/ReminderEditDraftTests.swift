import XCTest
import SwiftData
@testable import PetTrackerApp

final class ReminderEditDraftTests: XCTestCase {
    let pet = Pet(name: "Cat")
    let other = Pet(name: "Other")
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testMultiEventFormPreservesIDsPayloadsAndPartialCompletion() throws {
        let food = ReminderEventAction(petID: pet.id, data: .food(FoodEventData(name: "Dinner", foodType: .wet, amount: 0.5, unit: .can, calories: 50, caloriesPerUnit: 100)))
        let med = ReminderEventAction(petID: pet.id, data: .medicine(MedicineEventData(name: "Pill", dosage: 1, unit: "tablet")))
        var form = ReminderFormDraft()
        form.details.title = "Dinner and pill"
        form.events = [food, med].map { ReminderEventActionDraft(type: $0.type, action: $0) }
        let reminder = try XCTUnwrap(form.makeReminder(pets: [pet]))
        XCTAssertNil(reminder.eventType)
        XCTAssertEqual(reminder.eventActions, [food, med])
        XCTAssertEqual(reminder.targets.map(\.petID), [pet.id])
        var edit = ReminderFormDraft(reminder: reminder)
        edit.details.title = "Edited"
        XCTAssertEqual(edit.makeReminder(pets: [pet])?.eventActions, [food, med])
        var partial = reminder
        partial.targets[0].completedAt = now
        var locked = ReminderFormDraft(reminder: partial)
        locked.events = []
        XCTAssertEqual(locked.makeReminder(pets: [pet])?.eventActions, [food, med])
        XCTAssertEqual(locked.makeReminder(pets: [pet])?.targets, partial.targets)
        edit.events[1].petID = nil
        XCTAssertNil(edit.makeReminder(pets: [pet]))
    }

    func testLitterRecurrenceDraftCreatesStableHouseholdSchedule() throws {
        var draft = ScheduledEventEditDraft(now: now)
        draft.repeatStyle = .every
        let event = CareEvent(type: .litter, petID: nil, startTime: now, data: .litter(LitterEventData()))
        let first = try XCTUnwrap(draft.schedules(for: [event], pets: []).first)
        let second = try XCTUnwrap(draft.schedules(for: [event], pets: []).first)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.type, .litter)
        XCTAssertNil(first.food)
        XCTAssertEqual(first.nextDueAt, now)
        draft.hasEndDate = true
        draft.endDate = now.addingTimeInterval(-1)
        XCTAssertTrue(draft.schedules(for: [event], pets: []).isEmpty)
    }

    func testPureReminderValidationAndEndDate() throws {
        var draft = ReminderEditDraft(now: now)
        XCTAssertNil(draft.makeReminder(pets: []))
        draft.title = "  Fountain  "
        let reminder = try XCTUnwrap(draft.makeReminder(pets: []))
        XCTAssertEqual(reminder.title, "Fountain")
        XCTAssertNil(reminder.eventData)
        XCTAssertTrue(reminder.targets.isEmpty)
        draft.hasEndDate = true
        draft.endDate = now.addingTimeInterval(-1)
        XCTAssertNil(draft.makeReminder(pets: []))
        draft.endDate = now.addingTimeInterval(86_400)
        XCTAssertNotNil(draft.makeReminder(pets: []))
        draft.selectedPetIDs = [UUID()]
        XCTAssertNil(draft.makeReminder(pets: [pet]))
    }

    func testHouseholdFoodStoresPayloadAndPetAmountsUseSnapshotRate() throws {
        var draft = ReminderEditDraft(now: now)
        draft.title = "Dinner"
        draft.mode = .reminderToEvent
        let option = SavedEventOption(eventType: .food, data: .food(SavedFoodData(name: "Food", unit: .can, caloriesPerUnit: 90, foodType: .wet)))
        draft.selectOption(option)
        var result = try XCTUnwrap(draft.makeReminder(pets: [pet]))
        XCTAssertTrue(result.targets.isEmpty)
        guard case let .food(food) = result.eventData else { return XCTFail("Expected food") }
        XCTAssertEqual(food.caloriesPerUnit, 90)
        draft.isHousehold = false
        draft.selectedPetIDs = [pet.id]
        draft.reconcilePayloads()
        draft.payloads[0].event.amount = 0.5
        draft.payloads[0].event.recalculateCalories()
        result = try XCTUnwrap(draft.makeReminder(pets: [pet]))
        guard case let .food(targetFood) = result.targets[0].eventData else { return XCTFail("Expected target food") }
        XCTAssertEqual(targetFood.calories, 45)
        draft.payloads[0].event.amount = 0
        XCTAssertNil(draft.makeReminder(pets: [pet]))
    }

    func testMedicineRequiresPetsAndRetainsIdentityAndPetSpecificIntervals() throws {
        var draft = ReminderEditDraft(now: now)
        draft.title = "Medicine"
        draft.mode = .reminderToEvent
        draft.eventType = .medicine
        draft.changeEventType()
        let interval = MedicationDoseInterval(minimumHours: 8, maximumHours: 12)
        let option = SavedEventOption(eventType: .medicine, data: .medicine(SavedMedicineData(name: "Drug", dosage: 1, unit: "mL", petDoseIntervals: [PetMedicationDoseInterval(petID: other.id, interval: interval)])))
        draft.selectOption(option)
        XCTAssertNil(draft.makeReminder(pets: [pet, other]))
        draft.selectedPetIDs = [pet.id, other.id]
        draft.reconcilePayloads()
        let reminder = try XCTUnwrap(draft.makeReminder(pets: [pet, other]))
        guard case let .medicine(data) = reminder.targets.first(where: { $0.petID == other.id })?.eventData else { return XCTFail("Expected medicine") }
        XCTAssertEqual(data.savedOptionID, option.id)
        XCTAssertEqual(data.doseInterval, interval)
        draft.payloads[0].event.dosage = 0
        XCTAssertNil(draft.makeReminder(pets: [pet, other]))
    }

    func testPartialCompletionEditPreservesCompletedTargetAndHistory() throws {
        let data = CareEventData.medicine(MedicineEventData(name: "Recorded Drug", dosage: 1, unit: "mL"))
        let original = Reminder(title: "Dose", mode: .reminderToEvent, eventType: .medicine, dueAt: now, dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day)), targets: [ReminderTarget(petID: pet.id, eventData: data, completedAt: now), ReminderTarget(petID: other.id, eventData: data)])
        let history = Reminder(title: "Old dose", mode: .pureReminder, eventType: nil, dueAt: now, dueStyle: .timestamp, status: .completed, completedAt: now)
        var draft = ReminderEditDraft(reminder: original, now: now)
        draft.title = "Edited schedule"
        draft.dueAt = now.addingTimeInterval(3_600)
        let edited = try XCTUnwrap(draft.makeReminder(pets: [pet, other]))
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.targets.first(where: { $0.petID == pet.id }), original.targets[0])
        let store = PetCareStore(pets: [pet, other], reminders: [original, history])
        store.saveReminderAndRefresh(edited)
        XCTAssertEqual(store.reminders.first(where: { $0.id == history.id }), history)
        let completion = ReminderActionService.complete(edited, completedPetIDs: [pet.id, other.id], completionTime: now, createsEvent: true)
        XCTAssertEqual(completion.events.count, 1)
        XCTAssertEqual(completion.events[0].petID, other.id)
        draft.selectedPetIDs = [other.id]
        XCTAssertNil(draft.makeReminder(pets: [pet, other]))
    }

    func testSchedulesValidateDayOnlyAndDistinctDailyTimes() throws {
        var draft = ReminderEditDraft(now: now)
        draft.title = "Routine"
        draft.repeatStyle = .every
        draft.recurrenceUnit = .hour
        draft.dueStyle = .dayOnly
        XCTAssertNil(draft.makeReminder(pets: []))
        draft.recurrenceUnit = .week
        XCTAssertNotNil(draft.makeReminder(pets: []))
        draft.repeatStyle = .timesPerDay
        draft.setDailyCount(3, now: now)
        XCTAssertNil(draft.makeReminder(pets: []))
        draft.dueStyle = .timestamp
        let result = try XCTUnwrap(draft.makeReminder(pets: []))
        guard case let .timesPerDay(count, times) = result.schedule?.recurrenceRule else { return XCTFail("Expected daily times") }
        XCTAssertEqual(count, 3)
        XCTAssertEqual(times.count, 3)
        draft.dailyTimes[1] = draft.dailyTimes[0]
        XCTAssertNil(draft.makeReminder(pets: []))
    }

    func testLitterIsHouseholdAndCompletedHistoryCannotBeEdited() throws {
        var draft = ReminderEditDraft(now: now)
        draft.title = "Litter"
        draft.mode = .reminderToEvent
        draft.eventType = .litter
        draft.changeEventType()
        var reminder = try XCTUnwrap(draft.makeReminder(pets: []))
        XCTAssertEqual(reminder.eventData, .litter(LitterEventData()))
        XCTAssertTrue(reminder.targets.isEmpty)
        reminder.status = .completed
        XCTAssertNil(ReminderEditDraft(reminder: reminder).makeReminder(pets: []))
    }

    func testAddingPetUsesRecordedPayloadWithoutRequiringSavedOption() throws {
        let data = CareEventData.medicine(MedicineEventData(name: "Old Drug", dosage: 2, unit: "mL"))
        let original = Reminder(title: "Dose", mode: .reminderToEvent, eventType: .medicine,
            dueAt: now, dueStyle: .timestamp, targets: [ReminderTarget(petID: pet.id, eventData: data)])
        var draft = ReminderEditDraft(reminder: original, now: now)
        draft.selectedPetIDs.insert(other.id)
        draft.reconcilePayloads()
        let edited = try XCTUnwrap(draft.makeReminder(pets: [pet, other]))
        XCTAssertEqual(edited.targets.count, 2)
        XCTAssertEqual(edited.targets.first(where: { $0.petID == other.id })?.eventData, data)
        var pure = original
        pure.mode = .pureReminder
        pure.eventType = nil
        pure.targets[0].completedAt = now
        let pureDraft = ReminderEditDraft(reminder: pure, now: now)
        XCTAssertEqual(pureDraft.makeReminder(pets: [pet])?.targets[0], pure.targets[0])
    }

    func testClearingOptionRequiresNewPayloadOrRestoresHistoricalSnapshot() throws {
        var draft = ReminderEditDraft(now: now)
        draft.title = "Food"
        draft.mode = .reminderToEvent
        let option = SavedEventOption(eventType: .food, data: .food(SavedFoodData(name: "New food", unit: .can, caloriesPerUnit: 90, foodType: .wet)))
        draft.selectOption(option)
        XCTAssertNotNil(draft.makeReminder(pets: []))
        draft.selectOption(nil)
        XCTAssertNil(draft.makeReminder(pets: []))
        let data = CareEventData.food(FoodEventData(name: "Historical food", foodType: .dry, amount: 0.5, unit: .cup, calories: 190))
        let original = Reminder(title: "Dinner", mode: .reminderToEvent, eventType: .food, eventData: data, dueAt: now, dueStyle: .timestamp)
        draft = ReminderEditDraft(reminder: original, now: now)
        draft.selectOption(option)
        draft.selectOption(nil)
        XCTAssertEqual(draft.makeReminder(pets: [])?.eventData, data)
    }

    func testEditedReminderAndTargetsPersistThroughRepository() throws {
        let schema = Schema([ReminderRecord.self, ReminderTargetRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let repository = SwiftDataReminderRepository(context: ModelContext(container))
        let original = Reminder(title: "Routine", mode: .pureReminder, eventType: nil, dueAt: now, dueStyle: .timestamp, targets: [ReminderTarget(petID: pet.id)])
        try repository.saveReminder(original)
        var draft = ReminderEditDraft(reminder: original, now: now)
        draft.title = "Updated"
        draft.repeatStyle = .every
        draft.recurrenceUnit = .month
        draft.interval = 2
        let edited = try XCTUnwrap(draft.makeReminder(pets: [pet]))
        try repository.saveReminder(edited)
        XCTAssertEqual(try repository.listReminders(includeMuted: true), [edited])
    }
}
