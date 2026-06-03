import SwiftUI

struct SavedOptionsListView: View {
    @EnvironmentObject private var store: PetCareStore
    let eventType: CareEventType

    var body: some View {
        List {
            if options.isEmpty {
                ContentUnavailableView("No saved \(eventType.rawValue.lowercased()) options", systemImage: icon)
            } else {
                ForEach(options) { option in
                    NavigationLink {
                        SavedOptionEditorView(eventType: eventType, option: option)
                    } label: {
                        optionRow(option)
                    }
                }
            }
        }
        .navigationTitle("\(eventType.rawValue) Options")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SavedOptionEditorView(eventType: eventType)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add \(eventType.rawValue) Option")
            }
        }
    }

    private var options: [SavedEventOption] {
        store.activeSavedOptions(for: eventType)
    }

    private var icon: String {
        switch eventType {
        case .food:
            return "fork.knife"
        case .medicine:
            return "pills"
        case .litter:
            return "sparkles"
        }
    }

    @ViewBuilder
    private func optionRow(_ option: SavedEventOption) -> some View {
        switch option.data {
        case let .food(food):
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                Text("\(food.foodType.rawValue), \(food.caloriesPerUnit) cal per \(food.unit.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case let .medicine(medicine):
            VStack(alignment: .leading, spacing: 4) {
                Text(medicine.name)
                Text("\(medicine.dosage.formatted()) \(medicine.unit)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SavedOptionsListView(eventType: .food)
            .environmentObject(PetCareStore.preview)
    }
}
