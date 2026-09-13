import XCTest
import SwiftData
@testable import PetTrackerApp

final class CareEventEditDraftTests: XCTestCase {
    func testFoodEditPreservesIdentityHistoryAndAllowsExplicitCalories() throws {
        let event = CareEvent(type: .food, petID: nil, createdAt: Date(timeIntervalSince1970: 100),
            startTime: Date(timeIntervalSince1970: 200), endTime: Date(timeIntervalSince1970: 300),
            data: .food(FoodEventData(name: "Old food", foodType: .wet, amount: 1, unit: .can, calories: 93)))
        var draft = CareEventEditDraft(event: event)
        draft.name = "Corrected food"
        draft.timestamp = Date(timeIntervalSince1970: 400)
        draft.amount = 0.5
        draft.calories = 47
        let edited = try XCTUnwrap(draft.makeEvent(pets: []))
        XCTAssertEqual(edited.id, event.id)
        XCTAssertEqual(edited.createdAt, event.createdAt)
        XCTAssertEqual(edited.endTime, event.endTime)
        XCTAssertEqual(edited.startTime, draft.timestamp)
        guard case let .food(data) = edited.data else { return XCTFail("Expected food") }
        XCTAssertEqual(data.calories, 47)
        XCTAssertNil(data.caloriesPerUnit)
        XCTAssertEqual(event.startTime, Date(timeIntervalSince1970: 200))
    }

    func testStoredRateIsExplicitAndInvalidatedByUnitOrManualCalorieChange() throws {
        let event = CareEvent(type: .food, petID: nil,
            data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 93, caloriesPerUnit: 93)))
        var draft = CareEventEditDraft(event: event)
        draft.amount = 0.5
        XCTAssertEqual(draft.calories, 93)
        draft.recalculateCalories()
        XCTAssertEqual(draft.calories, 47)
        draft.calories = 50
        guard case let .food(data) = draft.makeEvent(pets: [])?.data else { return XCTFail("Expected food") }
        XCTAssertNil(data.caloriesPerUnit)
        draft.foodUnit = .ounce
        XCTAssertNil(draft.storedCalorieRate)
        draft.recalculateCalories()
        XCTAssertEqual(draft.calories, 50)
    }

    func testMedicineValidationAndLitterScope() throws {
        let pet = Pet(name: "Cat")
        let medicine = CareEvent(type: .medicine, petID: pet.id,
            data: .medicine(MedicineEventData(name: "Pill", dosage: 1, unit: "tablet")))
        var draft = CareEventEditDraft(event: medicine)
        XCTAssertTrue(draft.canSave(pets: [pet]))
        draft.petID = nil
        XCTAssertFalse(draft.canSave(pets: [pet]))
        draft.petID = pet.id
        draft.dosage = .nan
        XCTAssertFalse(draft.canSave(pets: [pet]))
        let litter = CareEvent(type: .litter, petID: nil, data: .litter(LitterEventData()))
        var litterDraft = CareEventEditDraft(event: litter)
        litterDraft.petID = pet.id
        XCTAssertNil(litterDraft.makeEvent(pets: [pet])?.petID)
    }

    func testEditUpsertsPersistsAndRefreshesCalorieDayTotals() throws {
        let container = try ModelContainer(for: PetRecord.self, CareEventRecord.self, SavedEventOptionRecord.self,
            ReminderRecord.self, ReminderTargetRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let pets = SwiftDataPetRepository(context: context)
        let events = SwiftDataCareEventRepository(context: context)
        let options = SwiftDataSavedEventOptionRepository(context: context)
        let reminders = SwiftDataReminderRepository(context: context)
        let pet = Pet(name: "Cat")
        pets.savePet(pet)
        let oldDay = Calendar.current.startOfDay(for: .now)
        let newDay = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: oldDay))
        let event = CareEvent(type: .food, petID: pet.id, startTime: oldDay,
            data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 90, caloriesPerUnit: 90)))
        events.saveEvent(event)
        let store = PetCareStore()
        store.configurePersistence(petRepository: pets, eventRepository: events, savedOptionRepository: options, reminderRepository: reminders)
        store.refreshFromPersistence()
        var draft = CareEventEditDraft(event: event)
        draft.timestamp = newDay
        draft.amount = 0.5
        draft.recalculateCalories()
        store.saveCareEventAndRefresh(try XCTUnwrap(draft.makeEvent(pets: [pet])))
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.calories(for: pet, on: oldDay), 0)
        XCTAssertEqual(store.calories(for: pet, on: newDay), 45)
        XCTAssertEqual(events.listEvents().first?.createdAt, event.createdAt)
        guard case let .food(saved) = events.listEvents().first?.data else { return XCTFail("Expected food") }
        XCTAssertEqual(saved.caloriesPerUnit, 90)
    }
}
