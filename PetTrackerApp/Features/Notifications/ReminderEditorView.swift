import SwiftUI

struct ReminderEditorView: View {
    @EnvironmentObject private var store: PetCareStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReminderEditDraft
    @State private var saveError = false

    init(reminder: Reminder? = nil) {
        _draft = State(initialValue: ReminderEditDraft(reminder: reminder))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $draft.title).frame(minHeight: 44)
                        .accessibilityIdentifier("reminderEditor.title")
                    Picker("Mode", selection: $draft.mode) {
                        ForEach(ReminderMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .disabled(draft.hasCompletedTargets).accessibilityIdentifier("reminderEditor.mode")
                }
                Section("Due") {
                    Picker("Due style", selection: $draft.dueStyle) {
                        ForEach(ReminderDueStyle.allCases) { Text($0.rawValue).tag($0) }
                    }.accessibilityIdentifier("reminderEditor.dueStyle")
                    DatePicker("First due", selection: $draft.dueAt,
                               displayedComponents: draft.dueStyle == .dayOnly ? [.date] : [.date, .hourAndMinute])
                        .accessibilityIdentifier("reminderEditor.due")
                    if let ignored = draft.original?.ignoredUntil {
                        Text("Ignored until \(ignored.formatted()). Changing the due date clears this postponement.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                scheduleFields
                if draft.mode == .reminderToEvent { eventFields }
                petFields
                if draft.mode == .reminderToEvent {
                    ForEach($draft.payloads) { $payload in
                        Section(payload.petID.map { store.petName(for: $0) } ?? "Household") {
                            if let target = draft.original?.targets.first(where: { $0.petID == payload.petID }), target.completedAt != nil {
                                Text("Already completed; recorded event details are preserved.")
                            } else { ReminderPayloadFields(draft: $payload.event) }
                        }
                    }
                }
                if draft.hasCompletedTargets {
                    Text("Some pets are already complete. Mode, event type, and pet selection are kept for this occurrence; its completed records remain unchanged.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if draft.dueStyle == .dayOnly && (draft.repeatStyle == .timesPerDay || (draft.repeatStyle == .every && draft.recurrenceUnit == .hour)) {
                    Text("Use timestamp due style for hourly or times-per-day schedules.").foregroundStyle(.secondary)
                }
                if draft.hasEndDate && draft.endDate < draft.dueAt {
                    Text("End date must be on or after the first due time.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(draft.original == nil ? "Add Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("reminderEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let reminder = draft.makeReminder(pets: store.pets) else { return }
                        if let original = draft.original, store.reminders.first(where: { $0.id == original.id }) != original {
                            saveError = true
                        } else {
                            store.saveReminderAndRefresh(reminder)
                            dismiss()
                        }
                    }
                    .disabled(draft.makeReminder(pets: store.pets) == nil)
                    .accessibilityIdentifier("reminderEditor.save")
                }
            }
            .alert("Reminder changed", isPresented: $saveError) {
                Button("OK", role: .cancel) { }
            } message: { Text("This reminder was updated while editing. Cancel and reopen it to use its current state.") }
        }
    }

    private var scheduleFields: some View {
        Section("Schedule") {
            Picker("Repeat", selection: $draft.repeatStyle) {
                ForEach(ReminderRepeatStyle.allCases) { Text($0.rawValue).tag($0) }
            }.accessibilityIdentifier("reminderEditor.repeat")
            if draft.repeatStyle == .every {
                Stepper("Every \(draft.interval)", value: $draft.interval, in: 1...365)
                Picker("Interval unit", selection: $draft.recurrenceUnit) {
                    ForEach(RecurrenceUnit.allCases) { Text($0.rawValue).tag($0) }
                }.accessibilityIdentifier("reminderEditor.intervalUnit")
            } else if draft.repeatStyle == .timesPerDay {
                Stepper("\(draft.dailyTimes.count) times per day", value: Binding(
                    get: { draft.dailyTimes.count }, set: { draft.setDailyCount($0) }), in: 1...12)
                ForEach(draft.dailyTimes.indices, id: \.self) { index in
                    DatePicker("Time \(index + 1)", selection: $draft.dailyTimes[index], displayedComponents: [.hourAndMinute])
                }
                Text("Suggested times can be edited; each time must be different.").font(.footnote).foregroundStyle(.secondary)
            }
            Toggle("End date", isOn: $draft.hasEndDate).accessibilityIdentifier("reminderEditor.hasEndDate")
            if draft.hasEndDate {
                DatePicker("Ends", selection: $draft.endDate).accessibilityIdentifier("reminderEditor.endDate")
            }
        }
    }

    private var eventFields: some View {
        Section("Event") {
            Picker("Event type", selection: $draft.eventType) {
                ForEach(CareEventType.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: draft.eventType) { _, _ in draft.changeEventType() }
            .disabled(draft.hasCompletedTargets).accessibilityIdentifier("reminderEditor.eventType")
            if draft.eventType != .litter {
                Picker("Saved option", selection: $draft.selectedOptionID) {
                    Text(draft.original == nil ? "Choose option" : "Keep recorded details").tag(Optional<UUID>.none)
                    ForEach(store.activeSavedOptions(for: draft.eventType)) { option in
                        Text(optionName(option)).tag(Optional(option.id))
                    }
                }
                .onChange(of: draft.selectedOptionID) { _, id in
                    draft.selectOption(store.savedOptions.first { $0.id == id })
                }
                .disabled(draft.hasCompletedTargets).accessibilityIdentifier("reminderEditor.savedOption")
            } else { Text("Household litter cleaning") }
        }
    }

    private func optionName(_ option: SavedEventOption) -> String {
        switch option.data {
        case let .food(data): return data.name
        case let .medicine(data): return data.name
        }
    }

    private var petFields: some View {
        Section("For") {
            if draft.mode == .reminderToEvent && draft.eventType == .food {
                Toggle("Household", isOn: $draft.isHousehold)
                    .onChange(of: draft.isHousehold) { _, value in
                        if value { draft.selectedPetIDs = [] }
                        draft.reconcilePayloads()
                    }.accessibilityIdentifier("reminderEditor.household")
            }
            if draft.mode == .pureReminder || draft.eventType != .litter {
                ForEach(store.pets) { pet in
                    Button {
                        if draft.selectedPetIDs.contains(pet.id) { draft.selectedPetIDs.remove(pet.id) }
                        else { draft.selectedPetIDs.insert(pet.id) }
                        draft.isHousehold = false
                        draft.reconcilePayloads()
                    } label: {
                        HStack {
                            Text(pet.name)
                            Spacer()
                            if draft.selectedPetIDs.contains(pet.id) { Image(systemName: "checkmark") }
                        }.frame(minHeight: 44)
                    }
                    .foregroundStyle(.primary).accessibilityIdentifier("reminderEditor.pet.\(pet.id)")
                }
            }
            if draft.mode == .pureReminder { Text("Pet selection is optional for a pure reminder.").font(.footnote).foregroundStyle(.secondary) }
        }.disabled(draft.hasCompletedTargets)
    }
}

private struct ReminderPayloadFields: View {
    @Binding var draft: CareEventEditDraft
    var body: some View {
        switch draft.original.type {
        case .food:
            Text(draft.name)
            TextField("Amount", value: $draft.amount, format: .number).keyboardType(.decimalPad).frame(minHeight: 44)
                .onChange(of: draft.amount) { _, _ in draft.recalculateCalories() }
                .accessibilityIdentifier("reminderEditor.amount.\(draft.petID?.uuidString ?? "household")")
            Text(draft.foodUnit.rawValue).foregroundStyle(.secondary)
            TextField("Calories", value: $draft.calories, format: .number).keyboardType(.numberPad).frame(minHeight: 44)
            Text("Event details are stored with this reminder; saved-option edits do not rewrite them.").font(.footnote).foregroundStyle(.secondary)
        case .medicine:
            Text(draft.name)
            TextField("Dose", value: $draft.dosage, format: .number).keyboardType(.decimalPad).frame(minHeight: 44)
                .accessibilityIdentifier("reminderEditor.dose.\(draft.petID?.uuidString ?? "household")")
            Text(draft.medicineUnit).foregroundStyle(.secondary)
        case .litter: Text("Litter cleaned")
        }
    }
}
