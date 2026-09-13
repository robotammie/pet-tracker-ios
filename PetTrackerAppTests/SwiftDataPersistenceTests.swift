import SwiftData
import XCTest
@testable import PetTrackerApp

final class SwiftDataPersistenceTests: XCTestCase {
    func testPetRepositoryPersistsPet() throws {
        let context = try makeContext()
        let repository = SwiftDataPetRepository(context: context)
        let pet = Pet(name: "Luna", caloriesPerDay: 220)

        repository.savePet(pet)

        XCTAssertEqual(repository.listPets(), [pet])
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

        repository.saveEvent(event)
        repository.deleteEvent(id: event.id)

        XCTAssertTrue(repository.listEvents().isEmpty)
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

        repository.saveSavedOption(option)
        repository.softDeleteSavedOption(id: option.id, at: Date())

        XCTAssertTrue(repository.listSavedOptions().isEmpty)
        XCTAssertEqual(repository.listSavedOptions(includeDeleted: true).count, 1)
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

        repository.saveReminder(reminder)
        repository.muteReminder(id: reminder.id)

        XCTAssertTrue(repository.listReminders().isEmpty)
        XCTAssertEqual(repository.listReminders(includeMuted: true).first?.status, .muted)

        repository.deleteReminder(id: reminder.id)

        XCTAssertTrue(repository.listReminders(includeMuted: true).isEmpty)
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

        repository.saveReminder(reminder)

        let saved = repository.listReminders().first
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

        repository.saveReminder(reminder)

        let saved = try XCTUnwrap(repository.listReminders().first)
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

        repository.saveReminder(reminder)

        XCTAssertEqual(repository.listReminders().first?.ignoredUntil, ignoredUntil)
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
        options.saveSavedOption(food)
        options.saveSavedOption(medicine)
        XCTAssertEqual(Set(options.listSavedOptions(includeDeleted: false)), Set([food, medicine]))
        let event = CareEvent(type: .food, petID: nil, data: .food(FoodEventData(
            name: "Hill's", foodType: .wet, amount: 0.5, unit: .can, calories: 45)))
        events.saveEvent(event)
        var edited = food
        edited.data = .food(SavedFoodData(name: "New display name", unit: .can,
                                         caloriesPerUnit: 100, foodType: .wet, officialName: "New official name"))
        options.saveSavedOption(edited)
        XCTAssertEqual(events.listEvents(), [event])
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
