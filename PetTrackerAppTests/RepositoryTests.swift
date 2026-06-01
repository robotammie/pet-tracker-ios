import XCTest
@testable import PetTrackerApp

final class RepositoryTests: XCTestCase {
    func testMutedReminderIsExcludedUnlessRequested() {
        let active = Reminder(
            title: "Clean fountain",
            mode: .pureReminder,
            eventType: nil,
            dueAt: Date(),
            dueStyle: .dayOnly
        )
        let muted = Reminder(
            title: "Check cabinet",
            mode: .pureReminder,
            eventType: nil,
            dueAt: Date(),
            dueStyle: .dayOnly,
            status: .muted
        )
        let store = PetCareStore(reminders: [active, muted])

        XCTAssertEqual(store.listReminders().map(\.id), [active.id])
        XCTAssertEqual(Set(store.listReminders(includeMuted: true).map(\.id)), [active.id, muted.id])
    }

    func testSavedOptionSoftDeleteKeepsOptionWhenIncludingDeleted() {
        let option = SavedEventOption(
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Hills Dry",
                unit: .cup,
                caloriesPerUnit: 381,
                foodType: .dry
            ))
        )
        let store = PetCareStore(savedOptions: [option])

        store.softDeleteSavedOption(id: option.id, at: Date())

        XCTAssertTrue(store.listSavedOptions().isEmpty)
        XCTAssertEqual(store.listSavedOptions(includeDeleted: true).count, 1)
    }

    func testEventDeleteIsHardDelete() {
        let event = CareEvent(
            type: .litter,
            petID: nil,
            data: .litter(LitterEventData())
        )
        let store = PetCareStore(events: [event])

        store.deleteEvent(id: event.id)

        XCTAssertTrue(store.listEvents().isEmpty)
    }
}
