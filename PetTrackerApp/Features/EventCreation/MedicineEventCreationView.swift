import SwiftUI

struct MedicineEventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @StateObject private var viewModel = MedicineEventFormViewModel()

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Time", selection: $viewModel.timestamp)
            }

            Section("Medicine") {
                Picker("Saved medicine", selection: $viewModel.selectedSavedOptionID) {
                    Text("Choose medicine").tag(Optional<UUID>.none)

                    ForEach(medicineOptions) { option in
                        Text(optionTitle(option)).tag(Optional(option.id))
                    }
                }
                .onChange(of: viewModel.selectedSavedOptionID) { _, selectedID in
                    viewModel.selectSavedOption(medicineOptions.first { $0.id == selectedID })
                }

                if let medicine = viewModel.selectedMedicine {
                    LabeledContent("Default dose", value: "\(medicine.dosage.formatted()) \(medicine.unit)")
                }
            }

            Section("For") {
                Menu {
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
                    Label(destinationTitle, systemImage: "person")
                }
            }

            if viewModel.selectedMedicine != nil && !viewModel.selectedPetIDs.isEmpty {
                Section("Dose") {
                    ForEach(selectedPets) { pet in
                        doseRow(pet)
                    }
                }
            }
        }
        .navigationTitle("Add Medicine")
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

    private var medicineOptions: [SavedEventOption] {
        store.activeSavedOptions(for: .medicine).filter { option in
            if case .medicine = option.data {
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
        let names = selectedPets.map(\.name)
        return names.isEmpty ? "Choose pets" : names.joined(separator: ", ")
    }

    private func optionTitle(_ option: SavedEventOption) -> String {
        if case let .medicine(medicine) = option.data {
            return medicine.name
        }

        return option.eventType.rawValue
    }

    private func dosageBinding(for petID: UUID) -> Binding<Double> {
        Binding(
            get: { viewModel.petDosages[petID] ?? 0 },
            set: { viewModel.petDosages[petID] = $0 }
        )
    }

    private func doseRow(_ pet: Pet) -> some View {
        HStack {
            Text(pet.name)
            Spacer()
            TextField("Dose", value: dosageBinding(for: pet.id), format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)

            if let unit = viewModel.selectedMedicine?.unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MedicineEventCreationView()
            .environmentObject(PetCareStore.preview)
    }
}
