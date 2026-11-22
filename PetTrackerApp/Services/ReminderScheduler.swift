import Foundation

enum ReminderScheduler {
    static func nextDueDate(
        after completionTime: Date,
        schedule: ReminderSchedule,
        calendar: Calendar = .current
    ) -> Date? {
        guard let rule = schedule.recurrenceRule else {
            return nil
        }

        let nextDate: Date?

        switch rule {
        case let .every(value, unit):
            nextDate = nextRepeatingDate(
                after: completionTime,
                value: value,
                unit: unit,
                calendar: calendar
            )

        case let .timesPerDay(_, times):
            nextDate = nextTimesPerDayDate(
                after: completionTime,
                times: times,
                calendar: calendar
            )
        }

        guard let nextDate else {
            return nil
        }

        if let endDate = schedule.endDate, nextDate > endDate {
            return nil
        }

        return nextDate
    }

    private static func nextRepeatingDate(
        after date: Date,
        value: Int,
        unit: RecurrenceUnit,
        calendar: Calendar
    ) -> Date? {
        let safeValue = max(1, value)

        switch unit {
        case .hour:
            return calendar.date(byAdding: .hour, value: safeValue, to: date)
        case .day:
            return calendar.date(byAdding: .day, value: safeValue, to: date)
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: safeValue, to: date)
        case .month:
            return calendar.date(byAdding: .month, value: safeValue, to: date)
        }
    }

    private static func nextTimesPerDayDate(
        after date: Date,
        times: [DateComponents],
        calendar: Calendar
    ) -> Date? {
        let normalizedTimes = times
            .compactMap { time -> DateComponents? in
                guard let hour = time.hour else {
                    return nil
                }

                return DateComponents(hour: hour, minute: time.minute ?? 0)
            }
            .sorted {
                ($0.hour ?? 0, $0.minute ?? 0) < ($1.hour ?? 0, $1.minute ?? 0)
            }

        guard !normalizedTimes.isEmpty else {
            return nil
        }

        let startOfDay = calendar.startOfDay(for: date)

        for time in normalizedTimes {
            guard let candidate = calendar.date(
                bySettingHour: time.hour ?? 0,
                minute: time.minute ?? 0,
                second: 0,
                of: startOfDay
            ) else {
                continue
            }

            if candidate > date {
                return candidate
            }
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay),
              let firstTime = normalizedTimes.first
        else {
            return nil
        }

        return calendar.date(
            bySettingHour: firstTime.hour ?? 0,
            minute: firstTime.minute ?? 0,
            second: 0,
            of: tomorrow
        )
    }
}

struct ScheduledEventMaterialization {
    var updatedSchedule: ScheduledEvent
    var events: [CareEvent]
}

enum ScheduledEventService {
    static func materialize(
        _ scheduledEvent: ScheduledEvent,
        through now: Date,
        limit: Int = 100,
        calendar: Calendar? = nil
    ) -> ScheduledEventMaterialization {
        var updated = scheduledEvent
        let calendar = calendar ?? scheduledEvent.calendar
        var events: [CareEvent] = []
        let safeLimit = max(1, limit)

        while let dueAt = updated.nextDueAt, dueAt <= now, events.count < safeLimit {
            events.append(CareEvent(
                id: SyncIdentity.scheduledEvent(scheduleID: updated.id, scheduledAt: dueAt),
                type: .food,
                petID: updated.petID,
                createdAt: now,
                startTime: dueAt,
                data: .food(updated.food)
            ))

            if let schedule = updated.schedule,
               let nextDue = ReminderScheduler.nextDueDate(
                after: dueAt,
                schedule: schedule,
                calendar: calendar
               ) {
                updated.nextDueAt = nextDue
            } else {
                updated.nextDueAt = nil
            }
        }

        if !events.isEmpty { updated.updatedAt = now }
        return ScheduledEventMaterialization(updatedSchedule: updated, events: events)
    }
}
