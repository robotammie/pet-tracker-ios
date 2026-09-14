import SwiftData
import XCTest
@testable import PetTrackerApp

final class SwiftDataPersistenceTests: XCTestCase {
    func testPetRepositoryPersistsPet() throws {
        let context = try makeContext()
        let repository = SwiftDataPetRepository(context: context)
        let pet = Pet(name: "Luna", caloriesPerDay: 220)

        try repository.savePet(pet)

        XCTAssertEqual(try repository.listPets(), [pet])
    }

    func testEventRepositoryHardDeletesEvent() throws {
        let context = try makeContext()
        let repository = SwiftDataCareEventRepository(context: context)
        let event = CareEvent(
            type: .food,
            petID: UUID(),
            data: .food(FoodEventData(
                name: "Dinner",
                foodType: .dry,
                amount: 0.5,
                unit: .cup,
                calories: 120
            ))
        )

        try repository.saveEvent(event)
        try repository.deleteEvent(id: event.id)

        XCTAssertTrue(try repository.listEvents().isEmpty)
    }

    func testSavedOptionRepositorySoftDeletesOption() throws {
        let context = try makeContext()
        let repository = SwiftDataSavedEventOptionRepository(context: context)
        let option = SavedEventOption(
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Hills Dry",
                unit: .cup,
                caloriesPerUnit: 381,
                foodType: .dry
            ))
        )

        try repository.saveSavedOption(option)
        try repository.softDeleteSavedOption(id: option.id, at: Date())

        XCTAssertTrue(try repository.listSavedOptions().isEmpty)
        XCTAssertEqual(try repository.listSavedOptions(includeDeleted: true).count, 1)
    }

    func testReminderRepositoryMutesAndHardDeletesReminder() throws {
        let context = try makeContext()
        let repository = SwiftDataReminderRepository(context: context)
        let reminder = Reminder(
            title: "Clean fountain",
            mode: .pureReminder,
            eventType: nil,
            dueAt: Date(),
            dueStyle: .dayOnly
        )

        try repository.saveReminder(reminder)
        try repository.muteReminder(id: reminder.id)

        XCTAssertTrue(try repository.listReminders().isEmpty)
        XCTAssertEqual(try repository.listReminders(includeMuted: true).first?.status, .muted)

        try repository.deleteReminder(id: reminder.id)

        XCTAssertTrue(try repository.listReminders(includeMuted: true).isEmpty)
    }

    func testReminderRepositoryPersistsEventData() throws {
        let context = try makeContext()
        let repository = SwiftDataReminderRepository(context: context)
        let petID = UUID()
        let reminder = Reminder(
            title: "Breakfast",
            mode: .reminderToEvent,
            eventType: .food,
            eventPetID: petID,
            eventData: .food(FoodEventData(
                name: "Hills Dry",
                foodType: .dry,
                amount: 0.25,
                unit: .cup,
                calories: 95
            )),
            dueAt: Date(),
            dueStyle: .timestamp
        )

        try repository.saveReminder(reminder)

        let saved = try repository.listReminders().first
        XCTAssertEqual(saved?.eventPetID, petID)
        XCTAssertEqual(saved?.eventData, reminder.eventData)
    }

    func testReminderRepositoryPersistsMultiPetTargets() throws {
        let context = try makeContext()
        let repository = SwiftDataReminderRepository(context: context)
        let appaID = UUID()
        let momoID = UUID()
        let reminder = Reminder(
            title: "Dinner",
            mode: .reminderToEvent,
            eventType: .food,
            eventData: .food(FoodEventData(
                name: "Wet Food",
                foodType: .wet,
                amount: 1,
                unit: .ounce,
                calories: 30
            )),
            dueAt: Date(),
            dueStyle: .timestamp,
            targets: [
                ReminderTarget(
                    petID: appaID,
                    eventData: .food(FoodEventData(
                        name: "Wet Food",
                        foodType: .wet,
                        amount: 2,
                        unit: .ounce,
                        calories: 60
                    ))
                ),
                ReminderTarget(
                    petID: momoID,
                    eventData: .food(FoodEventData(
                        name: "Wet Food",
                        foodType: .wet,
                        amount: 1,
                        unit: .ounce,
                        calories: 30
                    )),
                    completedAt: Date()
                )
            ]
        )

        try repository.saveReminder(reminder)

        let saved = try XCTUnwrap(try repository.listReminders().first)
        XCTAssertEqual(saved.targets.count, 2)

        let targetsByPetID = Dictionary(uniqueKeysWithValues: saved.targets.map { ($0.petID, $0) })
        XCTAssertEqual(targetsByPetID[appaID]?.eventData, reminder.targets.first?.eventData)
        XCTAssertEqual(targetsByPetID[momoID]?.eventData, reminder.targets.last?.eventData)
        XCTAssertNotNil(targetsByPetID[momoID]?.completedAt)
    }

    func testReminderRepositoryPersistsIgnoredUntil() throws {
        let context = try makeContext()
        let repository = SwiftDataReminderRepository(context: context)
        let ignoredUntil = Date(timeIntervalSince1970: 1_000)
        let reminder = Reminder(
            title: "Medicine",
            mode: .pureReminder,
            eventType: .medicine,
            dueAt: Date(timeIntervalSince1970: 500),
            dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil),
            ignoredUntil: ignoredUntil
        )

        try repository.saveReminder(reminder)

        XCTAssertEqual(try repository.listReminders().first?.ignoredUntil, ignoredUntil)
    }

    func testOptionMetadataAndCanUnitRoundTripWithoutChangingEventSnapshots() throws {
        let context = try makeContext()
        let options = SwiftDataSavedEventOptionRepository(context: context)
        let events = SwiftDataCareEventRepository(context: context)
        let food = SavedEventOption(eventType: .food, data: .food(SavedFoodData(
            name: "Hill's", unit: .can, caloriesPerUnit: 90, foodType: .wet,
            officialName: "Hill's Gastrointestinal Biome for Adult Cats")))
        let medicine = SavedEventOption(eventType: .medicine, data: .medicine(SavedMedicineData(
            name: "Pill", dosage: 1, unit: "tablet", purpose: "Antibiotic")))
        try options.saveSavedOption(food)
        try options.saveSavedOption(medicine)
        XCTAssertEqual(Set(try options.listSavedOptions(includeDeleted: false)), Set([food, medicine]))
        let event = CareEvent(type: .food, petID: nil, data: .food(FoodEventData(
            name: "Hill's", foodType: .wet, amount: 0.5, unit: .can, calories: 45)))
        try events.saveEvent(event)
        var edited = food
        edited.data = .food(SavedFoodData(name: "New display name", unit: .can,
                                         caloriesPerUnit: 100, foodType: .wet, officialName: "New official name"))
        try options.saveSavedOption(edited)
        XCTAssertEqual(try events.listEvents(), [event])
    }

    func testPopulatedStageFiveStoreCopyOpensWithoutResettingHistory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let original = root.appendingPathComponent("original")
        let copy = root.appendingPathComponent("copy")
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pet = Pet(name: "Upgrade cat", caloriesPerDay: 240)
        let event = CareEvent(type: .food, petID: pet.id,
            data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 90)))
        let option = SavedEventOption(eventType: .medicine,
            data: .medicine(SavedMedicineData(name: "Medication", dosage: 1, unit: "tablet",
                doseInterval: MedicationDoseInterval(minimumHours: 8, maximumHours: 12))))
        let reminder = Reminder(title: "Recorded completion", mode: .reminderToEvent, eventType: .food,
            dueAt: event.startTime, dueStyle: .timestamp, status: .completed,
            targets: [ReminderTarget(petID: pet.id, eventData: event.data, completedAt: event.startTime)],
            completedAt: event.startTime)
        let health = HealthEntry(petID: pet.id, title: "Weight", notes: "Keep this history",
            data: .weight(WeightMeasurement(value: 9.5, unit: .pound)))
        do {
            // Stage 5 used this unversioned schema and automatic container discovery.
            let legacySchema = Schema([PetRecord.self, HealthEntryRecord.self, CareEventRecord.self,
                SavedEventOptionRecord.self, ReminderRecord.self, ReminderTargetRecord.self])
            let container = try ModelContainer(for: legacySchema, configurations: [
                ModelConfiguration(schema: legacySchema, url: original.appendingPathComponent("default.store"))])
            let context = ModelContext(container)
            try SwiftDataPetRepository(context: context).savePet(pet)
            try SwiftDataCareEventRepository(context: context).saveEvent(event)
            try SwiftDataSavedEventOptionRepository(context: context).saveSavedOption(option)
            try SwiftDataReminderRepository(context: context).saveReminder(reminder)
            try SwiftDataHealthEntryRepository(context: context).saveHealthEntry(health)
        }
        // Exercise a copy, never a user's simulator store; include SQLite sidecars.
        try FileManager.default.copyItem(at: original, to: copy)
        let container = try LocalPersistence.makeContainer(url: copy.appendingPathComponent("default.store"))
        let context = ModelContext(container)
        XCTAssertEqual(try SwiftDataPetRepository(context: context).listPets(), [pet])
        XCTAssertEqual(try SwiftDataCareEventRepository(context: context).listEvents(), [event])
        XCTAssertEqual(try SwiftDataSavedEventOptionRepository(context: context).listSavedOptions(includeDeleted: true), [option])
        XCTAssertEqual(try SwiftDataReminderRepository(context: context).listReminders(includeMuted: true), [reminder])
        XCTAssertEqual(try SwiftDataHealthEntryRepository(context: context).listHealthEntries(), [health])
    }

    func testUnreadableStoredRecordThrowsAndStillCountsAsExistingData() throws {
        let context = ModelContext(try LocalPersistence.makeContainer(inMemory: true))
        context.insert(CareEventRecord(typeRawValue: "Unknown future type", petID: nil, createdAt: .now, startTime: .now))
        try context.save()
        XCTAssertTrue(try LocalPersistence.hasRecords(context: context))
        XCTAssertThrowsError(try SwiftDataCareEventRepository(context: context).listEvents())
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CareEventRecord>()), 1)
    }

    func testMultiRecordTransactionRollsBackAllChangesOnFailure() throws {
        struct Failure: Error {}
        let container = try LocalPersistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let pets = SwiftDataPetRepository(context: context, savesImmediately: false)
        let events = SwiftDataCareEventRepository(context: context, savesImmediately: false)
        XCTAssertThrowsError(try LocalPersistence.transaction(context: context) {
            try pets.savePet(Pet(name: "Unsaved"))
            try events.saveEvent(CareEvent(type: .litter, petID: nil, data: .litter(LitterEventData())))
            throw Failure()
        })
        XCTAssertTrue(try pets.listPets().isEmpty)
        XCTAssertTrue(try events.listEvents().isEmpty)
        XCTAssertTrue(try SwiftDataPetRepository(context: ModelContext(container)).listPets().isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            PetRecord.self,
            CareEventRecord.self,
            SavedEventOptionRecord.self,
            ReminderRecord.self,
            ReminderTargetRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        return ModelContext(container)
    }
}
