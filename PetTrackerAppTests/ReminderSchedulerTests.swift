import XCTest
@testable import PetTrackerApp

final class ReminderSchedulerTests: XCTestCase {
    func testEveryNHoursUsesCompletionTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let completion = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 1,
            hour: 10,
            minute: 30
        )))
        let schedule = ReminderSchedule(
            recurrenceRule: .every(value: 8, unit: .hour),
            endDate: nil
        )

        let next = ReminderScheduler.nextDueDate(
            after: completion,
            schedule: schedule,
            calendar: calendar
        )

        XCTAssertEqual(next, calendar.date(byAdding: .hour, value: 8, to: completion))
    }

    func testTimesPerDayChoosesNextEditableDefaultTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let completion = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 1,
            hour: 10,
            minute: 30
        )))
        let schedule = ReminderSchedule(
            recurrenceRule: .timesPerDay(
                count: 2,
                times: [
                    DateComponents(hour: 9),
                    DateComponents(hour: 21)
                ]
            ),
            endDate: nil
        )

        let next = ReminderScheduler.nextDueDate(
            after: completion,
            schedule: schedule,
            calendar: calendar
        )

        XCTAssertEqual(next, calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 1,
            hour: 21
        )))
    }

    func testEndDateStopsFutureReminder() throws {
        let calendar = Calendar(identifier: .gregorian)
        let completion = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 1,
            hour: 10
        )))
        let endDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: 1,
            hour: 12
        )))
        let schedule = ReminderSchedule(
            recurrenceRule: .every(value: 8, unit: .hour),
            endDate: endDate
        )

        let next = ReminderScheduler.nextDueDate(
            after: completion,
            schedule: schedule,
            calendar: calendar
        )

        XCTAssertNil(next)
    }
}
