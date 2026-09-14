import SwiftData
import XCTest
@testable import PetTrackerApp

final class HealthEntryTests: XCTestCase {
    private let pet = Pet(name: "Cat")
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func entry(_ category: HealthCategory = .generalNote, petID: UUID? = nil, hours: Double = 0) -> HealthEntry {
        let data: HealthEntryData = switch category {
        case .weight: .weight(WeightMeasurement(value: 9.5, unit: .pound))
        case .vetVisit: .vetVisit
        case .procedure: .procedure
        case .generalNote: .generalNote
        }
        return HealthEntry(petID: petID ?? pet.id, happenedAt: now.addingTimeInterval(hours * 3_600), title: category.rawValue, notes: "Recorded details", clinic: "Clinic", provider: "Vet", data: data)
    }

    func testDraftRequiresPetTitleAndFinitePositiveWeightAndDefaultsToPounds() {
        var draft = HealthEntryDraft()
        XCTAssertEqual(draft.weightUnit, .pound)
        draft.weight = 9.5
        XCTAssertNil(draft.makeEntry(pets: [pet]))
        draft.petID = pet.id
        XCTAssertNotNil(draft.makeEntry(pets: [pet]))
        for invalid in [0.0, -1, .infinity, .nan] {
            draft.weight = invalid
            XCTAssertNil(draft.makeEntry(pets: [pet]))
        }
        draft.category = .generalNote
        draft.title = "  "
        XCTAssertNil(draft.makeEntry(pets: [pet]))
        draft.title = "Recovery"
        XCTAssertNotNil(draft.makeEntry(pets: [pet]))
        draft.petID = UUID()
        XCTAssertNil(draft.makeEntry(pets: [pet]))
    }

    func testEditPreservesIdentityCreationAndExplicitUnitWithoutConversion() throws {
        let original = entry(.weight)
        var draft = HealthEntryDraft(entry: original)
        draft.weightUnit = .kilogram
        draft.happenedAt = now.addingTimeInterval(-3_600)
        let edited = try XCTUnwrap(draft.makeEntry(pets: [pet], now: now))
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.createdAt, original.createdAt)
        XCTAssertEqual(edited.updatedAt, now)
        guard case let .weight(weight) = edited.data else { return XCTFail("Expected weight") }
        XCTAssertEqual(weight.value, 9.5)
        XCTAssertEqual(weight.unit, .kilogram)
    }

    func testRecentKeepsLatestPerPetAndCategoryExcludesOldAndFuture() {
        let otherPet = UUID()
        let old = entry(.weight, hours: -169)
        let first = entry(.weight, hours: -5)
        let latest = entry(.weight, hours: -1)
        let other = entry(.weight, petID: otherPet, hours: -2)
        let note = entry(.generalNote, hours: -3)
        let future = entry(.vetVisit, hours: 1)
        XCTAssertEqual(HealthRecentService.entries([old, first, latest, other, note, future], now: now).map(\.id), [latest.id, other.id, note.id])
    }

    func testHealthStoreUpsertsFiltersAndLeavesCareAndRemindersIndependent() throws {
        let care = CareEvent(type: .food, petID: pet.id, startTime: now,
            data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 90)))
        let reminder = Reminder(title: "Routine", mode: .pureReminder, eventType: nil, dueAt: now, dueStyle: .timestamp)
        let store = PetCareStore(pets: [pet], events: [care], reminders: [reminder])
        var health = entry()
        try store.saveHealthEntryAndRefresh(health)
        health.title = "Corrected"
        try store.saveHealthEntryAndRefresh(health)
        XCTAssertEqual(store.healthEntries(for: pet.id), [health])
        XCTAssertTrue(store.healthEntries(for: UUID()).isEmpty)
        XCTAssertEqual(store.events, [care])
        XCTAssertEqual(store.reminders, [reminder])
        XCTAssertEqual(store.calories(for: pet, on: now), 90)
        XCTAssertThrowsError(try store.saveHealthEntryAndRefresh(entry(petID: UUID())))
    }

    func testFailedRepositorySaveDoesNotPublishAnEntry() {
        let backing = PetCareStore(pets: [pet])
        let store = PetCareStore(pets: [pet])
        store.configurePersistence(petRepository: backing, eventRepository: backing,
            savedOptionRepository: backing, reminderRepository: backing, healthRepository: FailingHealthRepository())
        XCTAssertThrowsError(try store.saveHealthEntryAndRefresh(entry()))
        XCTAssertTrue(store.healthEntries.isEmpty)
    }

    func testRecordCategoryChangeClearsWeightAndRejectsInvalidMeasurements() {
        let record = HealthEntryRecord(entry: entry(.weight))
        record.apply(entry(.procedure))
        XCTAssertNil(record.weightValue)
        XCTAssertNil(record.weightUnitRawValue)
        XCTAssertEqual(record.entry?.data, .procedure)
        record.apply(entry(.weight))
        record.weightValue = 0
        XCTAssertNil(record.entry)
    }

    func testAllCategoriesPersistOnDiskAndEditsUpsertAfterReopening() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("health-test-\(UUID()).store")
        defer {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        let schema = Schema([HealthEntryRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let originals = HealthCategory.allCases.map { entry($0) }
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let repository = SwiftDataHealthEntryRepository(context: ModelContext(container))
            try originals.forEach(repository.saveHealthEntry)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SwiftDataHealthEntryRepository(context: ModelContext(container))
        XCTAssertEqual(Set(try repository.listHealthEntries()), Set(originals))
        var edited = originals[0]
        edited.title = "Corrected weight"
        edited.notes = "At home"
        edited.updatedAt = now
        try repository.saveHealthEntry(edited)
        XCTAssertEqual(try repository.listHealthEntries().count, 4)
        XCTAssertEqual(try repository.listHealthEntries().first { $0.id == edited.id }, edited)
    }
}

private struct FailingHealthRepository: HealthEntryRepository {
    enum Failure: Error { case save }
    func listHealthEntries() -> [HealthEntry] { [] }
    func saveHealthEntry(_ entry: HealthEntry) throws { throw Failure.save }
}
