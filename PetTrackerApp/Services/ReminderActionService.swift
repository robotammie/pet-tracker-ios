import Foundation

struct ReminderCompletionResult {
    var updatedReminder: Reminder
    var historyReminder: Reminder?
    var events: [CareEvent]
}

enum ReminderActionService {
    static func complete(
        _ reminder: Reminder,
        completedPetIDs: Set<UUID>,
        completionTime: Date,
        createsEvent: Bool,
        calendar: Calendar = .current
    ) -> ReminderCompletionResult {
        var updated = reminder
        var events: [CareEvent] = []

        if let actions = reminder.eventActions {
            let newlyCompleted = Set(reminder.incompleteTargets.filter { completedPetIDs.contains($0.petID) }.map(\.petID))
            // Household entries belong to the first completion of this occurrence.
            let includeHousehold = reminder.targets.isEmpty ||
                (!newlyCompleted.isEmpty && reminder.targets.allSatisfy { $0.completedAt == nil })
            if createsEvent {
                events = actions.filter { action in
                    action.petID.map { newlyCompleted.contains($0) } ?? includeHousehold
                }.map { action in
                    CareEvent(id: SyncIdentity.event(reminder, actionID: action.id), type: action.type,
                        petID: action.petID, createdAt: completionTime, startTime: completionTime, data: action.data)
                }
            }
            updated.targets = reminder.targets.map { target in
                var target = target
                if newlyCompleted.contains(target.petID) { target.completedAt = completionTime }
                return target
            }
            if !updated.incompleteTargets.isEmpty {
                return ReminderCompletionResult(updatedReminder: updated, historyReminder: nil, events: events)
            }
            return finish(updated, completionTime: completionTime, events: events, calendar: calendar)
        }

        if updated.targets.isEmpty {
            if createsEvent, let event = event(from: updated, petID: updated.eventPetID, completionTime: completionTime) {
                events.append(event)
            }

            return finish(updated, completionTime: completionTime, events: events, calendar: calendar)
        }

        updated.targets = updated.targets.map { target in
            guard completedPetIDs.contains(target.petID), target.completedAt == nil else {
                return target
            }

            var completed = target
            completed.completedAt = completionTime

            if createsEvent, let event = event(from: updated, target: completed, completionTime: completionTime) {
                events.append(event)
            }

            return completed
        }

        guard updated.incompleteTargets.isEmpty else {
            return ReminderCompletionResult(updatedReminder: updated, historyReminder: nil, events: events)
        }

        return finish(updated, completionTime: completionTime, events: events, calendar: calendar)
    }

    static func ignore(
        _ reminder: Reminder,
        until ignoreUntil: Date,
        updateFutureNotifications: Bool,
        calendar: Calendar = .current
    ) -> Reminder {
        var updated = reminder

        if updateFutureNotifications || !reminder.isRecurring {
            updated.dueAt = ignoreUntil
            updated.ignoredUntil = nil
            updated.targets = updated.targets.map { target in
                ReminderTarget(petID: target.petID, eventData: target.eventData, completedAt: nil)
            }
        } else {
            updated.ignoredUntil = ignoreUntil
        }

        return updated
    }

    private static func finish(
        _ reminder: Reminder,
        completionTime: Date,
        events: [CareEvent],
        calendar: Calendar
    ) -> ReminderCompletionResult {
        var completed = reminder
        completed.status = .completed
        completed.completedAt = completionTime
        completed.ignoredUntil = nil

        guard let schedule = reminder.schedule,
              let nextDue = ReminderScheduler.nextDueDate(
                after: completionTime,
                schedule: schedule,
                calendar: calendar
              )
        else {
            return ReminderCompletionResult(updatedReminder: completed, historyReminder: nil, events: events)
        }

        var next = reminder
        next.dueAt = nextDue
        next.status = .active
        next.completedAt = nil
        next.ignoredUntil = nil
        next.targets = reminder.targets.map { target in
            ReminderTarget(petID: target.petID, eventData: target.eventData, completedAt: nil)
        }

        var history = completed
        history = Reminder(
            id: SyncIdentity.history(reminder),
            title: history.title,
            mode: history.mode,
            eventType: history.eventType,
            eventPetID: history.eventPetID,
            eventData: history.eventData,
            dueAt: history.dueAt,
            dueStyle: history.dueStyle,
            status: .completed,
            schedule: nil,
            targets: history.targets,
            completedAt: completionTime,
            ignoredUntil: nil,
            eventActions: reminder.eventActions
        )

        return ReminderCompletionResult(updatedReminder: next, historyReminder: history, events: events)
    }

    private static func event(
        from reminder: Reminder,
        target: ReminderTarget,
        completionTime: Date
    ) -> CareEvent? {
        event(
            from: reminder,
            petID: target.petID,
            eventData: target.eventData ?? reminder.eventData,
            completionTime: completionTime
        )
    }

    private static func event(
        from reminder: Reminder,
        petID: UUID?,
        completionTime: Date
    ) -> CareEvent? {
        event(from: reminder, petID: petID, eventData: reminder.eventData, completionTime: completionTime)
    }

    private static func event(
        from reminder: Reminder,
        petID: UUID?,
        eventData: CareEventData?,
        completionTime: Date
    ) -> CareEvent? {
        guard let eventType = reminder.eventType,
              let eventData
        else {
            return nil
        }

        return CareEvent(
            id: SyncIdentity.event(reminder, petID: petID),
            type: eventType,
            petID: petID,
            createdAt: completionTime,
            startTime: completionTime,
            data: eventData
        )
    }
}
