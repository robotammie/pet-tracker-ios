import Foundation

enum ReminderRepeatStyle: String, CaseIterable, Identifiable {
    case none = "Does not repeat", every = "Every interval", timesPerDay = "Times per day"
    var id: String { rawValue }
}

struct ReminderPayloadDraft: Identifiable {
    let id: UUID
    var petID: UUID?
    var event: CareEventEditDraft
    init(type: CareEventType, petID: UUID?, data: CareEventData) {
        id = petID ?? UUID()
        self.petID = petID
        event = CareEventEditDraft(event: CareEvent(type: type, petID: petID, data: data))
    }
}

struct ReminderEditorRoute: Identifiable {
    let id = UUID()
    var reminder: Reminder?
}

struct ReminderEditDraft {
    let original: Reminder?
    let id: UUID
    var title: String
    var mode: ReminderMode
    var dueAt: Date
    var dueStyle: ReminderDueStyle
    var repeatStyle = ReminderRepeatStyle.none
    var interval = 1
    var recurrenceUnit = RecurrenceUnit.day
    var dailyTimes: [Date] = []
    var hasEndDate: Bool
    var endDate: Date
    var eventType: CareEventType
    var selectedOptionID: UUID?
    var selectedPetIDs: Set<UUID>
    var isHousehold: Bool
    var payloads: [ReminderPayloadDraft] = []
    private var template: CareEventData?
    private var templateMedicine: SavedMedicineData?

    var hasCompletedTargets: Bool { original?.targets.contains { $0.completedAt != nil } ?? false }

    init(reminder: Reminder? = nil, now: Date = .now, calendar: Calendar = .current) {
        original = reminder
        id = reminder?.id ?? UUID()
        title = reminder?.title ?? ""
        mode = reminder?.mode ?? .pureReminder
        dueAt = reminder?.dueAt ?? now
        dueStyle = reminder?.dueStyle ?? .timestamp
        eventType = reminder?.eventType ?? .food
        selectedPetIDs = Set(reminder?.targets.map(\.petID) ?? [])
        isHousehold = selectedPetIDs.isEmpty
        hasEndDate = reminder?.schedule?.endDate != nil
        endDate = reminder?.schedule?.endDate ?? calendar.date(byAdding: .month, value: 1, to: now) ?? now
        template = reminder?.eventData ?? reminder?.targets.first?.eventData
        switch reminder?.schedule?.recurrenceRule {
        case let .every(value, unit): repeatStyle = .every; interval = value; recurrenceUnit = unit
        case let .timesPerDay(_, times):
            repeatStyle = .timesPerDay
            dailyTimes = times.compactMap { calendar.date(bySettingHour: $0.hour ?? 9, minute: $0.minute ?? 0, second: 0, of: now) }
        case nil: break
        }
        if dailyTimes.isEmpty { setDailyCount(1, now: now, calendar: calendar) }
        if let reminder {
            if reminder.targets.isEmpty, let data = reminder.eventData {
                payloads = [ReminderPayloadDraft(type: eventType, petID: nil, data: data)]
            } else {
                payloads = reminder.targets.compactMap { target in
                    (target.eventData ?? reminder.eventData).map { ReminderPayloadDraft(type: eventType, petID: target.petID, data: $0) }
                }
            }
        }
    }

    mutating func setDailyCount(_ count: Int, now: Date = .now, calendar: Calendar = .current) {
        dailyTimes = (0..<max(1, min(12, count))).compactMap { index in
            calendar.date(bySettingHour: (9 + index * 24 / max(1, count)) % 24, minute: 0, second: 0, of: now)
        }.sorted()
    }

    mutating func changeEventType() {
        selectedOptionID = nil
        templateMedicine = nil
        if eventType == .medicine { isHousehold = false }
        template = eventType == .litter ? .litter(LitterEventData()) : nil
        payloads = []
        if eventType == .litter { selectedPetIDs = []; isHousehold = true }
        reconcilePayloads()
    }

    mutating func selectOption(_ option: SavedEventOption?) {
        selectedOptionID = option?.id
        guard let option else {
            templateMedicine = nil
            if let original, original.eventType == eventType {
                template = original.eventData ?? original.targets.first?.eventData
                payloads = ReminderEditDraft(reminder: original).payloads
                reconcilePayloads()
            } else {
                template = nil
                payloads = []
            }
            return
        }
        guard option.eventType == eventType else { return }
        switch option.data {
        case let .food(food):
            template = .food(FoodEventData(name: food.name, foodType: food.foodType, amount: 1, unit: food.unit, calories: food.caloriesPerUnit, caloriesPerUnit: food.caloriesPerUnit))
        case let .medicine(medicine):
            templateMedicine = medicine
            template = .medicine(MedicineEventData(name: medicine.name, dosage: medicine.dosage, unit: medicine.unit, savedOptionID: option.id, doseInterval: medicine.doseInterval))
        }
        payloads = []
        reconcilePayloads()
        if case let .medicine(medicine) = option.data {
            for index in payloads.indices {
                let petID = payloads[index].petID
                var event = payloads[index].event.original
                if case var .medicine(data) = event.data {
                    data.doseInterval = petID.flatMap { medicine.doseInterval(for: $0) } ?? medicine.doseInterval
                    event.data = .medicine(data)
                    payloads[index].event = CareEventEditDraft(event: event)
                }
            }
        }
    }

