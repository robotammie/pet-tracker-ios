import SwiftUI

struct FoodEventCreationView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @State private var savedOptionRoute: SavedOptionCreationRoute?
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
                if foodOptions.isEmpty {
                    Text("Add a food option below or manage saved options in Settings.")
                        .foregroundStyle(.secondary)
                }
                Picker("Saved food", selection: $viewModel.selectedSavedOptionID) {
                    Text("Choose food").tag(Optional<UUID>.none)

                    ForEach(foodOptions) { option in
                        Text(optionTitle(option)).tag(Optional(option.id))
                    }
                }
                .accessibilityIdentifier("foodCreation.savedOption")
                .onChange(of: viewModel.selectedSavedOptionID) { _, selectedID in
                    viewModel.selectSavedOption(foodOptions.first { $0.id == selectedID })
                }
                Button { savedOptionRoute = SavedOptionCreationRoute(eventType: .food) } label: {
                    Text("Add new food…")
                        .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless).accessibilityIdentifier("foodCreation.addOption")

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
        .sheet(item: $savedOptionRoute) { route in
            SavedOptionCreationSheet(eventType: route.eventType) { option in viewModel.selectSavedOption(option) }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.saveCareEventsAndRefresh(viewModel.makeEvents())
                    dismiss()
                }
                .disabled(!viewModel.canSave())
                .accessibilityIdentifier("foodCreation.save")
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text(title)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if let food = viewModel.selectedFood {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        TextField("Amount", value: amount, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 90, minHeight: 44)
                            .accessibilityLabel("Amount for \(title)")
                            .accessibilityIdentifier("foodCreation.amount.\(title)")

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
