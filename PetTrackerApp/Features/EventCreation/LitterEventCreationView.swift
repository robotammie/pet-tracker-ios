import SwiftUI

struct LitterEventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    @State private var isRecurring = false
    @State private var recurrence = ScheduledEventEditDraft()
    @StateObject private var viewModel = LitterEventFormViewModel()

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Time", selection: $viewModel.timestamp)
            }

            RecurringEventFields(isRecurring: $isRecurring, draft: $recurrence)
            Section {
                Label("Household litter box cleaning", systemImage: "tray")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Litter")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let saved = isRecurring
                        ? store.saveScheduledEventsAndRefresh(recurrence.schedules(for: [viewModel.makeEvent()], pets: store.pets))
                        : store.saveCareEventAndRefresh(viewModel.makeEvent())
                    if saved { dismiss() }
                }
                .disabled(isRecurring && recurrence.schedules(for: [viewModel.makeEvent()], pets: store.pets).isEmpty)
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
