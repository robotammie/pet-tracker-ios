import SwiftUI

struct ReminderSummaryRow: View {
    let reminder: Reminder
    var now: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(reminder.title)
                    .font(.headline)
                Spacer()
                statusText
            }

            HStack(spacing: 6) {
                Text(reminder.mode.rawValue)
                if let eventType = reminder.eventType {
                    Text(eventType.rawValue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(reminder.dueAt, style: .date)
                + Text(" at ")
                + Text(reminder.dueAt, style: .time)
        }
        .padding(.vertical, 2)
    }

    private var statusText: some View {
        Group {
            if reminder.dueAt < now {
                Text("Overdue")
                    .foregroundStyle(.red)
            } else {
                RelativeTimeText(date: reminder.dueAt)
            }
        }
        .font(.caption.weight(.medium))
    }
}
