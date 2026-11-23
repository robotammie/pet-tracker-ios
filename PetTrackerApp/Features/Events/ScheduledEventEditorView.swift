import SwiftUI

struct ScheduledEventSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let scheduledEvent: ScheduledEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: scheduledEvent.type.homeSystemImage)
                .foregroundStyle(.secondary)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 24)
            VStack(alignment: .leading, spacing: 4) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                layout {
                    Text(scheduledEvent.title).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    if let nextDueAt = scheduledEvent.nextDueAt {
                        RelativeTimeText(date: nextDueAt)
                    } else {
                        Text("Ended")
                    }
                }
                .font(.caption)
                if let food = scheduledEvent.food {
                    Text("\(food.name) · \(food.amount.formatted()) \(food.unit.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                } else { Text("Household litter cleaning").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct ScheduledEventEditorRoute: Identifiable {
    let id = UUID()
    var scheduledEvent: ScheduledEvent?
}

struct ScheduledEventEditDraft {
    let original: ScheduledEvent?
    let id: UUID
    var title: String
    var eventType: CareEventType
    var petID: UUID?
    var nextDueAt: Date
    var repeatStyle = ReminderRepeatStyle.none
    var interval = 1
    var recurrenceUnit = RecurrenceUnit.day
    var dailyTimes: [Date] = []
    var hasEndDate: Bool
    var endDate: Date
    var selectedOptionID: UUID?
    var food: FoodEventData?

    init(scheduledEvent: ScheduledEvent? = nil, now: Date = .now, calendar: Calendar = .current) {
        original = scheduledEvent
        id = scheduledEvent?.id ?? UUID()
        title = scheduledEvent?.title ?? ""
        eventType = scheduledEvent?.type ?? .food
        petID = scheduledEvent?.petID
        nextDueAt = scheduledEvent?.nextDueAt ?? now
        hasEndDate = scheduledEvent?.schedule?.endDate != nil
        endDate = scheduledEvent?.schedule?.endDate
            ?? calendar.date(byAdding: .month, value: 1, to: now) ?? now
        food = scheduledEvent?.food
        switch scheduledEvent?.schedule?.recurrenceRule {
        case let .every(value, unit):
            repeatStyle = .every
            interval = value
            recurrenceUnit = unit
        case let .timesPerDay(_, times):
            repeatStyle = .timesPerDay
            dailyTimes = times.compactMap {
                calendar.date(
                    bySettingHour: $0.hour ?? 9,
                    minute: $0.minute ?? 0,
                    second: 0,
                    of: now
                )
            }
        case nil:
            break
        }
        if dailyTimes.isEmpty { setDailyCount(1, now: now, calendar: calendar) }
    }

    mutating func selectOption(_ option: SavedEventOption?) {
        selectedOptionID = option?.id
        guard let option, case let .food(savedFood) = option.data else {
            food = original?.food
            return
        }
        food = FoodEventData(
            name: savedFood.name,
            foodType: savedFood.foodType,
            amount: food?.amount ?? 1,
            unit: savedFood.unit,
            calories: 0,
            caloriesPerUnit: savedFood.caloriesPerUnit
        )
        recalculateCalories()
    }

    mutating func recalculateCalories() {
        guard var food, let rate = food.caloriesPerUnit else { return }
        food.calories = Int((food.amount * Double(rate)).rounded())
        self.food = food
    }

    mutating func setDailyCount(_ count: Int, now: Date = .now, calendar: Calendar = .current) {
        dailyTimes = (0..<max(1, min(12, count))).compactMap { index in
            calendar.date(
                bySettingHour: (9 + index * 24 / max(1, count)) % 24,
                minute: 0,
                second: 0,
                of: now
            )
        }.sorted()
    }

    func makeScheduledEvent(pets: [Pet], id overrideID: UUID? = nil, now: Date = .now, calendar: Calendar = .current) -> ScheduledEvent? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              nextDueAt.timeIntervalSinceReferenceDate.isFinite,
              petID == nil || pets.contains(where: { $0.id == petID }) else { return nil }
        if eventType == .food {
            guard let food, !food.name.isEmpty, food.amount.isFinite, food.amount > 0, food.calories >= 0 else { return nil }
        } else if eventType != .litter || petID != nil { return nil }
        if hasEndDate, !endDate.timeIntervalSinceReferenceDate.isFinite || endDate < nextDueAt {
            return nil
        }

        let rule: RecurrenceRule?
        switch repeatStyle {
        case .none:
            rule = nil
        case .every:
            guard interval > 0 else { return nil }
            rule = .every(value: interval, unit: recurrenceUnit)
        case .timesPerDay:
            let times = dailyTimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
            guard !times.isEmpty,
                  Set(times.map { ($0.hour ?? 0) * 60 + ($0.minute ?? 0) }).count == times.count
            else { return nil }
            rule = .timesPerDay(
                count: times.count,
                times: times.sorted {
                    ($0.hour ?? 0) * 60 + ($0.minute ?? 0)
                        < ($1.hour ?? 0) * 60 + ($1.minute ?? 0)
                }
            )
        }

        return ScheduledEvent(
            id: overrideID ?? id,
            title: title,
            petID: petID,
            food: food,
            eventType: eventType == .food ? nil : eventType,
            nextDueAt: nextDueAt,
            schedule: rule == nil && !hasEndDate
                ? nil
                : ReminderSchedule(recurrenceRule: rule, endDate: hasEndDate ? endDate : nil),
            calendar: original?.calendar ?? calendar,
            createdAt: original?.createdAt ?? now,
            updatedAt: now
        )
    }
}

