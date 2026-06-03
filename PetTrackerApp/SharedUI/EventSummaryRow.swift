import SwiftUI

struct EventSummaryRow: View {
    let event: CareEvent
    let petName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                scopeLabel
                Spacer()
                Text(event.startTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            EventSummaryText(event: event)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var scopeLabel: some View {
        if event.petID == nil {
            Label("Household", systemImage: "house")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        } else {
            Text(petName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
