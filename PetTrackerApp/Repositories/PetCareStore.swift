import Foundation

final class PetCareStore: ObservableObject {
    @Published var pets: [Pet]
    @Published var events: [CareEvent]
    @Published var reminders: [Reminder]
    @Published var settings: UserSettings

    init(
        pets: [Pet] = [],
        events: [CareEvent] = [],
        reminders: [Reminder] = [],
        settings: UserSettings = .defaults
    ) {
        self.pets = pets
        self.events = events
        self.reminders = reminders
        self.settings = settings
    }

    func petName(for petID: UUID?) -> String {
        guard let petID else {
            return "Household"
        }

        return pets.first(where: { $0.id == petID })?.name ?? "Unknown Pet"
    }

    func events(for pet: Pet) -> [CareEvent] {
        events
            .filter { event in
                switch event.type {
                case .food:
                    return event.petID == pet.id || event.petID == nil
                case .medicine:
                    return event.petID == pet.id
                case .litter:
                    return false
                }
            }
            .sorted { $0.startTime > $1.startTime }
    }

    func calories(for pet: Pet, on day: Date, calendar: Calendar = .current) -> Int {
        events.reduce(0) { total, event in
            guard event.type == .food,
                  event.petID == pet.id,
                  calendar.isDate(event.startTime, inSameDayAs: day),
                  case let .food(data) = event.data
            else {
                return total
            }

            return total + data.calories
        }
    }

    func recentEvents(limit: Int = 5) -> [CareEvent] {
        Array(events.sorted { $0.startTime > $1.startTime }.prefix(limit))
    }

    func upcomingReminders(now: Date = .now) -> [Reminder] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

        return reminders
            .filter { !$0.isCompleted && $0.dueAt <= tomorrow }
            .sorted { $0.dueAt < $1.dueAt }
    }
}
