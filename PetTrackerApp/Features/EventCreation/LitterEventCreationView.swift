import SwiftUI

struct LitterEventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @StateObject private var viewModel = LitterEventFormViewModel()

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Time", selection: $viewModel.timestamp)
            }

            Section {
                Label("Household litter box cleaning", systemImage: "tray")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Litter")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if store.saveCareEventAndRefresh(viewModel.makeEvent()) { dismiss() }
                }
                .accessibilityIdentifier("litterCreation.save")
            }
        }
    }
}

#Preview {
    NavigationStack {
        LitterEventCreationView()
            .environmentObject(PetCareStore.preview)
    }
}
