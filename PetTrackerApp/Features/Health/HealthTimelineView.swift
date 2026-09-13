import SwiftUI

struct HealthEditorRoute: Identifiable {
    let id = UUID()
    var entry: HealthEntry?
    var petID: UUID?
}

struct HealthSummaryRow: View {
    let entry: HealthEntry
    let petName: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.data.category.systemImage).frame(width: 24).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(petName).font(.caption).foregroundStyle(.secondary)
                Text(entry.summary)
                Text(entry.data.category.rawValue + " · " + entry.happenedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if !entry.notes.isEmpty { Text(entry.notes).font(.footnote).lineLimit(2).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 2)
    }
}

struct HealthTimelineView: View {
    @EnvironmentObject private var store: PetCareStore
    let pet: Pet
    @State private var category: HealthCategory?
    @State private var editorRoute: HealthEditorRoute?

    private var sections: [(day: Date, entries: [HealthEntry])] {
        let entries = store.healthEntries(for: pet.id).filter { category == nil || $0.data.category == category }
        return Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.happenedAt) }
            .map { (day: $0.key, entries: $0.value.sorted { $0.happenedAt > $1.happenedAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            Section {
                Picker("Category", selection: $category) {
                    Text("All health").tag(Optional<HealthCategory>.none)
                    ForEach(HealthCategory.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                .accessibilityIdentifier("healthTimeline.category")
            }
            if sections.isEmpty {
                ContentUnavailableView(category == nil ? "No health entries yet" : "No matching health entries", systemImage: "heart.text.square",
                    description: Text("Record weight, vet visits, procedures, or general notes for \(pet.name)."))
            }
            ForEach(sections, id: \.day) { section in
                Section(section.day.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach(section.entries) { entry in
                        Button { editorRoute = HealthEditorRoute(entry: entry, petID: pet.id) } label: {
                            HealthSummaryRow(entry: entry, petName: pet.name)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("healthTimeline.edit.\(entry.id)")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editorRoute = HealthEditorRoute(petID: pet.id) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add health entry").accessibilityIdentifier("healthTimeline.add")
            }
        }
        .sheet(item: $editorRoute) { route in
            HealthEntryEditorView(entry: route.entry, petID: route.petID)
        }
    }
}
