import SwiftUI

struct FoodEventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @StateObject private var viewModel = FoodEventFormViewModel()

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Time", selection: $viewModel.timestamp)
            }

            Section("Food") {
                Picker("Saved food", selection: $viewModel.selectedSavedOptionID) {
                    Text("Choose food").tag(Optional<UUID>.none)

                    ForEach(foodOptions) { option in
                        Text(optionTitle(option)).tag(Optional(option.id))
                    }
                }
                .onChange(of: viewModel.selectedSavedOptionID) { _, selectedID in
                    viewModel.selectSavedOption(foodOptions.first { $0.id == selectedID })
                }

                if let food = viewModel.selectedFood {
                    LabeledContent("Unit", value: food.unit.rawValue)
                    LabeledContent("Calories per \(food.unit.rawValue)", value: "\(food.caloriesPerUnit)")
                }
            }

            Section("For") {
                Menu {
                    Button {
                        viewModel.selectHousehold()
                    } label: {
                        Label("Household", systemImage: viewModel.isHouseholdSelected ? "checkmark" : "house")
                    }

                    ForEach(store.pets) { pet in
                        Button {
                            viewModel.togglePet(pet.id)
                        } label: {
                            Label(
                                pet.name,
                                systemImage: viewModel.selectedPetIDs.contains(pet.id) ? "checkmark" : "cat"
                            )
                        }
                    }
                } label: {
                    Label(destinationTitle, systemImage: "person.2")
                }
            }

            if viewModel.selectedFood != nil {
                Section("Amount") {
                    if viewModel.isHouseholdSelected {
                        amountRow("Household", amount: $viewModel.householdAmount)
                    } else {
                        ForEach(selectedPets) { pet in
                            amountRow(pet.name, amount: amountBinding(for: pet.id))
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Food")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.saveCareEventsAndRefresh(viewModel.makeEvents())
                    dismiss()
                }
                .disabled(!viewModel.canSave())
            }
        }
    }

    private var foodOptions: [SavedEventOption] {
        store.activeSavedOptions(for: .food).filter { option in
            if case .food = option.data {
                return true
            }

            return false
        }
    }

    private var selectedPets: [Pet] {
        store.pets
            .filter { viewModel.selectedPetIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var destinationTitle: String {
        if viewModel.isHouseholdSelected {
            return "Household"
        }

        let names = selectedPets.map(\.name)
        return names.isEmpty ? "Choose pets" : names.joined(separator: ", ")
    }

    private func amountBinding(for petID: UUID) -> Binding<Double> {
        Binding(
            get: { viewModel.petAmounts[petID] ?? 0 },
            set: { viewModel.petAmounts[petID] = $0 }
        )
    }

    private func optionTitle(_ option: SavedEventOption) -> String {
        if case let .food(food) = option.data {
            return food.name
        }

        return option.eventType.rawValue
    }

    private func amountRow(_ title: String, amount: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                TextField("Amount", value: amount, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }

            if let food = viewModel.selectedFood {
                Text("\(viewModel.calories(for: amount.wrappedValue)) cal, \(food.unit.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FoodEventCreationView()
            .environmentObject(PetCareStore.preview)
    }
}
