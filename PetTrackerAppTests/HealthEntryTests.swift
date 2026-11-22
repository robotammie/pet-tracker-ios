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

    func testHomeRecentIncludesEveryEntryWithin24HoursWithoutCategoryCollapsing() {
        let entries = (0..<15).map { entry(hours: -Double($0)) }
        let boundary = entry(hours: -24)
        let older = entry(hours: -25)
        let future = entry(hours: 1)
        let result = HomeRecentService.items(events: [], health: entries + [boundary, older, future], now: now)
        XCTAssertEqual(result.map(\.id), (entries + [boundary]).map { "health.\($0.id)" })
    }

    func testHomeRecentExtendsToTenAcrossCareAndHealthAndGroupsByLocalDay() {
        let entries = (1...12).map { entry(hours: -Double($0 * 24)) }
        let care = CareEvent(type: .litter, petID: nil, startTime: now, data: .litter(LitterEventData()))
        let result = HomeRecentService.items(events: [care], health: entries, now: now)
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(result.first?.id, "care.\(care.id)")
        XCTAssertEqual(result.last?.id, "health.\(entries[8].id)")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -8 * 3_600)!
        let sections = HomeRecentService.sections(events: [care], health: entries, now: now, calendar: calendar)
        XCTAssertEqual(sections.count, 10)
        XCTAssertEqual(sections.first?.day, calendar.startOfDay(for: now))
        XCTAssertEqual(sections.flatMap { $0.items }.map { $0.id }, result.map(\.id))
        XCTAssertTrue(HomeRecentService.items(events: [], health: [], now: now).isEmpty)
        XCTAssertEqual(HomeRecentService.items(events: [], health: [entries[0]], now: now).count, 1)
    }

    func testHealthDeletePersistsAndKeepsOtherEntries() throws {
        let container = try ModelContainer(for: HealthEntryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let repository = SwiftDataHealthEntryRepository(context: context)
        let first = entry()
        let second = entry(.weight)
        try repository.saveHealthEntry(first)
        try repository.saveHealthEntry(second)
        let backing = PetCareStore(pets: [pet])
        let store = PetCareStore(pets: [pet])
        store.configurePersistence(petRepository: backing, eventRepository: backing,
            savedOptionRepository: backing, reminderRepository: backing, healthRepository: repository)
        XCTAssertTrue(store.refreshFromPersistence())
        XCTAssertTrue(store.deleteHealthEntryAndRefresh(id: first.id))
        XCTAssertEqual(store.healthEntries, [second])
        XCTAssertEqual(try SwiftDataHealthEntryRepository(context: ModelContext(container)).listHealthEntries(), [second])
    }

    func testFailedHealthDeleteKeepsPublishedHistory() {
        let health = entry()
        let backing = PetCareStore(pets: [pet])
        let store = PetCareStore(pets: [pet], healthEntries: [health])
        store.configurePersistence(petRepository: backing, eventRepository: backing,
            savedOptionRepository: backing, reminderRepository: backing, healthRepository: FailingHealthRepository())
        XCTAssertFalse(store.deleteHealthEntryAndRefresh(id: health.id))
        XCTAssertEqual(store.healthEntries, [health])
        XCTAssertNotNil(store.persistenceError)
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
    func deleteHealthEntry(id: UUID) throws { throw Failure.save }
}
