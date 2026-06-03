import Foundation

extension Array where Element == CareEvent {
    func groupedByDay(calendar: Calendar = .current) -> [(day: Date, events: [CareEvent])] {
        let grouped = Dictionary(grouping: self) { event in
            calendar.startOfDay(for: event.startTime)
        }

        return grouped
            .map { day, events in
                (
                    day: day,
                    events: events.sorted { $0.startTime > $1.startTime }
                )
            }
            .sorted { $0.day > $1.day }
    }
}
