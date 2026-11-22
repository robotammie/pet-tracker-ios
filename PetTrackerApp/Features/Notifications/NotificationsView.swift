import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var completionDraft: ReminderCompletionDraft?
    @State private var ignoreDraft: ReminderIgnoreDraft?
    @State private var isCompletedExpanded = false
    @State private var editorRoute: ReminderEditorRoute?
    @State private var deletingReminder: Reminder?
    @State private var scheduledEventRoute: ScheduledEventEditorRoute?
    @State private var deletingScheduledEvent: ScheduledEvent?

    var body: some View {
        List {
            Section("Active") {
                if activeReminders.isEmpty {
                    ContentUnavailableView("No active reminders", systemImage: "bell.slash")
                } else {
                    ForEach(activeReminders) { reminder in
                        ReminderSummaryRow(
                            reminder: reminder,
                            rowAccessibilityIdentifier: "reminder.active.\(reminder.id.uuidString)",
                            onSelect: { editorRoute = ReminderEditorRoute(reminder: reminder) },
                            onCompleteNow: { store.completeReminderNowAndRefresh(id: reminder.id) }
                        )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Edit") { editorRoute = ReminderEditorRoute(reminder: reminder) }
                                    .tint(.blue).accessibilityIdentifier("reminder.edit")
                                Button("Done") {
                                    startCompletion(reminder)
                                }
                                .accessibilityIdentifier("reminder.complete")
                                .tint(.green)

                                Button("Ignore") {
                                    ignoreDraft = ReminderIgnoreDraft(reminder: reminder)
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Mute") {
                                    store.muteReminderAndRefresh(id: reminder.id)
                                }
                                .tint(.gray)

                                Button("Delete", role: .destructive) {
                                    deletingReminder = reminder
                                }
                                .accessibilityIdentifier("reminder.delete")
                            }
                    }
                }
            }

            Section {
                DisclosureGroup(isExpanded: $isCompletedExpanded) {
                    if completedReminders.isEmpty {
                        Text("No completed reminders")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(completedReminders) { reminder in
                            ReminderSummaryRow(reminder: reminder)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("reminder.completed.\(reminder.id.uuidString)")
                        }
                    }
                } label: {
                    Text("Completed")
                }
            }

            Section("Scheduled Events") {
                if scheduledEvents.isEmpty {
                    ContentUnavailableView(
                        "No scheduled events",
                        systemImage: "calendar.badge.clock"
                    )
                } else {
                    ForEach(scheduledEvents) { scheduledEvent in
                        Button {
                            scheduledEventRoute = ScheduledEventEditorRoute(scheduledEvent: scheduledEvent)
                        } label: {
                            ScheduledEventSummaryRow(scheduledEvent: scheduledEvent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("scheduledEvent.row.\(scheduledEvent.id.uuidString)")
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                deletingScheduledEvent = scheduledEvent
                            }
                            .accessibilityIdentifier("scheduledEvent.delete")
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editorRoute = ReminderEditorRoute() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add reminder")
                    .accessibilityIdentifier("reminders.add")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { scheduledEventRoute = ScheduledEventEditorRoute() } label: {
                    Image(systemName: "calendar.badge.clock")
                }
                .accessibilityLabel("Add scheduled food event")
                .accessibilityIdentifier("scheduledEvents.add")
            }
        }
        .sheet(item: $editorRoute) { route in ReminderEditorView(reminder: route.reminder) }
        .sheet(item: $scheduledEventRoute) { route in
            ScheduledEventEditorView(scheduledEvent: route.scheduledEvent)
                .environmentObject(store)
        }
        .sheet(item: $completionDraft) { draft in
            ReminderCompletionSheet(draft: draft)
                .environmentObject(store)
        }
        .sheet(item: $ignoreDraft) { draft in
            ReminderIgnoreSheet(draft: draft)
                .environmentObject(store)
        }
        .alert("Delete reminder?", isPresented: Binding(
            get: { deletingReminder != nil },
            set: { if !$0 { deletingReminder = nil } }
        ), presenting: deletingReminder) { reminder in
            if reminder.isRecurring {
                Button("Delete This Occurrence", role: .destructive) {
                    store.deleteReminderOccurrenceAndRefresh(reminder)
                }
                .accessibilityIdentifier("reminder.deleteOccurrence")
                Button("Delete All", role: .destructive) {
                    store.deleteReminderSeriesAndRefresh(reminder)
                }
                .accessibilityIdentifier("reminder.deleteAll")
            } else {
                Button("Delete Reminder", role: .destructive) {
                    store.deleteReminderAndRefresh(id: reminder.id)
                }
                .accessibilityIdentifier("reminder.confirmDelete")
            }
            Button("Cancel", role: .cancel) { }
        } message: { reminder in
            if reminder.isRecurring {
                Text("Delete this occurrence and keep the series, or delete the series and all of its completed reminder history. Logged care events are kept.")
            } else {
                Text("This removes the reminder. Logged care events are kept.")
            }
        }
        .alert("Delete scheduled event?", isPresented: Binding(
            get: { deletingScheduledEvent != nil },
            set: { if !$0 { deletingScheduledEvent = nil } }
        ), presenting: deletingScheduledEvent) { scheduledEvent in
            Button("Delete", role: .destructive) {
                store.deleteScheduledEventAndRefresh(id: scheduledEvent.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("Future events will no longer be created. Events already logged from this schedule are kept.")
        }
    }

    private var activeReminders: [Reminder] {
        store.reminders
            .filter(\.isActive)
            .sorted { $0.displayDueAt() < $1.displayDueAt() }
    }

    private var completedReminders: [Reminder] {
        store.reminders
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.dueAt) > ($1.completedAt ?? $1.dueAt) }
    }

    private var scheduledEvents: [ScheduledEvent] {
        store.scheduledEvents.sorted {
            switch ($0.nextDueAt, $1.nextDueAt) {
            case let (left?, right?): left < right
            case (.some, nil): true
            case (nil, .some): false
            case (nil, nil): $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }

    private func startCompletion(_ reminder: Reminder) {
        let targetIDs = Set(reminder.incompleteTargets.map(\.petID))

        if reminder.mode == .pureReminder && targetIDs.count <= 1 {
            store.completeReminderAndRefresh(
                reminder,
                completedPetIDs: targetIDs,
                completionTime: .now,
                createsEvent: false
            )
        } else {
            completionDraft = ReminderCompletionDraft(reminder: reminder)
        }
    }
}

private struct ScheduledEventSummaryRow: View {
    let scheduledEvent: ScheduledEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "fork.knife")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(scheduledEvent.title).font(.headline)
                    Spacer()
                    if let nextDueAt = scheduledEvent.nextDueAt {
                        RelativeTimeText(date: nextDueAt)
                    } else {
                        Text("Ended")
                    }
                }
                .font(.caption)
                Text("\(scheduledEvent.food.name) · \(scheduledEvent.food.amount.formatted()) \(scheduledEvent.food.unit.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    func makeScheduledEvent(pets: [Pet], now: Date = .now, calendar: Calendar = .current) -> ScheduledEvent? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              nextDueAt.timeIntervalSinceReferenceDate.isFinite,
              petID == nil || pets.contains(where: { $0.id == petID }),
              let food,
              !food.name.isEmpty,
              food.amount.isFinite,
              food.amount > 0,
              food.calories >= 0 else { return nil }
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
            id: id,
            title: title,
            petID: petID,
            food: food,
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

private struct ScheduledEventEditorView: View {
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

                scheduleFields

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

    private var scheduleFields: some View {
        Section("Schedule") {
            Picker("Repeat", selection: $draft.repeatStyle) {
                ForEach(ReminderRepeatStyle.allCases) { Text($0.rawValue).tag($0) }
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

struct ReminderCompletionDraft: Identifiable {
    let id = UUID()
    var reminder: Reminder
}

private struct ReminderCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    let draft: ReminderCompletionDraft
    @State private var selectedPetIDs: Set<UUID>
    @State private var completionTime: Date = .now

    init(draft: ReminderCompletionDraft) {
        self.draft = draft
        _selectedPetIDs = State(initialValue: Set(draft.reminder.incompleteTargets.map(\.petID)))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !draft.reminder.incompleteTargets.isEmpty {
                    Section("Completed Pets") {
                        ForEach(draft.reminder.incompleteTargets) { target in
                            Button {
                                toggle(target.petID)
                            } label: {
                                HStack {
                                    Text(petName(for: target.petID))
                                    Spacer()
                                    if selectedPetIDs.contains(target.petID) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                if draft.reminder.mode == .reminderToEvent {
                    Section("Event Time") {
                        DatePicker("Completed at", selection: $completionTime)
                    }
                }
            }
            .medicationTimingAlert(.reminderCompletion)
            .persistenceErrorBanner()
            .navigationTitle("Mark Complete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.completeReminderAndRefresh(
                            draft.reminder,
                            completedPetIDs: selectedPetIDs,
                            completionTime: completionTime,
                            createsEvent: draft.reminder.mode == .reminderToEvent,
                            presentation: .reminderCompletion,
                            onSaved: { dismiss() }
                        )
                    }
                    .disabled(!canComplete)
                    .accessibilityIdentifier("reminderCompletion.done")
                }
            }
        }
    }

    private var canComplete: Bool {
        draft.reminder.incompleteTargets.isEmpty || !selectedPetIDs.isEmpty
    }

    private func petName(for petID: UUID) -> String {
        store.petName(for: petID)
    }

    private func toggle(_ petID: UUID) {
        if selectedPetIDs.contains(petID) {
            selectedPetIDs.remove(petID)
        } else {
            selectedPetIDs.insert(petID)
        }
    }
}

struct ReminderIgnoreDraft: Identifiable {
    let id = UUID()
    var reminder: Reminder
}

private struct ReminderIgnoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    let draft: ReminderIgnoreDraft
    @State private var ignoreUntil: Date
    @State private var updateFutureNotifications = false

    init(draft: ReminderIgnoreDraft) {
        self.draft = draft
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        _ignoreUntil = State(initialValue: tomorrow)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ignore Until") {
                    Button("Later today") {
                        ignoreUntil = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
                    }

                    Button("Tomorrow") {
                        ignoreUntil = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    }

                    DatePicker("Custom", selection: $ignoreUntil)
                }

                if draft.reminder.isRecurring {
                    Section {
                        Toggle("Update future notifications", isOn: $updateFutureNotifications)
                    }
                }
            }
            .navigationTitle("Ignore Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ignore") {
                        store.ignoreReminderAndRefresh(
                            draft.reminder,
                            until: ignoreUntil,
                            updateFutureNotifications: updateFutureNotifications
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(PetCareStore.preview)
    }
}
