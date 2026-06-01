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

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            PetRecord.self,
            CareEventRecord.self,
            SavedEventOptionRecord.self,
            ReminderRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        return ModelContext(container)
    }
}
