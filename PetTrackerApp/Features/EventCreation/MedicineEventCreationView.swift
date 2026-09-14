import SwiftUI

struct MedicineEventCreationView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @State private var savedOptionRoute: SavedOptionCreationRoute?
    @StateObject private var viewModel = MedicineEventFormViewModel()

    var body: some View {
        Form {
            EventTimestampSection(timestamp: $viewModel.timestamp)

            PetSelectionSection(
                pets: store.pets,
                selectedPetIDs: viewModel.selectedPetIDs,
                title: destinationTitle,
                togglePet: viewModel.togglePet
            )

            Section("Medicine") {
                if medicineOptions.isEmpty {
                    Text("Add a medication option below or manage saved options in Settings.")
                        .foregroundStyle(.secondary)
                }
                Picker("Saved medicine", selection: $viewModel.selectedSavedOptionID) {
                    Text("Choose medicine").tag(Optional<UUID>.none)

                    ForEach(medicineOptions) { option in
                        Text(optionTitle(option)).tag(Optional(option.id))
                    }
                }
                .accessibilityIdentifier("medicineCreation.savedOption")
                .onChange(of: viewModel.selectedSavedOptionID) { _, selectedID in
                    viewModel.selectSavedOption(medicineOptions.first { $0.id == selectedID })
                }
                Button { savedOptionRoute = SavedOptionCreationRoute(eventType: .medicine) } label: {
                    Text("Add new medication…")
                        .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless).accessibilityIdentifier("medicineCreation.addOption")

                if let medicine = viewModel.selectedMedicine {
                    LabeledContent("Default dose", value: "\(medicine.dosage.formatted()) \(medicine.unit)")
                }
            }

            if viewModel.selectedMedicine != nil && !viewModel.selectedPetIDs.isEmpty {
                Section("Dose") {
                    ForEach(selectedPets) { pet in
                        doseRow(pet)
                        timingSummary(for: pet)
                    }
                }
            }
        }
        .medicationTimingAlert(.eventCreation)
        .navigationTitle("Add Medicine")
        .sheet(item: $savedOptionRoute) { route in
            SavedOptionCreationSheet(eventType: route.eventType) { option in viewModel.selectNewSavedOption(option) }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.saveCareEventsAndRefresh(viewModel.makeEvents(), presentation: .eventCreation, onSaved: { dismiss() })
                }
                .disabled(!viewModel.canSave())
                .accessibilityIdentifier("medicineCreation.save")
            }
        }
    }

    @ViewBuilder
    private func timingSummary(for pet: Pet) -> some View {
        if let interval = viewModel.selectedMedicine?.doseInterval(for: pet.id) {
            Text("Prescribed interval: \(interval.summary)")
                .font(.footnote).foregroundStyle(.secondary)
            let latest = store.events.map { MedicationTimingService.resolved($0, options: store.savedOptions) }
                .filter { event in
                    guard event.petID == pet.id, case let .medicine(data) = event.data else { return false }
                    return data.savedOptionID == viewModel.selectedSavedOptionID
                }.max { $0.startTime < $1.startTime }
            if let latest, let window = MedicationTimingService.nextDoseWindow(for: latest, options: store.savedOptions) {
                Text("Next prescribed window from latest logged dose: \(window.lowerBound.formatted(date: .abbreviated, time: .shortened)) – \(window.upperBound.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else {
            Text("No prescribed interval configured; timing is not checked.")
                .font(.footnote).foregroundStyle(.secondary)
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
        EventCreationSelectionText.sortedSelectedPets(
            selectedPetIDs: viewModel.selectedPetIDs,
            pets: store.pets
        )
    }

    private var destinationTitle: String {
        EventCreationSelectionText.petNames(
            selectedPetIDs: viewModel.selectedPetIDs,
            pets: store.pets
        )
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        return layout {
            Text(pet.name)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            TextField("Dose", value: dosageBinding(for: pet.id), format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(minHeight: 44)
                .accessibilityLabel("Dose for \(pet.name)")

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
