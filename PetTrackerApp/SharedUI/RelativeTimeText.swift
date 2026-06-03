import SwiftUI

struct RelativeTimeText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(relativeText(from: context.date))
                .font(.caption)
        }
    }

    private func relativeText(from now: Date) -> String {
        let interval = date.timeIntervalSince(now)
        let absoluteSeconds = abs(Int(interval.rounded()))

        let units: [(seconds: Int, singular: String, plural: String)] = [
            (7 * 24 * 60 * 60, "week", "weeks"),
            (24 * 60 * 60, "day", "days"),
            (60 * 60, "hour", "hours"),
            (60, "minute", "minutes")
        ]

        guard let unit = units.first(where: { absoluteSeconds >= $0.seconds }) else {
            return "just now"
        }

        let value = absoluteSeconds / unit.seconds
        let label = value == 1 ? unit.singular : unit.plural

        if interval < 0 {
            return "\(value) \(label) ago"
        }

        return "in \(value) \(label)"
    }
}
