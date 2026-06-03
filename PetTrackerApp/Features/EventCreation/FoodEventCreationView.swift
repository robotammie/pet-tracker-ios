import SwiftUI

struct FoodEventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @StateObject private var viewModel = FoodEventFormViewModel()

    var body: some View {
        Form {
            EventTimestampSection(timestamp: $viewModel.timestamp)

            PetSelectionSection(
                pets: store.pets,
                selectedPetIDs: viewModel.selectedPetIDs,
                title: destinationTitle,
                includesHousehold: true,
                isHouseholdSelected: viewModel.isHouseholdSelected,
                togglePet: viewModel.togglePet,
                selectHousehold: viewModel.selectHousehold
            )

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
                    LabeledContent("Calories per \(food.unit.rawValue)", value: "\(food.caloriesPerUnit)")
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
        EventCreationSelectionText.sortedSelectedPets(
            selectedPetIDs: viewModel.selectedPetIDs,
            pets: store.pets
        )
    }

    private var destinationTitle: String {
        if viewModel.isHouseholdSelected {
            return "Household"
        }

        return EventCreationSelectionText.petNames(
            selectedPetIDs: viewModel.selectedPetIDs,
            pets: store.pets
        )
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
        HStack(alignment: .firstTextBaseline) {
            Text(title)

            Spacer()

            if let food = viewModel.selectedFood {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Amount", value: amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 90)

                        Text(food.unit.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(viewModel.calories(for: amount.wrappedValue)) cal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
