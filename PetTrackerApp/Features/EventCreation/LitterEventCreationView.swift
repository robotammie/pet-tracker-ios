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
                Label("Household litter box cleaning", systemImage: "sparkles")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Litter")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.saveCareEventAndRefresh(viewModel.makeEvent())
                    dismiss()
                }
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
