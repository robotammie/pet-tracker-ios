import SwiftUI

struct ReminderSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let reminder: Reminder
    var now: Date = .now
    var showsEventIcon = false
    var rowAccessibilityIdentifier: String?
    var onSelect: (() -> Void)?
    var onCompleteNow: (() -> Void)?

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize && onCompleteNow != nil
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            if let onSelect {
                Button(action: onSelect) {
                    summaryContent
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens reminder editor")
            } else {
                summaryContent
            }

            if let onCompleteNow {
                Button(action: onCompleteNow) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Complete \(reminder.title) now")
                .accessibilityHint(reminder.targets.count > 1 ? "Completes all remaining pets at the current time" : "Uses the current time")
                .accessibilityIdentifier("reminder.completeNow.\(reminder.id.uuidString)")
            }
        }
        .padding(.vertical, 2)
    }

    private var summaryContent: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsEventIcon, let eventType = reminder.eventType {
                Image(systemName: eventType.homeSystemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                            .font(.headline)
                        statusText
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(reminder.title)
                            .font(.headline)
                        Spacer()
                        statusText
                    }
                }

                Text([reminder.mode.rawValue, reminder.eventType?.rawValue]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(rowAccessibilityIdentifier ?? "")
    }

    private var statusText: some View {
        Group {
            if reminder.isOverdue(now: now) {
                RelativeTimeText(date: reminder.displayDueAt(now: now))
                    .foregroundStyle(.red)
            } else {
                RelativeTimeText(date: reminder.displayDueAt(now: now))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.medium))
    }
}

private struct ReminderDeletionAlert: ViewModifier {
    @EnvironmentObject private var store: PetCareStore
    @Binding var reminder: Reminder?

    func body(content: Content) -> some View {
        content
        .alert("Delete reminder?", isPresented: Binding(
            get: { reminder != nil },
            set: { if !$0 { reminder = nil } }
        ), presenting: reminder) { reminder in
            if reminder.isRecurring {
                Button("Delete This Occurrence", role: .destructive) {
                    store.deleteReminderOccurrenceAndRefresh(reminder)
                }
                .accessibilityIdentifier("reminder.deleteOccurrence")
                Button("Delete All", role: .destructive) {
                    store.deleteReminderSeriesAndRefresh(reminder)
                }
                .accessibilityIdentifier("reminder.deleteAll")
            } else {
                Button("Delete Reminder", role: .destructive) {
                    store.deleteReminderAndRefresh(id: reminder.id)
                }
                .accessibilityIdentifier("reminder.confirmDelete")
            }
            Button("Cancel", role: .cancel) { }
        } message: { reminder in
            if reminder.isRecurring {
                Text("Delete this occurrence and keep the series, or delete the series and all of its completed reminder history. Logged care events are kept.")
            } else {
                Text("This removes the reminder. Logged care events are kept.")
            }
        }
    }
}

extension View {
    func reminderDeletionAlert(reminder: Binding<Reminder?>) -> some View {
        modifier(ReminderDeletionAlert(reminder: reminder))
    }
}