struct ScheduledEventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @State private var draft: ScheduledEventEditDraft
    @State private var saveError = false

    init(scheduledEvent: ScheduledEvent? = nil) {
        _draft = State(initialValue: ScheduledEventEditDraft(scheduledEvent: scheduledEvent))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scheduled Event") {
                    TextField("Title", text: $draft.title)
                        .accessibilityIdentifier("scheduledEventEditor.title")
                    DatePicker("Next event", selection: $draft.nextDueAt)
                        .accessibilityIdentifier("scheduledEventEditor.nextDue")
                    Text("The event is recorded with this scheduled time when the app next runs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ScheduledEventRepeatFields(draft: $draft)

                if draft.eventType == .food {
                    Section("Food") {
                        Picker("Saved food", selection: $draft.selectedOptionID) {
                            Text(draft.original == nil ? "Choose food" : "Keep recorded details")
                                .tag(Optional<UUID>.none)
                            ForEach(store.activeSavedOptions(for: .food)) { option in
                                if case let .food(food) = option.data {
                                    Text(food.name).tag(Optional(option.id))
                                }
                            }
                        }
                        .onChange(of: draft.selectedOptionID) { _, id in
                            draft.selectOption(store.savedOptions.first { $0.id == id })
                        }
                        .accessibilityIdentifier("scheduledEventEditor.food")

                        Picker("For", selection: $draft.petID) {
                            Text("Household").tag(Optional<UUID>.none)
                            ForEach(store.pets) { pet in
                                Text(pet.name).tag(Optional(pet.id))
                            }
                        }
                        .accessibilityIdentifier("scheduledEventEditor.pet")

                        if let food = draft.food {
                            Text(food.name)
                            TextField("Amount", value: Binding(
                                get: { draft.food?.amount ?? 0 },
                                set: { draft.food?.amount = $0; draft.recalculateCalories() }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("scheduledEventEditor.amount")
                            Text("\(food.unit.rawValue) · \(draft.food?.calories ?? 0) calories")
                                .foregroundStyle(.secondary)
                        }
                    }

                } else {
                    Section { Label("Household litter cleaning", systemImage: "tray") }
                }
                if draft.hasEndDate && draft.endDate < draft.nextDueAt {
                    Text("End date must be on or after the next event time.")
                        .foregroundStyle(.secondary)
                }
            }
            .persistenceErrorBanner()
            .navigationTitle(draft.original == nil ? "Add Scheduled Event" : "Edit Scheduled Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("scheduledEventEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = draft.makeScheduledEvent(pets: store.pets) else { return }
                        if let original = draft.original,
                           store.scheduledEvents.first(where: { $0.id == original.id }) != original {
                            saveError = true
                        } else if store.saveScheduledEventAndRefresh(value) {
                            store.materializeScheduledEvents()
                            dismiss()
                        }
                    }
                    .disabled(draft.makeScheduledEvent(pets: store.pets) == nil)
                    .accessibilityIdentifier("scheduledEventEditor.save")
                }
            }
            .alert("Scheduled event changed", isPresented: $saveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This schedule was updated while editing. Cancel and reopen it to use its current state.")
            }
        }
    }

}

