import XCTest
import SwiftData
@testable import PetTrackerApp

final class CareEventDeletionTests: XCTestCase {
    func testDeleteUpdatesPetCaloriesWithoutChangingHealthOrReminderHistory() {
        let pet = Pet(name: "Cat")
        let food = CareEvent(type: .food, petID: pet.id, data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 90)))
        let medicine = CareEvent(type: .medicine, petID: pet.id, data: .medicine(MedicineEventData(name: "Medicine", dosage: 1, unit: "mL")))
        let litter = CareEvent(type: .litter, petID: nil, data: .litter(LitterEventData()))
        let reminder = Reminder(title: "Dinner", mode: .pureReminder, eventType: nil, dueAt: .now, dueStyle: .timestamp, status: .completed, completedAt: .now)
        let health = HealthEntry(petID: pet.id, title: "Healthy", data: .generalNote)
        let store = PetCareStore(pets: [pet], events: [food, medicine, litter], healthEntries: [health], reminders: [reminder])
        XCTAssertEqual(store.calories(for: pet, on: food.startTime), 90)
        store.deleteCareEventAndRefresh(id: food.id)
        XCTAssertEqual(store.calories(for: pet, on: food.startTime), 0)
        XCTAssertEqual(store.events, [medicine, litter])
        store.deleteCareEventAndRefresh(id: medicine.id)
        store.deleteCareEventAndRefresh(id: litter.id)
        store.deleteCareEventAndRefresh(id: litter.id)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.reminders, [reminder])
        XCTAssertEqual(store.healthEntries, [health])
    }

    func testRepositoryDeletionRefreshesStoreAndRemovesOnlySelectedEvent() throws {
        let schema = Schema([CareEventRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let repository = SwiftDataCareEventRepository(context: ModelContext(container))
        let first = CareEvent(type: .litter, petID: nil, data: .litter(LitterEventData()))
        let second = CareEvent(type: .litter, petID: nil, data: .litter(LitterEventData()))
        repository.saveEvent(first)
        repository.saveEvent(second)
        let backing = PetCareStore()
        let store = PetCareStore()
        store.configurePersistence(petRepository: backing, eventRepository: repository, savedOptionRepository: backing, reminderRepository: backing)
        store.refreshFromPersistence()
        store.deleteCareEventAndRefresh(id: first.id)
        XCTAssertEqual(repository.listEvents(), [second])
        XCTAssertEqual(store.events, [second])
    }
}
