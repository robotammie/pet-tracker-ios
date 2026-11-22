import XCTest
@testable import PetTrackerApp

final class ReminderActionServiceTests: XCTestCase {
    func testMixedEventsCompletePerPetAndHouseholdOnlyOnceWithDistinctIDs() {
        let a = UUID(), b = UUID()
        let now = Date()
        let actions = [
            ReminderEventAction(petID: a, data: .food(FoodEventData(name: "Food", foodType: .dry, amount: 1, unit: .cup, calories: 10))),
            ReminderEventAction(petID: a, data: .medicine(MedicineEventData(name: "Med", dosage: 1, unit: "pill"))),
            ReminderEventAction(petID: b, data: .medicine(MedicineEventData(name: "Med", dosage: 2, unit: "pill"))),
            ReminderEventAction(data: .litter(LitterEventData()))]
        let reminder = Reminder(title: "Routine", mode: .reminderToEvent, eventType: nil, dueAt: now,
            dueStyle: .timestamp, schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day)),
            targets: [ReminderTarget(petID: a), ReminderTarget(petID: b)], eventActions: actions)
        let first = ReminderActionService.complete(reminder, completedPetIDs: [a], completionTime: now, createsEvent: true)
        XCTAssertEqual(first.events.count, 3)
        XCTAssertEqual(Set(first.events.map(\.id)).count, 3)
        XCTAssertNil(first.historyReminder)
        let second = ReminderActionService.complete(first.updatedReminder, completedPetIDs: [b], completionTime: now.addingTimeInterval(60), createsEvent: true)
        XCTAssertEqual(second.events.count, 1)
        XCTAssertEqual(second.events.first?.petID, b)
        XCTAssertEqual(second.historyReminder?.eventActions, actions)
        XCTAssertEqual(second.updatedReminder.eventActions, actions)
        XCTAssertTrue(second.updatedReminder.targets.allSatisfy { $0.completedAt == nil })
    }

    func testMixedCompletionMedicationWarningCancelsAllEventWrites() {
        let pet = Pet(name: "Cat")
        let now = Date()
        let data = MedicineEventData(name: "Med", dosage: 1, unit: "pill", savedOptionID: UUID(),
            doseInterval: MedicationDoseInterval(minimumHours: 12, maximumHours: 12))
        let previous = CareEvent(type: .medicine, petID: pet.id, startTime: now.addingTimeInterval(-3600), data: .medicine(data))
        let actions = [ReminderEventAction(petID: pet.id, data: .medicine(data)), ReminderEventAction(data: .litter(LitterEventData()))]
        let reminder = Reminder(title: "Routine", mode: .reminderToEvent, eventType: nil, dueAt: now,
            dueStyle: .timestamp, targets: [ReminderTarget(petID: pet.id)], eventActions: actions)
        let store = PetCareStore(pets: [pet], events: [previous], reminders: [reminder])
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        XCTAssertNotNil(store.medicationTimingPrompt)
        XCTAssertEqual(store.events, [previous])
        XCTAssertEqual(store.reminders, [reminder])
        store.cancelMedicationTimingWrite()
        XCTAssertEqual(store.events, [previous])
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        store.confirmMedicationTimingWrite(at: now)
        XCTAssertEqual(store.events.count, 3)
        XCTAssertEqual(store.reminders.first?.status, .completed)
    }

    func testPartialCompletionKeepsReminderActiveAndCreatesSelectedPetEvent() {
        let appaID = UUID()
        let momoID = UUID()
        let completionTime = Date()
        let reminder = Reminder(
            title: "Medicine",
            mode: .reminderToEvent,
            eventType: .medicine,
            eventData: .medicine(MedicineEventData(name: "Pill", dosage: 1, unit: "tablet")),
            dueAt: completionTime,
            dueStyle: .timestamp,
            targets: [
                ReminderTarget(
                    petID: appaID,
                    eventData: .medicine(MedicineEventData(name: "Pill", dosage: 1, unit: "tablet"))
                ),
                ReminderTarget(
                    petID: momoID,
                    eventData: .medicine(MedicineEventData(name: "Pill", dosage: 0.5, unit: "tablet"))
                )
            ]
        )

        let result = ReminderActionService.complete(
            reminder,
            completedPetIDs: [appaID],
            completionTime: completionTime,
            createsEvent: true
        )

        XCTAssertEqual(result.updatedReminder.status, .active)
        XCTAssertEqual(result.updatedReminder.incompleteTargets.map(\.petID), [momoID])
        XCTAssertEqual(result.events.map(\.petID), [appaID])
    }

    func testRecurringCompletionKeepsHistoryAndSchedulesNextReminder() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dueAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8)))
        let completionTime = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let reminder = Reminder(
            title: "Medicine",
            mode: .pureReminder,
            eventType: .medicine,
            dueAt: dueAt,
            dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil)
        )

        let result = ReminderActionService.complete(
            reminder,
            completedPetIDs: [],
            completionTime: completionTime,
            createsEvent: false,
            calendar: calendar
        )

        XCTAssertEqual(result.updatedReminder.status, .active)
        XCTAssertEqual(result.updatedReminder.dueAt, calendar.date(byAdding: .day, value: 1, to: completionTime))
        XCTAssertEqual(result.historyReminder?.status, .completed)
        XCTAssertEqual(result.historyReminder?.dueAt, dueAt)
    }

    func testRecurringIgnoreWithoutFutureUpdatePreservesScheduleDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dueAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8)))
        let ignoredUntil = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))
        let reminder = Reminder(
            title: "Medicine",
            mode: .pureReminder,
            eventType: .medicine,
            dueAt: dueAt,
            dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil)
        )

        let ignored = ReminderActionService.ignore(
            reminder,
            until: ignoredUntil,
            updateFutureNotifications: false,
            calendar: calendar
        )

        XCTAssertEqual(ignored.dueAt, dueAt)
        XCTAssertEqual(ignored.ignoredUntil, ignoredUntil)
        XCTAssertEqual(ignored.displayDueAt(now: dueAt), ignoredUntil)
    }

    func testRecurringIgnoreWithFutureUpdateMovesScheduleDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dueAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8)))
        let ignoredUntil = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))
        let reminder = Reminder(
            title: "Medicine",
            mode: .pureReminder,
            eventType: .medicine,
            dueAt: dueAt,
            dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil)
        )

        let ignored = ReminderActionService.ignore(
            reminder,
            until: ignoredUntil,
            updateFutureNotifications: true,
            calendar: calendar
        )

        XCTAssertEqual(ignored.dueAt, ignoredUntil)
        XCTAssertNil(ignored.ignoredUntil)
    }
}
