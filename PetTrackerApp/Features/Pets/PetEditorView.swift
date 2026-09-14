import SwiftUI

struct PetEditorRoute: Identifiable {
    let id = UUID()
    var pet: Pet?
}

struct PetEditDraft {
    let id: UUID
    var name: String
    var calorieGoal: String

    init(pet: Pet? = nil) {
        id = pet?.id ?? UUID()
        name = pet?.name ?? ""
        calorieGoal = pet?.caloriesPerDay.map(String.init) ?? ""
    }

    func makePet() -> Pet? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = calorieGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if goal.isEmpty { return Pet(id: id, name: name) }
        guard let calories = Int(goal), calories > 0 else { return nil }
        return Pet(id: id, name: name, caloriesPerDay: calories)
    }
}

struct PetEditorView: View {
    @EnvironmentObject private var store: PetCareStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PetEditDraft
    private let isEditing: Bool

    init(pet: Pet? = nil) {
        isEditing = pet != nil
        _draft = State(initialValue: PetEditDraft(pet: pet))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                    .frame(minHeight: 44).accessibilityIdentifier("petEditor.name")
                Section("Daily calorie goal") {
                    TextField("Calories (optional)", text: $draft.calorieGoal)
                        .keyboardType(.numberPad).frame(minHeight: 44)
                        .accessibilityIdentifier("petEditor.calories")
                    Text("Leave blank for no daily goal.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit Pet" : "Add Pet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("petEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let pet = draft.makePet() else { return }
                        store.savePetAndRefresh(pet)
                        dismiss()
                    }
                    .disabled(draft.makePet() == nil).accessibilityIdentifier("petEditor.save")
                }
            }
        }
    }
}
