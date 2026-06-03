import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var store: PetCareStore
    @State private var completionDraft: ReminderCompletionDraft?
    @State private var ignoreDraft: ReminderIgnoreDraft?
    @State private var isCompletedExpanded = false

    var body: some View {
        List {
            Section("Active") {
                if activeReminders.isEmpty {
                    ContentUnavailableView("No active reminders", systemImage: "bell.slash")
                } else {
                    ForEach(activeReminders) { reminder in
                        ReminderSummaryRow(reminder: reminder)
                            .swipeActions(edge: .trailing) {
                                Button("Done") {
                                    startCompletion(reminder)
                                }
                                .tint(.green)

                                Button("Ignore") {
                                    ignoreDraft = ReminderIgnoreDraft(reminder: reminder)
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading) {
                                Button("Mute") {
                                    store.muteReminderAndRefresh(id: reminder.id)
                                }
                                .tint(.gray)

                                Button("Delete", role: .destructive) {
                                    store.deleteReminderAndRefresh(id: reminder.id)
                                }
                            }
                    }
                }
            }

            Section {
                DisclosureGroup(isExpanded: $isCompletedExpanded) {
                    if completedReminders.isEmpty {
                        Text("No completed reminders")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(completedReminders) { reminder in
                            ReminderSummaryRow(reminder: reminder)
                        }
                    }
                } label: {
                    Text("Completed")
                }
            }
        }
        .navigationTitle("Reminders")
        .sheet(item: $completionDraft) { draft in
            ReminderCompletionSheet(draft: draft)
                .environmentObject(store)
        }
        .sheet(item: $ignoreDraft) { draft in
            ReminderIgnoreSheet(draft: draft)
                .environmentObject(store)
        }
    }

    private var activeReminders: [Reminder] {
        store.reminders
            .filter(\.isActive)
            .sorted { $0.dueAt < $1.dueAt }
    }

    private var completedReminders: [Reminder] {
        store.reminders
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.dueAt) > ($1.completedAt ?? $1.dueAt) }
    }

    private func startCompletion(_ reminder: Reminder) {
        let targetIDs = Set(reminder.incompleteTargets.map(\.petID))

        if reminder.mode == .pureReminder && targetIDs.count <= 1 {
            store.completeReminderAndRefresh(
                reminder,
                completedPetIDs: targetIDs,
                completionTime: .now,
                createsEvent: false
            )
        } else {
            completionDraft = ReminderCompletionDraft(reminder: reminder)
        }
    }
}

struct ReminderCompletionDraft: Identifiable {
    let id = UUID()
    var reminder: Reminder
}

private struct ReminderCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    let draft: ReminderCompletionDraft
    @State private var selectedPetIDs: Set<UUID>
    @State private var completionTime: Date = .now

    init(draft: ReminderCompletionDraft) {
        self.draft = draft
        _selectedPetIDs = State(initialValue: Set(draft.reminder.incompleteTargets.map(\.petID)))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !draft.reminder.incompleteTargets.isEmpty {
                    Section("Completed Pets") {
                        ForEach(draft.reminder.incompleteTargets) { target in
                            Button {
                                toggle(target.petID)
                            } label: {
                                HStack {
                                    Text(petName(for: target.petID))
                                    Spacer()
                                    if selectedPetIDs.contains(target.petID) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                if draft.reminder.mode == .reminderToEvent {
                    Section("Event Time") {
                        DatePicker("Completed at", selection: $completionTime)
                    }
                }
            }
            .navigationTitle("Mark Complete")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.completeReminderAndRefresh(
                            draft.reminder,
                            completedPetIDs: selectedPetIDs,
                            completionTime: completionTime,
                            createsEvent: draft.reminder.mode == .reminderToEvent
                        )
                        dismiss()
                    }
                    .disabled(!canComplete)
                }
            }
        }
    }

    private var canComplete: Bool {
        draft.reminder.incompleteTargets.isEmpty || !selectedPetIDs.isEmpty
    }

    private func petName(for petID: UUID) -> String {
        store.petName(for: petID)
    }

    private func toggle(_ petID: UUID) {
        if selectedPetIDs.contains(petID) {
            selectedPetIDs.remove(petID)
        } else {
            selectedPetIDs.insert(petID)
        }
    }
}

struct ReminderIgnoreDraft: Identifiable {
    let id = UUID()
    var reminder: Reminder
}

private struct ReminderIgnoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetCareStore
    let draft: ReminderIgnoreDraft
    @State private var ignoreUntil: Date
    @State private var updateFutureNotifications = false

    init(draft: ReminderIgnoreDraft) {
        self.draft = draft
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        _ignoreUntil = State(initialValue: tomorrow)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ignore Until") {
                    Button("Later today") {
                        ignoreUntil = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
                    }

                    Button("Tomorrow") {
                        ignoreUntil = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    }

                    DatePicker("Custom", selection: $ignoreUntil)
                }

                if draft.reminder.isRecurring {
                    Section {
                        Toggle("Update future notifications", isOn: $updateFutureNotifications)
                    }
                }
            }
            .navigationTitle("Ignore Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Ignore") {
                        store.ignoreReminderAndRefresh(
                            draft.reminder,
                            until: ignoreUntil,
                            updateFutureNotifications: updateFutureNotifications
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(PetCareStore.preview)
    }
}
