import Foundation
import SwiftData

@Model
final class HealthEntryRecord {
    @Attribute(.unique) var id: UUID
    var petID: UUID
    var happenedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var notes: String
    var clinic: String
    var provider: String
    var categoryRawValue: String
    var weightValue: Double?
    var weightUnitRawValue: String?

    init(entry: HealthEntry) {
        id = entry.id
        petID = entry.petID
        happenedAt = entry.happenedAt
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        title = entry.title
        notes = entry.notes
        clinic = entry.clinic
        provider = entry.provider
        categoryRawValue = entry.data.category.rawValue
        apply(entry)
    }

    func apply(_ entry: HealthEntry) {
        petID = entry.petID
        happenedAt = entry.happenedAt
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        title = entry.title
        notes = entry.notes
        clinic = entry.clinic
        provider = entry.provider
        categoryRawValue = entry.data.category.rawValue
        weightValue = nil
        weightUnitRawValue = nil
        if case let .weight(measurement) = entry.data {
            weightValue = measurement.value
            weightUnitRawValue = measurement.unit.rawValue
        }
    }

    var entry: HealthEntry? {
        guard let category = HealthCategory(rawValue: categoryRawValue) else { return nil }
        let data: HealthEntryData
        switch category {
        case .weight:
            guard let value = weightValue, let raw = weightUnitRawValue, let unit = WeightUnit(rawValue: raw) else { return nil }
            data = .weight(WeightMeasurement(value: value, unit: unit))
        case .vetVisit: data = .vetVisit
        case .procedure: data = .procedure
        case .generalNote: data = .generalNote
        }
        let result = HealthEntry(id: id, petID: petID, happenedAt: happenedAt, createdAt: createdAt,
            updatedAt: updatedAt, title: title, notes: notes, clinic: clinic, provider: provider, data: data)
        return result.isValid ? result : nil
    }
}

final class SwiftDataHealthEntryRepository: HealthEntryRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func listHealthEntries() -> [HealthEntry] {
        ((try? context.fetch(FetchDescriptor<HealthEntryRecord>())) ?? []).compactMap(\.entry)
    }

    func saveHealthEntry(_ entry: HealthEntry) throws {
        let records = try context.fetch(FetchDescriptor<HealthEntryRecord>())
        if let record = records.first(where: { $0.id == entry.id }) {
            record.apply(entry)
        } else {
            context.insert(HealthEntryRecord(entry: entry))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
