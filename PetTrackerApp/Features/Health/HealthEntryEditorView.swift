import SwiftUI

struct HealthEntryEditorView: View {
    @EnvironmentObject private var store: PetCareStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HealthEntryDraft
    @State private var saveError: String?

    init(entry: HealthEntry? = nil, petID: UUID? = nil) {
        _draft = State(initialValue: HealthEntryDraft(entry: entry, petID: petID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("For") {
                    if store.pets.isEmpty {
                        Text("Add a pet before recording health entries.")
                    }
                    Picker("Pet", selection: $draft.petID) {
                        Text("Choose pet").tag(Optional<UUID>.none)
                        ForEach(store.pets) { pet in Text(pet.name).tag(Optional(pet.id)) }
                    }
                    .accessibilityIdentifier("healthEditor.pet")
                }
                Section("Entry") {
                    DatePicker("Happened at", selection: $draft.happenedAt)
                        .accessibilityIdentifier("healthEditor.date")
                    Picker("Category", selection: $draft.category) {
                        ForEach(HealthCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("healthEditor.category")
                    .onChange(of: draft.category) { old, new in
                        if draft.title == old.rawValue { draft.title = new.rawValue }
                    }
                    TextField("Title", text: $draft.title)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("healthEditor.title")
                }
                if draft.category == .weight {
                    Section("Weight") {
                        TextField("Weight", value: $draft.weight, format: .number)
                            .keyboardType(.decimalPad).frame(minHeight: 44)
                            .accessibilityLabel("Weight").accessibilityIdentifier("healthEditor.weight")
                        Picker("Unit", selection: $draft.weightUnit) {
                            ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .accessibilityIdentifier("healthEditor.weightUnit")
                        Text("Record the unit used for this measurement. Changing the unit does not convert the value.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8).frame(minHeight: 44)
                        .accessibilityIdentifier("healthEditor.notes")
                }
                Section {
                    DisclosureGroup("Clinic / provider (optional)") {
                        TextField("Clinic", text: $draft.clinic).frame(minHeight: 44)
                            .accessibilityIdentifier("healthEditor.clinic")
                        TextField("Provider", text: $draft.provider).frame(minHeight: 44)
                            .accessibilityIdentifier("healthEditor.provider")
                    }
                }
            }
            .navigationTitle(draft.original == nil ? "Add Health" : "Edit Health")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("healthEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let entry = draft.makeEntry(pets: store.pets) else { return }
                        do { try store.saveHealthEntryAndRefresh(entry); dismiss() }
                        catch { saveError = error.localizedDescription }
                    }
                    .disabled(draft.makeEntry(pets: store.pets) == nil)
                    .accessibilityIdentifier("healthEditor.save")
                }
            }
            .alert("Could not save health entry", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "Please try again.") }
        }
    }
}
