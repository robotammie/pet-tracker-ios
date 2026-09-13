import XCTest
@testable import PetTrackerApp

final class RepositoryTests: XCTestCase {
    func testCompleteNowLogsOnlyRemainingPetsAtCurrentTime() {
        let completedPet = UUID()
        let remainingPet = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let payload = CareEventData.medicine(MedicineEventData(name: "Pill", dosage: 1, unit: "tablet"))
        let reminder = Reminder(
            title: "Give medicine", mode: .reminderToEvent, eventType: .medicine,
            dueAt: now.addingTimeInterval(3_600), dueStyle: .timestamp,
            targets: [
                ReminderTarget(petID: completedPet, eventData: payload, completedAt: now.addingTimeInterval(-100)),
                ReminderTarget(petID: remainingPet, eventData: payload)
            ]
        )
        let store = PetCareStore(reminders: [reminder], notificationScheduler: SilentNotificationScheduler())
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events.first?.petID, remainingPet)
        XCTAssertEqual(store.events.first?.startTime, now)
        XCTAssertEqual(store.reminders.first?.status, .completed)
        XCTAssertEqual(store.reminders.first?.completedAt, now)
    }

    func testCompleteNowPureReminderDoesNotLogAnEvent() {
        let now = Date(timeIntervalSince1970: 1_000)
        let reminder = Reminder(title: "Clean fountain", mode: .pureReminder, eventType: nil,
                                dueAt: now, dueStyle: .timestamp)
        let store = PetCareStore(reminders: [reminder], notificationScheduler: SilentNotificationScheduler())
        store.completeReminderNowAndRefresh(id: reminder.id, now: now)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.reminders.first?.completedAt, now)
    }

    func testPetFilterKeepsHouseholdSeparateFromPetEvents() {
        let petID = UUID()
        let household = CareEvent(type: .food, petID: nil,
                                  data: .food(FoodEventData(name: "Food", foodType: .wet, amount: 1, unit: .can, calories: 90)))
        var petEvent = household
        petEvent.petID = petID
        XCTAssertTrue(EventPetFilter.all.includes(household))
        XCTAssertTrue(EventPetFilter.all.includes(petEvent))
        XCTAssertTrue(EventPetFilter.household.includes(household))
        XCTAssertFalse(EventPetFilter.household.includes(petEvent))
        XCTAssertTrue(EventPetFilter.pet(petID).includes(petEvent))
        XCTAssertFalse(EventPetFilter.pet(petID).includes(household))
        XCTAssertFalse(EventPetFilter.pet(UUID()).includes(petEvent))
    }
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

    func testActiveSavedOptionsAreScopedAndExcludeDeleted() {
        let activeFood = SavedEventOption(
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Hills Dry",
                unit: .cup,
                caloriesPerUnit: 381,
                foodType: .dry
            ))
        )
        let deletedFood = SavedEventOption(
            eventType: .food,
            data: .food(SavedFoodData(
                name: "Wet Food",
                unit: .ounce,
                caloriesPerUnit: 25,
                foodType: .wet
            )),
            deletedAt: Date()
        )
        let medicine = SavedEventOption(
            eventType: .medicine,
            data: .medicine(SavedMedicineData(
                name: "Meds",
                dosage: 1,
                unit: "tablet"
            ))
        )
        let store = PetCareStore(savedOptions: [activeFood, deletedFood, medicine])

        XCTAssertEqual(store.activeSavedOptions(for: .food), [activeFood])
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

private struct SilentNotificationScheduler: NotificationScheduling {
    func requestAuthorization() {}
    func sync(reminders: [Reminder], settings: UserSettings) {}
    func resetScheduledNotifications() {}
}
