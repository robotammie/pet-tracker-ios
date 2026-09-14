import SwiftUI

struct CareEventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @State private var draft: CareEventEditDraft

    init(event: CareEvent) {
        _draft = State(initialValue: CareEventEditDraft(event: event))
    }

    var body: some View {
        NavigationStack {
            Form {
                EventTimestampSection(timestamp: $draft.timestamp)
                if draft.original.type != .litter {
                    Section("For") {
                        Picker("Pet", selection: $draft.petID) {
                            if draft.original.type == .food {
                                Text("Household").tag(Optional<UUID>.none)
                            }
                            ForEach(store.pets) { pet in
                                Text(pet.name).tag(Optional(pet.id))
                            }
                        }
                        .accessibilityIdentifier("eventEditor.pet")
                    }
                    Section("Details") {
                        TextField("Name", text: $draft.name)
                            .accessibilityIdentifier("eventEditor.name")
                    }
                }
                switch draft.original.type {
                case .food: foodFields
                case .medicine:
                    Section("Medicine") {
                        Picker("Timing medication", selection: $draft.savedMedicationID) {
                            Text("Unlinked historical dose").tag(Optional<UUID>.none)
                            ForEach(store.savedOptions.filter { $0.eventType == .medicine }) { option in
                                if case let .medicine(data) = option.data {
                                    Text(data.name).tag(Optional(option.id))
                                }
                            }
                        }
                        .accessibilityIdentifier("eventEditor.timingMedication")
                        TextField("Dose", value: $draft.dosage, format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("eventEditor.dose")
                        TextField("Unit", text: $draft.medicineUnit)
                    }
                case .litter:
                    Text("Household litter cleaning")
                }
                Section {
                    Text("Changes apply only to this event. Saved options and reminder history are kept as recorded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = draft.original.doseTimingOverrideMessage {
                    Section("Recorded timing override") {
                        Text(message)
                        if let date = draft.original.doseTimingOverrideAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .medicationTimingAlert(.eventEditor)
            .persistenceErrorBanner()
            .navigationTitle("Edit \(draft.original.type.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("eventEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let event = draft.makeEvent(pets: store.pets) else { return }
                        store.saveCareEventAndRefresh(event, presentation: .eventEditor, onSaved: { dismiss() })
                    }
                    .disabled(!draft.canSave(pets: store.pets))
                    .accessibilityIdentifier("eventEditor.save")
                }
            }
        }
    }

    private var foodFields: some View {
        Section("Food") {
            Picker("Type", selection: $draft.foodType) {
                ForEach(FoodType.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Unit", selection: $draft.foodUnit) {
                ForEach(FoodUnit.options(for: draft.foodType)) { Text($0.rawValue).tag($0) }
            }
            TextField("Amount", value: $draft.amount, format: .number)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Amount")
                .accessibilityIdentifier("eventEditor.amount")
            TextField("Calories", value: $draft.calories, format: .number)
                .keyboardType(.numberPad)
                .accessibilityLabel("Calories")
                .accessibilityIdentifier("eventEditor.calories")
            if let rate = draft.storedCalorieRate {
                Button("Recalculate using stored \(rate) cal per \(draft.foodUnit.rawValue)") {
                    draft.recalculateCalories()
                }
                .accessibilityIdentifier("eventEditor.recalculateCalories")
            } else {
                Text("Confirm calories when changing the amount or unit. This event has no stored calorie rate for the selected unit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
