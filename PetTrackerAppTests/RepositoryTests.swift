import XCTest
@testable import PetTrackerApp

final class RepositoryTests: XCTestCase {
    func testDeletingRecurringOccurrenceAdvancesFromScheduledDueTimeWithoutHistory() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dueAt = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: 2026, month: 9, day: 15, hour: 8
        )))
        let reminder = Reminder(
            title: "Feed cats",
            mode: .pureReminder,
            eventType: nil,
            dueAt: dueAt,
            dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil)
        )
        let store = PetCareStore(reminders: [reminder], notificationScheduler: SilentNotificationScheduler())

        XCTAssertTrue(store.deleteReminderOccurrenceAndRefresh(reminder, calendar: calendar))

        XCTAssertEqual(store.reminders.count, 1)
        XCTAssertEqual(store.reminders[0].id, reminder.id)
        XCTAssertEqual(store.reminders[0].dueAt, calendar.date(byAdding: .day, value: 1, to: dueAt))
        XCTAssertTrue(store.reminders[0].isActive)
        XCTAssertTrue(store.reminders.filter { $0.status == .completed }.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
    }

    func testDeleteAllRemovesSeriesHistoryButKeepsLoggedEvents() {
        let dueAt = Date(timeIntervalSince1970: 1_000)
        let active = Reminder(
            title: "Feed cats",
            mode: .pureReminder,
            eventType: nil,
            dueAt: dueAt.addingTimeInterval(86_400),
            dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil)
        )
        let history = Reminder(
            id: SyncIdentity.history(reminderID: active.id, dueAt: dueAt),
            title: active.title,
            mode: active.mode,
            eventType: active.eventType,
            dueAt: dueAt,
            dueStyle: active.dueStyle,
            status: .completed,
            completedAt: dueAt
        )
        let unrelated = Reminder(
            title: "Unrelated",
            mode: .pureReminder,
            eventType: nil,
            dueAt: dueAt,
            dueStyle: .timestamp,
            status: .completed,
            completedAt: dueAt
        )
        let event = CareEvent(
            type: .litter,
            petID: nil,
            startTime: dueAt,
            data: .litter(LitterEventData())
        )
        let store = PetCareStore(
            events: [event],
            reminders: [active, history, unrelated],
            notificationScheduler: SilentNotificationScheduler()
        )

        XCTAssertTrue(store.deleteReminderSeriesAndRefresh(active))

        XCTAssertEqual(store.reminders.map(\.id), [unrelated.id])
        XCTAssertEqual(store.events.map(\.id), [event.id])
    }

    func testInjectedUnitHostAndUITestArgumentsAlwaysUseIsolatedStorage() {
        XCTAssertTrue(UITestConfiguration.enabled(arguments: ["-uiTesting"], isTestHost: false))
        XCTAssertTrue(UITestConfiguration.enabled(arguments: [], isTestHost: true))
        XCTAssertFalse(UITestConfiguration.enabled(arguments: [], isTestHost: false))
        XCTAssertTrue(UITestConfiguration.isEnabled)
        XCTAssertEqual(UITestConfiguration.storeURL.lastPathComponent, "UnitTestHost.store")
        XCTAssertNil(SyncBuildConfiguration.containerIdentifier)
    }

    func testStaleCompletionSheetDoesNotCompleteNextOccurrence() {
        let now = Date(timeIntervalSince1970: 1_000)
        let original = Reminder(title: "Reminder", mode: .pureReminder, eventType: nil,
            dueAt: now, dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil))
        let store = PetCareStore(reminders: [original], notificationScheduler: SilentNotificationScheduler())
        store.completeReminderNowAndRefresh(id: original.id, now: now)
        XCTAssertFalse(store.completeReminderAndRefresh(original, completedPetIDs: [], completionTime: now,
            createsEvent: false))
        XCTAssertEqual(store.reminders.filter { $0.status == .completed }.count, 1)
        XCTAssertNotNil(store.persistenceError)
    }

    func testReschedulingToPreviouslyCompletedDueTimeDoesNotLogAgain() {
        let now = Date(timeIntervalSince1970: 1_000)
        let original = Reminder(title: "Reminder", mode: .pureReminder, eventType: nil,
            dueAt: now, dueStyle: .timestamp,
            schedule: ReminderSchedule(recurrenceRule: .every(value: 1, unit: .day), endDate: nil))
        let store = PetCareStore(reminders: [original], notificationScheduler: SilentNotificationScheduler())
        store.completeReminderNowAndRefresh(id: original.id, now: now)
        var next = store.reminders.first { $0.isActive }!
        next.dueAt = original.dueAt
        store.saveReminderAndRefresh(next)
        XCTAssertFalse(store.completeReminderAndRefresh(next, completedPetIDs: [], completionTime: now,
            createsEvent: false))
        XCTAssertEqual(store.reminders.filter { $0.status == .completed }.count, 1)
        XCTAssertNotNil(store.persistenceError)
    }

    func testFailedFetchPreservesAllDisplayedDataAndShowsError() {
        let pet = Pet(name: "Original")
        let store = PetCareStore(pets: [pet], notificationScheduler: SilentNotificationScheduler())
        store.configurePersistence(petRepository: FailingPetRepository(), eventRepository: PetCareStore(),
            savedOptionRepository: PetCareStore(), reminderRepository: PetCareStore())
        XCTAssertFalse(store.refreshFromPersistence())
        XCTAssertEqual(store.pets, [pet])
        XCTAssertNotNil(store.persistenceError)
    }

    func testFailedPetWriteDoesNotReportSuccessOrNotifySync() {
        let store = PetCareStore(notificationScheduler: SilentNotificationScheduler())
        store.configurePersistence(petRepository: FailingPetRepository(), eventRepository: PetCareStore(),
            savedOptionRepository: PetCareStore(), reminderRepository: PetCareStore())
        var notified = false
        store.onPersistenceChanged = { notified = true }
        XCTAssertFalse(store.savePetAndRefresh(Pet(name: "Unsaved")))
        XCTAssertTrue(store.pets.isEmpty)
        XCTAssertFalse(notified)
        XCTAssertNotNil(store.persistenceError)
    }

    func testInitializationDoesNotReseedEmptyCloudOrPreviouslyInitializedStores() {
        XCTAssertTrue(InitialDataPolicy.shouldSeed(hasLocalData: false, initialized: false, syncConfigured: false))
        XCTAssertFalse(InitialDataPolicy.shouldSeed(hasLocalData: true, initialized: false, syncConfigured: false))
        XCTAssertFalse(InitialDataPolicy.shouldSeed(hasLocalData: false, initialized: true, syncConfigured: false))
        XCTAssertFalse(InitialDataPolicy.shouldSeed(hasLocalData: false, initialized: false, syncConfigured: true))
    }

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

private struct FailingPetRepository: PetRepository {
    struct Failure: Error {}
    func listPets() throws -> [Pet] { throw Failure() }
    func savePet(_ pet: Pet) throws { throw Failure() }
    func deletePet(id: UUID) throws { throw Failure() }
}
