import Foundation

enum HealthCategory: String, CaseIterable, Identifiable, Codable {
    case weight = "Weight"
    case vetVisit = "Vet visit"
    case procedure = "Procedure"
    case generalNote = "General note"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .weight: "scalemass"
        case .vetVisit: "stethoscope"
        case .procedure: "cross.case"
        case .generalNote: "note.text"
        }
    }
}

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case kilogram = "kg"
    case pound = "lb"
    var id: String { rawValue }
}

struct WeightMeasurement: Hashable, Codable {
    var value: Double
    var unit: WeightUnit
    var isValid: Bool { value.isFinite && value > 0 }
}

enum HealthEntryData: Hashable, Codable {
    case weight(WeightMeasurement)
    case vetVisit
    case procedure
    case generalNote

    var category: HealthCategory {
        switch self {
        case .weight: .weight
        case .vetVisit: .vetVisit
        case .procedure: .procedure
        case .generalNote: .generalNote
        }
    }
}

struct HealthEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var petID: UUID
    var happenedAt: Date
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var notes: String
    var clinic: String
    var provider: String
    var data: HealthEntryData

    init(id: UUID = UUID(), petID: UUID, happenedAt: Date = .now, createdAt: Date = .now,
         updatedAt: Date = .now, title: String, notes: String = "", clinic: String = "",
         provider: String = "", data: HealthEntryData) {
        self.id = id
        self.petID = petID
        self.happenedAt = happenedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.notes = notes
        self.clinic = clinic
        self.provider = provider
        self.data = data
    }

    var summary: String {
        if case let .weight(measurement) = data {
            return "\(title) · \(measurement.value.formatted()) \(measurement.unit.rawValue)"
        }
        return title
    }

    var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              happenedAt.timeIntervalSinceReferenceDate.isFinite else { return false }
        if case let .weight(measurement) = data { return measurement.isValid }
        return true
    }
}

struct HealthEntryDraft {
    let original: HealthEntry?
    var petID: UUID?
    var happenedAt: Date
    var category: HealthCategory
    var title: String
    var notes: String
    var clinic: String
    var provider: String
    var weight: Double
    var weightUnit: WeightUnit

    init(entry: HealthEntry? = nil, petID: UUID? = nil, defaultWeightUnit: WeightUnit = .pound) {
        original = entry
        self.petID = entry?.petID ?? petID
        happenedAt = entry?.happenedAt ?? .now
        category = entry?.data.category ?? .weight
        title = entry?.title ?? "Weight"
        notes = entry?.notes ?? ""
        clinic = entry?.clinic ?? ""
        provider = entry?.provider ?? ""
        weight = 0
        weightUnit = defaultWeightUnit
        if case let .weight(measurement) = entry?.data {
            weight = measurement.value
            weightUnit = measurement.unit
        }
    }

    func makeEntry(pets: [Pet], now: Date = .now) -> HealthEntry? {
        guard let petID, pets.contains(where: { $0.id == petID }) else { return nil }
        let data: HealthEntryData = switch category {
        case .weight: .weight(WeightMeasurement(value: weight, unit: weightUnit))
        case .vetVisit: .vetVisit
        case .procedure: .procedure
        case .generalNote: .generalNote
        }
        let entry = HealthEntry(id: original?.id ?? UUID(), petID: petID, happenedAt: happenedAt,
            createdAt: original?.createdAt ?? now, updatedAt: now,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes,
            clinic: clinic.trimmingCharacters(in: .whitespacesAndNewlines),
            provider: provider.trimmingCharacters(in: .whitespacesAndNewlines), data: data)
        return entry.isValid ? entry : nil
    }
}

struct RecentHealthKey: Hashable {
    var petID: UUID
    var category: HealthCategory
}

enum HealthRecentService {
    static func entries(_ entries: [HealthEntry], now: Date = .now, calendar: Calendar = .current) -> [HealthEntry] {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return Dictionary(grouping: entries.filter { $0.happenedAt >= cutoff && $0.happenedAt <= now }) {
            RecentHealthKey(petID: $0.petID, category: $0.data.category)
        }.values.compactMap { $0.max { $0.happenedAt < $1.happenedAt } }
            .sorted { $0.happenedAt > $1.happenedAt }
    }
}
