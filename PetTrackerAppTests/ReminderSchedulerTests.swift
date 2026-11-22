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

    func testDayOnlyReminderIsOverdueAfterDueDayEnds() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dueDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))
        let sameDayEvening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 23)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2)))
        let reminder = Reminder(
            title: "Clean fountain",
            mode: .pureReminder,
            eventType: nil,
            dueAt: dueDay,
            dueStyle: .dayOnly
        )

        XCTAssertFalse(reminder.isOverdue(now: sameDayEvening, calendar: calendar))
        XCTAssertTrue(reminder.isOverdue(now: nextDay, calendar: calendar))
    }

    func testScheduledFoodCatchesUpWithStableIDsAndAdvancesFromScheduledTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: 2026, month: 9, day: 15, hour: 8
        )))
        let scheduled = ScheduledEvent(
            title: "Auto feeder",
            petID: nil,
            food: FoodEventData(
                name: "Kibble", foodType: .dry, amount: 0.25,
                unit: .cup, calories: 95, caloriesPerUnit: 380
            ),
            nextDueAt: first,
            schedule: ReminderSchedule(
                recurrenceRule: .every(value: 8, unit: .hour), endDate: nil
            ),
            calendar: calendar
        )
        let through = try XCTUnwrap(calendar.date(byAdding: .hour, value: 17, to: first))

        let result = ScheduledEventService.materialize(scheduled, through: through)

        XCTAssertEqual(result.events.map(\.startTime), [
            first,
            calendar.date(byAdding: .hour, value: 8, to: first),
            calendar.date(byAdding: .hour, value: 16, to: first)
        ])
        XCTAssertEqual(Set(result.events.map(\.id)).count, 3)
        XCTAssertEqual(result.events[0].id, SyncIdentity.scheduledEvent(scheduleID: scheduled.id, scheduledAt: first))
        XCTAssertEqual(result.updatedSchedule.nextDueAt, calendar.date(byAdding: .hour, value: 24, to: first))
        XCTAssertTrue(result.events.allSatisfy { $0.type == .food && $0.petID == nil })
    }

    func testScheduledFoodBatchIsBoundedAndResumable() {
        let first = Date(timeIntervalSince1970: 1_000)
        let scheduled = ScheduledEvent(
            title: "Auto feeder",
            petID: nil,
            food: FoodEventData(name: "Kibble", foodType: .dry, amount: 1, unit: .cup, calories: 100),
            nextDueAt: first,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .hour), endDate: nil)
        )

        let firstBatch = ScheduledEventService.materialize(
            scheduled, through: first.addingTimeInterval(10 * 3_600), limit: 3
        )
        let secondBatch = ScheduledEventService.materialize(
            firstBatch.updatedSchedule, through: first.addingTimeInterval(10 * 3_600), limit: 3
        )

        XCTAssertEqual(firstBatch.events.count, 3)
        XCTAssertEqual(secondBatch.events.count, 3)
        XCTAssertTrue(Set(firstBatch.events.map(\.id)).isDisjoint(with: secondBatch.events.map(\.id)))
    }
}
