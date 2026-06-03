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
                TextField("Name", text: $viewModel.name)
            }

            switch viewModel.eventType {
            case .food:
                foodFields
            case .medicine:
                medicineFields
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
                    dismiss()
                }
                .disabled(!viewModel.canSave())
            }
        }
    }

    private var foodFields: some View {
        Section("Food") {
            Picker("Type", selection: $viewModel.foodType) {
                ForEach(FoodType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            Picker("Unit", selection: $viewModel.foodUnit) {
                ForEach(FoodUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }

            Stepper(value: $viewModel.caloriesPerUnit, in: 0...3000, step: 5) {
                Text("Calories per \(viewModel.foodUnit.rawValue): \(viewModel.caloriesPerUnit)")
            }
        }
    }

    private var medicineFields: some View {
        Section("Medicine") {
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
}

#Preview {
    NavigationStack {
        SavedOptionEditorView(eventType: .food)
            .environmentObject(PetCareStore.preview)
    }
}
