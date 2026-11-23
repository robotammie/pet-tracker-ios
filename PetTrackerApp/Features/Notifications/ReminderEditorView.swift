import SwiftUI

struct ReminderEditorView: View {
    @EnvironmentObject private var store: PetCareStore
    @Environment(\.dismiss) private var dismiss
    @State private var form: ReminderFormDraft
    @State private var saveError = false

    init(reminder: Reminder? = nil) {
        _form = State(initialValue: ReminderFormDraft(reminder: reminder))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("Title", text: $form.details.title).frame(minHeight: 44)
                        .accessibilityIdentifier("reminderEditor.title")
                }
                Section("Due") {
                    Picker("Due style", selection: $form.details.dueStyle) {
                        ForEach(ReminderDueStyle.allCases) { Text($0.rawValue).tag($0) }
                    }.accessibilityIdentifier("reminderEditor.dueStyle")
                    DatePicker("First due", selection: $form.details.dueAt,
                               displayedComponents: form.details.dueStyle == .dayOnly ? [.date] : [.date, .hourAndMinute])
                        .accessibilityIdentifier("reminderEditor.due")
                    if let ignored = form.details.original?.ignoredUntil {
                        Text("Ignored until \(ignored.formatted()). Changing the due date clears this postponement.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                scheduleFields
                Section("Create Events") {
                    Text("Events are logged when you complete this reminder.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Menu {
                        ForEach(CareEventType.allCases) { type in
                            Button(type.rawValue) { form.events.append(ReminderEventActionDraft(type: type)) }
                        }
                    } label: {
                        HStack {
                            Text("Add event")
                            Spacer()
                            Image(systemName: "plus")
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("reminderEditor.addEvent")
                    .disabled(form.details.hasCompletedTargets)
                }
                ForEach($form.events) { $event in
                    Section {
                        ReminderActionFields(draft: $event)
                    } header: {
                        HStack {
                            Text(event.type.rawValue)
                            Spacer()
                            Button("Remove", role: .destructive) { form.events.removeAll { $0.id == event.id } }
                                .frame(minHeight: 44)
                                .accessibilityLabel("Remove \(event.type.rawValue.lowercased()) event")
                        }
                    }
                    .disabled(form.details.hasCompletedTargets)
                }
                if form.events.isEmpty { petFields }
                if form.events.contains(where: { $0.petID == nil }) && form.events.contains(where: { $0.petID != nil }) {
                    Text("Household events are logged with the first pet completion.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if form.details.hasCompletedTargets {
                    Text("Some pets are already complete. Event details and pet selection stay unchanged for this occurrence.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if form.details.dueStyle == .dayOnly && (form.details.repeatStyle == .timesPerDay || (form.details.repeatStyle == .every && form.details.recurrenceUnit == .hour)) {
                    Text("Use timestamp due style for hourly or times-per-day schedules.").foregroundStyle(.secondary)
                }
                if form.details.hasEndDate && form.details.endDate < form.details.dueAt {
                    Text("End date must be on or after the first due time.").foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .persistenceErrorBanner()
            .navigationTitle(form.details.original == nil ? "Add Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("reminderEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let reminder = form.makeReminder(pets: store.pets) else { return }
                        if let original = form.details.original, store.reminders.first(where: { $0.id == original.id }) != original {
                            saveError = true
                        } else {
                            if store.saveReminderAndRefresh(reminder) { dismiss() }
                        }
                    }
                    .disabled(form.makeReminder(pets: store.pets) == nil)
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
            Picker("Repeat", selection: $form.details.repeatStyle) {
                ForEach(ReminderRepeatStyle.allCases) { Text($0.rawValue).tag($0) }
            }.accessibilityIdentifier("reminderEditor.repeat")
            if form.details.repeatStyle == .every {
                Stepper("Every \(form.details.interval)", value: $form.details.interval, in: 1...365)
                Picker("Interval unit", selection: $form.details.recurrenceUnit) {
                    ForEach(RecurrenceUnit.allCases) { Text($0.rawValue).tag($0) }
                }.accessibilityIdentifier("reminderEditor.intervalUnit")
            } else if form.details.repeatStyle == .timesPerDay {
                Stepper("\(form.details.dailyTimes.count) times per day", value: Binding(
                    get: { form.details.dailyTimes.count }, set: { form.details.setDailyCount($0) }), in: 1...12)
                ForEach(form.details.dailyTimes.indices, id: \.self) { index in
                    DatePicker("Time \(index + 1)", selection: $form.details.dailyTimes[index], displayedComponents: [.hourAndMinute])
                }
                Text("Suggested times can be edited; each time must be different.").font(.footnote).foregroundStyle(.secondary)
            }
            Toggle("End date", isOn: $form.details.hasEndDate).accessibilityIdentifier("reminderEditor.hasEndDate")
            if form.details.hasEndDate {
                DatePicker("Ends", selection: $form.details.endDate).accessibilityIdentifier("reminderEditor.endDate")
            }
        }
    }

    private var petFields: some View {
        Section("For") {
            ForEach(store.pets) { pet in
                Button {
                    if form.details.selectedPetIDs.contains(pet.id) { form.details.selectedPetIDs.remove(pet.id) }
                    else { form.details.selectedPetIDs.insert(pet.id) }
                } label: {
                    HStack {
                        Text(pet.name)
                        Spacer()
                        if form.details.selectedPetIDs.contains(pet.id) { Image(systemName: "checkmark") }
                    }.frame(minHeight: 44)
                }
                .foregroundStyle(.primary).accessibilityIdentifier("reminderEditor.pet.\(pet.id)")
            }
            Text("Pet selection is optional.").font(.footnote).foregroundStyle(.secondary)
        }.disabled(form.details.hasCompletedTargets)
    }
}

private struct ReminderActionFields: View {
    @EnvironmentObject private var store: PetCareStore
    @Binding var draft: ReminderEventActionDraft
    var body: some View {
        if draft.type != .litter {
            Picker("For", selection: $draft.petID) {
                Text(draft.type == .medicine ? "Choose pet" : "Household").tag(Optional<UUID>.none)
                ForEach(store.pets) { Text($0.name).tag(Optional($0.id)) }
            }
            .accessibilityIdentifier("reminderAction.pet.\(draft.type.rawValue)")
            .onChange(of: draft.petID) { _, _ in draft.updatePet(options: store.savedOptions, pets: store.pets) }
            Picker("Saved option", selection: $draft.selectedOptionID) {
                Text(draft.event == nil ? "Choose option" : "Keep recorded details").tag(Optional<UUID>.none)
                ForEach(store.activeSavedOptions(for: draft.type)) { option in
                    switch option.data {
                    case let .food(food): Text(food.name).tag(Optional(option.id))
                    case let .medicine(medicine): Text(medicine.name).tag(Optional(option.id))
                    }
                }
            }
            .accessibilityIdentifier("reminderAction.option.\(draft.type.rawValue)")
            .onChange(of: draft.selectedOptionID) { _, id in
                draft.selectOption(store.savedOptions.first { $0.id == id })
            }
        }
        if draft.event != nil {
            ReminderPayloadFields(draft: Binding(
                get: { draft.event! }, set: { draft.event = $0 }))
        }
    }
}

private struct ReminderPayloadFields: View {
    @Binding var draft: CareEventEditDraft
    var body: some View {
        switch draft.original.type {
        case .food:
            Text(draft.name)
            LabeledContent("Amount (\(draft.foodUnit.rawValue))") {
                TextField("Amount", value: $draft.amount, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minHeight: 44)
                    .onChange(of: draft.amount) { _, _ in draft.recalculateCalories() }
                    .accessibilityIdentifier("reminderEditor.amount.\(draft.petID?.uuidString ?? "household")")
            }
            LabeledContent("Calories") {
                TextField("Calories", value: $draft.calories, format: .number)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(minHeight: 44)
            }
            Text("Event details are stored with this reminder; saved-option edits do not rewrite them.").font(.footnote).foregroundStyle(.secondary)
        case .medicine:
            Text(draft.name)
            LabeledContent("Dose (\(draft.medicineUnit))") {
                TextField("Dose", value: $draft.dosage, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(minHeight: 44)
                    .accessibilityIdentifier("reminderEditor.dose.\(draft.petID?.uuidString ?? "household")")
            }
        case .litter: Text("Litter cleaned")
        }
    }
}
