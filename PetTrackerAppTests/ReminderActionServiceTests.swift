import XCTest
@testable import PetTrackerApp

final class ReminderActionServiceTests: XCTestCase {
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
}
