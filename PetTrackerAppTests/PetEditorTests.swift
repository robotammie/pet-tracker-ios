import XCTest
import SwiftData
@testable import PetTrackerApp

final class PetEditorTests: XCTestCase {
    func testDraftTrimsNameAndValidatesOptionalPositiveIntegerGoal() {
        var draft = PetEditDraft()
        XCTAssertNil(draft.makePet())
        draft.name = "  Cat  "
        XCTAssertEqual(draft.makePet()?.name, "Cat")
        XCTAssertNil(draft.makePet()?.caloriesPerDay)
        for invalid in ["0", "-1", "1.5", "abc"] {
            draft.calorieGoal = invalid
            XCTAssertNil(draft.makePet())
        }
        draft.calorieGoal = " 250 "
        XCTAssertEqual(draft.makePet()?.caloriesPerDay, 250)
    }

    func testPetEditPreservesLinkedCareHealthAndReminderTargets() throws {
        let pet = Pet(name: "Cat", caloriesPerDay: 200)
        let health = HealthEntry(petID: pet.id, title: "Note", data: .generalNote)
        let care = CareEvent(type: .food, petID: pet.id, data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 90)))
        let store = PetCareStore(pets: [pet], events: [care], healthEntries: [health])
        var draft = PetEditDraft(pet: pet)
        draft.name = "Renamed"
        draft.calorieGoal = ""
        let edited = try XCTUnwrap(draft.makePet())
        store.savePetAndRefresh(edited)
        XCTAssertEqual(store.pets, [edited])
        XCTAssertEqual(edited.id, pet.id)
        XCTAssertEqual(store.events, [care])
        XCTAssertEqual(store.healthEntries(for: pet.id), [health])
        XCTAssertEqual(store.calories(for: edited, on: care.startTime), 90)
    }

    func testRepositoryBackedAddAndEditPersistWithStableIdentity() throws {
        let schema = Schema([PetRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let repository = SwiftDataPetRepository(context: ModelContext(container))
        let backing = PetCareStore()
        let store = PetCareStore()
        store.configurePersistence(petRepository: repository, eventRepository: backing, savedOptionRepository: backing, reminderRepository: backing)
        let original = Pet(name: "New", caloriesPerDay: 200)
        store.savePetAndRefresh(original)
        var edited = original
        edited.name = "Edited"
        edited.caloriesPerDay = nil
        store.savePetAndRefresh(edited)
        XCTAssertEqual(try repository.listPets(), [edited])
        XCTAssertEqual(store.pets, [edited])
    }
}