    mutating func reconcilePayloads() {
        let ids: [UUID?] = eventType == .litter || isHousehold ? [nil] : selectedPetIDs.sorted { $0.uuidString < $1.uuidString }.map(Optional.some)
        payloads = ids.compactMap { petID in
            if let old = payloads.first(where: { $0.petID == petID }) { return old }
            let data = template ?? (eventType == .litter ? .litter(LitterEventData()) : nil)
            return data.map { data in
                var adjusted = data
                if case var .medicine(medicine) = adjusted, let petID, let templateMedicine {
                    medicine.doseInterval = templateMedicine.doseInterval(for: petID)
                    adjusted = .medicine(medicine)
                }
                return ReminderPayloadDraft(type: eventType, petID: petID, data: adjusted)
            }
        }
    }

    func makeReminder(pets: [Pet], calendar: Calendar = .current) -> Reminder? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              dueAt.timeIntervalSinceReferenceDate.isFinite,
              selectedPetIDs.isSubset(of: Set(pets.map(\.id))),
              original == nil || original?.isActive == true else { return nil }
        if hasEndDate, !endDate.timeIntervalSinceReferenceDate.isFinite || endDate < dueAt { return nil }
        let rule: RecurrenceRule?
        switch repeatStyle {
        case .none: rule = nil
        case .every:
            guard interval > 0, !(dueStyle == .dayOnly && recurrenceUnit == .hour) else { return nil }
            rule = .every(value: interval, unit: recurrenceUnit)
        case .timesPerDay:
            guard dueStyle == .timestamp, !dailyTimes.isEmpty, dailyTimes.count <= 12 else { return nil }
            let times = dailyTimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
            guard Set(times.map { ($0.hour ?? 0) * 60 + ($0.minute ?? 0) }).count == times.count else { return nil }
            rule = .timesPerDay(count: times.count, times: times.sorted { ($0.hour ?? 0) * 60 + ($0.minute ?? 0) < ($1.hour ?? 0) * 60 + ($1.minute ?? 0) })
        }
        if hasCompletedTargets {
            guard mode == original?.mode, (mode == .pureReminder || eventType == original?.eventType),
                  selectedPetIDs == Set(original?.targets.map(\.petID) ?? []) else { return nil }
        }
        var result = original ?? Reminder(id: id, title: title, mode: mode, eventType: nil, dueAt: dueAt, dueStyle: dueStyle)
        result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result.mode = mode
        result.dueAt = dueAt
        result.dueStyle = dueStyle
        result.schedule = rule == nil && !hasEndDate ? nil : ReminderSchedule(recurrenceRule: rule, endDate: hasEndDate ? endDate : nil)
        if dueAt != original?.dueAt { result.ignoredUntil = nil }
        if mode == .pureReminder {
            result.eventType = original?.eventType
            result.eventPetID = nil
            result.eventData = nil
            result.targets = selectedPetIDs.sorted { $0.uuidString < $1.uuidString }.map { petID in
                let old = original?.targets.first { $0.petID == petID }
                if let old, old.completedAt != nil { return old }
                return ReminderTarget(petID: petID, completedAt: old?.completedAt)
            }
        } else {
            if eventType == .medicine, isHousehold || selectedPetIDs.isEmpty { return nil }
            if eventType == .food, !isHousehold && selectedPetIDs.isEmpty { return nil }
            let expected = eventType == .litter || isHousehold ? 1 : selectedPetIDs.count
            guard payloads.count == expected else { return nil }
            var targets: [ReminderTarget] = []
            var householdData: CareEventData?
            for payload in payloads {
                let old = original?.targets.first { $0.petID == payload.petID }
                if let old, old.completedAt != nil { targets.append(old); continue }
                guard payload.event.original.type == eventType,
                      let event = payload.event.makeEvent(pets: pets) else { return nil }
                if case let .food(food) = event.data, food.amount <= 0 { return nil }
                if let petID = payload.petID {
                    targets.append(ReminderTarget(petID: petID, eventData: event.data))
                } else { householdData = event.data }
            }
            result.eventType = eventType
            result.eventPetID = nil
            result.eventData = householdData
            result.targets = targets
        }
        return result
    }
}
