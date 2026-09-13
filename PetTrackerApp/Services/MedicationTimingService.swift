import Foundation

struct MedicationTimingWarning: Equatable {
    var eventID: UUID
    var message: String
}

enum MedicationTimingPresentation {
    case main, eventCreation, eventEditor, reminderCompletion
}

struct MedicationTimingPrompt: Identifiable {
    let id = UUID()
    var warnings: [MedicationTimingWarning]
    var presentation: MedicationTimingPresentation = .main
    var message: String { warnings.map(\.message).joined(separator: "\n\n") }
}

enum MedicationTimingService {
    // A legacy name is linked only if exactly one saved medication (including deleted ones)
    // has that name. Ambiguous matches require acknowledgement instead of asserting safety.
    static func resolved(_ event: CareEvent, options: [SavedEventOption]) -> CareEvent {
        guard case var .medicine(data) = event.data else { return event }
        let medicines = options.filter { $0.eventType == .medicine }
        let matches = medicines.filter { option in
            guard case let .medicine(saved) = option.data else { return false }
            return data.savedOptionID.map { $0 == option.id } ?? (key(saved.name) == key(data.name))
        }
        if matches.count == 1, let option = matches.first, case let .medicine(saved) = option.data {
            data.savedOptionID = option.id
            data.doseInterval = saved.doseInterval(for: event.petID)
        }
        var result = event
        result.data = .medicine(data)
        return result
    }

    static func warnings(for candidates: [CareEvent], existing: [CareEvent], options: [SavedEventOption], pets: [Pet]) -> [MedicationTimingWarning] {
        let replacements = Set(candidates.map(\.id))
        let history = existing.filter { !replacements.contains($0.id) }.map { resolved($0, options: options) }
        let proposed = candidates.map { resolved($0, options: options) }
        return proposed.flatMap { candidate -> [MedicationTimingWarning] in
            guard let petID = candidate.petID, case let .medicine(data) = candidate.data else { return [] }
            let petName = pets.first { $0.id == petID }?.name ?? "Unknown pet"
            guard let medicationID = data.savedOptionID else {
                let timedMatches = options.filter {
                    guard case let .medicine(saved) = $0.data else { return false }
                    return key(saved.name) == key(data.name) && saved.doseInterval(for: petID) != nil
                }
                return timedMatches.isEmpty ? [] : [MedicationTimingWarning(eventID: candidate.id,
                    message: "\(petName): \(data.name) cannot be matched to a unique saved medication. Select its saved medication to check the interval, or log without a verified timing check.")]
            }
            guard let interval = data.doseInterval, interval.isValid else { return [] }
            let allNeighbors = history + proposed.filter { $0.id != candidate.id }
            let ambiguousHistory = allNeighbors.contains { neighbor in
                guard neighbor.petID == petID, case let .medicine(other) = neighbor.data else { return false }
                return other.savedOptionID == nil && key(other.name) == key(data.name)
                    && abs(candidate.startTime.timeIntervalSince(neighbor.startTime)) < interval.minimumHours * 3_600
            }
            let ambiguousWarnings = ambiguousHistory ? [MedicationTimingWarning(eventID: candidate.id,
                message: "\(petName): a nearby historical dose named \(data.name) has ambiguous medication identity. Link that dose to its saved medication, or log without a verified timing check.")] : []
            let neighbors = allNeighbors.filter {
                guard $0.petID == petID, case let .medicine(other) = $0.data else { return false }
                return other.savedOptionID == medicationID
            }
            let preceding = neighbors.filter { $0.startTime <= candidate.startTime }.max { $0.startTime < $1.startTime }
            let following = neighbors.filter { $0.startTime > candidate.startTime }.min { $0.startTime < $1.startTime }
            return ambiguousWarnings + [preceding, following].compactMap { neighbor in
                guard let neighbor else { return nil }
                let gap = abs(candidate.startTime.timeIntervalSince(neighbor.startTime))
                guard gap < interval.minimumHours * 3_600 else { return nil }
                let direction = neighbor.startTime <= candidate.startTime ? "Previous" : "Following"
                return MedicationTimingWarning(eventID: candidate.id,
                    message: "\(petName): \(data.name). \(direction) dose: \(neighbor.startTime.formatted(date: .abbreviated, time: .shortened)). Gap: \((gap / 3_600).formatted()) hours; prescribed minimum: \(interval.minimumHours.formatted()) hours (window: \(interval.summary)).")
            }
        }
    }

    static func nextDoseWindow(for event: CareEvent, options: [SavedEventOption]) -> ClosedRange<Date>? {
        guard case let .medicine(data) = resolved(event, options: options).data,
              let interval = data.doseInterval, interval.isValid else { return nil }
        let earliest = event.startTime.addingTimeInterval(interval.minimumHours * 3_600)
        let latest = event.startTime.addingTimeInterval(interval.maximumHours * 3_600)
        return earliest...latest
    }

    private static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
