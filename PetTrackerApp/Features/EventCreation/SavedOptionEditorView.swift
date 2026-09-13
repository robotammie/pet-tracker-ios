import SwiftUI

struct SavedOptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @StateObject private var viewModel: SavedOptionFormViewModel
    private let option: SavedEventOption?

    init(eventType: CareEventType, option: SavedEventOption? = nil) {
        self.option = option
        _viewModel = StateObject(wrappedValue: SavedOptionFormViewModel(
            option: option,
            eventType: eventType
        ))
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Display name", text: $viewModel.name)
                    .accessibilityIdentifier("savedOption.name")
            }

            switch viewModel.eventType {
            case .food:
                foodFields
            case .medicine:
                medicineFields
                doseTimingFields
                reminderFields
            case .litter:
                Text("Litter does not use saved options.")
                    .foregroundStyle(.secondary)
            }

            if option != nil {
                Section {
                    Button("Delete Option", role: .destructive) {
                        if let option {
                            store.softDeleteSavedOptionAndRefresh(id: option.id)
                        }
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(option == nil ? "New Option" : "Edit Option")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let savedOption = viewModel.makeOption(existing: option) else {
                        return
                    }

                    store.saveSavedOptionAndRefresh(savedOption)
                    if option == nil, let reminder = viewModel.makeAutoqueuedReminder(savedOption: savedOption) {
                        store.saveReminderAndRefresh(reminder)
                    }
                    dismiss()
                }
                .disabled(!viewModel.canSave())
                .accessibilityIdentifier("savedOption.save")
            }
        }
    }

    private var foodFields: some View {
        Section("Food") {
            TextField("Official name (optional)", text: $viewModel.officialFoodName, axis: .vertical)
                .accessibilityIdentifier("savedOption.food.officialName")

            Picker("Type", selection: $viewModel.foodType) {
                ForEach(FoodType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            .onChange(of: viewModel.foodType) { _, foodType in
                if !FoodUnit.options(for: foodType).contains(viewModel.foodUnit) {
                    viewModel.foodUnit = .ounce
                    viewModel.caloriesPerUnit = 0
                }
            }

            Picker("Unit", selection: $viewModel.foodUnit) {
                ForEach(FoodUnit.options(for: viewModel.foodType)) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }

            if viewModel.foodUnit == .can {
                Text("Use calories for one whole can of this food. Fractional cans can be logged; no unit conversion is applied.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: $viewModel.caloriesPerUnit, in: 0...3000, step: 5) {
                Text("Calories per \(viewModel.foodUnit.rawValue): \(viewModel.caloriesPerUnit)")
            }
        }
    }

    private var medicineFields: some View {
        Section("Medicine") {
            TextField("Type / purpose (optional)", text: $viewModel.medicinePurpose)
                .accessibilityIdentifier("savedOption.medicine.purpose")

            HStack {
                Text("Default dose")
                Spacer()
                TextField("Dose", value: $viewModel.dosage, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            TextField("Unit", text: $viewModel.medicineUnit)
        }
    }

    private var reminderFields: some View {
        Section("Reminder") {
            Toggle("Autoqueue notification", isOn: $viewModel.shouldAutoqueueReminder)

            if viewModel.shouldAutoqueueReminder {
                Picker("Mode", selection: $viewModel.reminderMode) {
                    ForEach(ReminderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                DatePicker("First due", selection: $viewModel.reminderDueAt)

                PetSelectionSection(
                    pets: store.pets,
                    selectedPetIDs: viewModel.reminderPetIDs,
                    title: reminderPetTitle,
                    togglePet: viewModel.toggleReminderPet
                )

                Text("Repeats every day. More schedule controls will come in the reminder editor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var doseTimingFields: some View {
        Section("Dose timing") {
            Toggle("Check dose intervals", isOn: $viewModel.usesDoseTiming)
                .accessibilityIdentifier("medicineTiming.enabled")
            if viewModel.usesDoseTiming {
                MedicationDoseIntervalFields(minimumHours: $viewModel.minimumDoseHours,
                                             maximumHours: $viewModel.maximumDoseHours)
                if !viewModel.configuredDoseInterval.isValid {
                    Text("Enter positive hours; the maximum must be at least the minimum.")
                        .foregroundStyle(.secondary)
                }
            }
            DisclosureGroup("Pet-specific intervals") {
                ForEach(store.pets) { pet in
                    Toggle("Different interval for \(pet.name)", isOn: Binding(
                        get: { viewModel.petDoseIntervals.contains { $0.petID == pet.id } },
                        set: { viewModel.setPetDoseIntervalEnabled($0, petID: pet.id) }
                    ))
                    if viewModel.petDoseIntervals.contains(where: { $0.petID == pet.id }) {
                        MedicationDoseIntervalFields(
                            minimumHours: petDoseHoursBinding(petID: pet.id, minimum: true),
                            maximumHours: petDoseHoursBinding(petID: pet.id, minimum: false),
                            accessibilityPrefix: "medicineTiming.\(pet.id.uuidString)"
                        )
                    }
                }
            }
            Text("Use your veterinarian's prescribed interval. Set both values equal for a fixed interval. Pet-specific intervals take precedence. Without a configured interval, no timing check is made.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func petDoseHoursBinding(petID: UUID, minimum: Bool) -> Binding<Double> {
        Binding(get: {
            let interval = viewModel.petDoseIntervals.first { $0.petID == petID }?.interval
            return (minimum ? interval?.minimumHours : interval?.maximumHours) ?? 0
        }, set: { viewModel.setPetDoseHours($0, petID: petID, minimum: minimum) })
    }

    private var reminderPetTitle: String {
        EventCreationSelectionText.petNames(
            selectedPetIDs: viewModel.reminderPetIDs,
            pets: store.pets
        )
    }
}

#Preview {
    NavigationStack {
        SavedOptionEditorView(eventType: .food)
            .environmentObject(PetCareStore.preview)
    }
}