struct ScheduledEventRepeatFields: View {
    @Binding var draft: ScheduledEventEditDraft
    var body: some View {

        Section("Schedule") {
            Picker("Repeat", selection: $draft.repeatStyle) {
                ForEach(ReminderRepeatStyle.allCases.filter { $0 != .none || draft.repeatStyle == .none }) { Text($0.rawValue).tag($0) }
            }
            .accessibilityIdentifier("scheduledEventEditor.repeat")
            if draft.repeatStyle == .every {
                Stepper("Every \(draft.interval)", value: $draft.interval, in: 1...365)
                Picker("Interval unit", selection: $draft.recurrenceUnit) {
                    ForEach(RecurrenceUnit.allCases) { Text($0.rawValue).tag($0) }
                }
            } else if draft.repeatStyle == .timesPerDay {
                Stepper("\(draft.dailyTimes.count) times per day", value: Binding(
                    get: { draft.dailyTimes.count },
                    set: { draft.setDailyCount($0) }
                ), in: 1...12)
                ForEach(draft.dailyTimes.indices, id: \.self) { index in
                    DatePicker(
                        "Time \(index + 1)",
                        selection: $draft.dailyTimes[index],
                        displayedComponents: [.hourAndMinute]
                    )
                }
            }
            Toggle("End date", isOn: $draft.hasEndDate)
            if draft.hasEndDate {
                DatePicker("Ends", selection: $draft.endDate)
            }
        }
    }
}


struct RecurringEventFields: View {
    @Binding var isRecurring: Bool
    @Binding var draft: ScheduledEventEditDraft
    var body: some View {
        Section {
            Toggle("Recurring", isOn: $isRecurring)
                .accessibilityIdentifier("eventCreation.recurring")
                .onChange(of: isRecurring) { _, enabled in
                    if enabled && draft.repeatStyle == .none { draft.repeatStyle = .every }
                }
        }
        if isRecurring {
            ScheduledEventRepeatFields(draft: $draft)
            Text("Due events are logged automatically when the app next runs, using their scheduled time.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

extension ScheduledEventEditDraft {
    func schedules(for events: [CareEvent], pets: [Pet]) -> [ScheduledEvent] {
        let values = events.compactMap { event -> ScheduledEvent? in
            var draft = self
            draft.nextDueAt = event.startTime
            draft.petID = event.petID
            draft.eventType = event.type
            switch event.data {
            case let .food(food): draft.food = food; draft.title = food.name
            case .litter: draft.food = nil; draft.title = "Litter cleaning"
            case .medicine: return nil
            }
            let stableID = SyncIdentity.uuid("schedule-draft/\(id)/\(event.petID?.uuidString ?? "household")/\(event.type.rawValue)")
            return draft.makeScheduledEvent(pets: pets, id: stableID)
        }
        return values.count == events.count ? values : []
    }
}
