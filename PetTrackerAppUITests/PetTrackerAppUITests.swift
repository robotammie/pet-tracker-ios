import XCTest

@MainActor
final class PetTrackerAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStartupFailureRetryKeepsExistingTestHistory() {
        let app = launchApp()
        app.buttons["home.quickAdd.Litter"].tap()
        app.buttons["litterCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Litter cleaned"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-uiTesting", "-uiTestingStartupFailure"]
        app.launch()
        XCTAssertTrue(app.buttons["persistence.retry"].waitForExistence(timeout: 8))
        app.buttons["persistence.retry"].tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Litter cleaned"].waitForExistence(timeout: 5))
    }

    func testLaunchShowsPrimaryTabs() {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Pet Tracker"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Events"].exists)
        XCTAssertTrue(app.tabBars.buttons["Pets"].exists)
        XCTAssertTrue(app.tabBars.buttons["Reminders"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testQuickAddFoodPersistsVisibleEvent() {
        let app = launchApp()
        app.buttons["home.quickAdd.Food"].tap()
        app.buttons["foodCreation.savedOption"].tap()
        app.buttons["Breakfast Dry Food"].tap()
        let amount = app.textFields["foodCreation.amount.Household"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("0.5")
        app.buttons["foodCreation.save"].tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food · 0.5 cup"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food · 0.5 cup"].waitForExistence(timeout: 8))
    }

    func testHomeCompleteNowLogsEventWithoutOpeningSheet() {
        let app = launchApp()
        let complete = app.buttons["reminder.completeNow.99999999-9999-9999-9999-999999999999"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        XCTAssertFalse(app.navigationBars["Mark Complete"].exists)
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food · 0.25 cup"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food · 0.25 cup"].waitForExistence(timeout: 8))
    }

    func testHomeEventTapDoesNothingAndSwipeEditDeletePersists() {
        let app = launchApp()
        app.buttons["reminder.completeNow.99999999-9999-9999-9999-999999999999"].tap()
        let row = app.staticTexts["Breakfast Dry Food · 0.25 cup"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].exists)
        row.swipeLeft()
        app.buttons["home.event.edit"].tap()
        replaceText(app.textFields["eventEditor.name"], with: "Edited from Home")
        app.buttons["eventEditor.save"].tap()
        let edited = app.staticTexts["Edited from Home · 0.25 cup"]
        XCTAssertTrue(edited.waitForExistence(timeout: 5))
        edited.swipeLeft()
        app.buttons["home.event.delete"].tap()
        app.alerts["Delete event?"].buttons["Cancel"].tap()
        XCTAssertTrue(edited.exists)
        edited.swipeLeft()
        app.buttons["home.event.delete"].tap()
        app.alerts["Delete event?"].buttons["Delete"].tap()
        relaunch(app)
        XCTAssertFalse(edited.exists)
    }

    func testHomeReminderSwipeEditSkipAndDelete() {
        let app = launchApp()
        let row = app.descendants(matching: .any)["home.reminder.99999999-9999-9999-9999-999999999999"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["home.reminder.edit"].tap()
        replaceText(app.textFields["reminderEditor.title"], with: "Home reminder")
        app.buttons["reminderEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Home reminder"].waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["home.reminder.skip"].tap()
        XCTAssertFalse(app.staticTexts["Breakfast Dry Food · 0.25 cup"].exists)
        relaunch(app)
        XCTAssertFalse(row.exists)
        app.tabBars.buttons["Reminders"].tap()
        XCTAssertTrue(app.staticTexts["Home reminder"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Home"].tap()
        let fountain = app.staticTexts["Clean fountain"]
        fountain.swipeLeft()
        app.buttons["home.reminder.delete"].tap()
        app.alerts["Delete reminder?"].buttons["Delete Reminder"].firstMatch.tap()
        relaunch(app)
        XCTAssertFalse(fountain.exists)
    }

    func testPastFoodEditPersistsAndCancelKeepsSavedValue() {
        let app = launchApp()
        app.buttons["reminder.completeNow.99999999-9999-9999-9999-999999999999"].tap()
        app.tabBars.buttons["Events"].tap()
        app.staticTexts["Breakfast Dry Food · 0.25 cup · 95 cal"].tap()
        let name = app.textFields["eventEditor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.press(forDuration: 1.2)
        let selectAll = app.menuItems["Select All"].exists
            ? app.menuItems["Select All"] : app.buttons["Select All"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 3))
        selectAll.tap()
        name.typeText("Corrected Breakfast")
        app.buttons["eventEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Corrected Breakfast · 0.25 cup · 95 cal"].waitForExistence(timeout: 5))
        relaunch(app)
        app.tabBars.buttons["Events"].tap()
        app.staticTexts["Corrected Breakfast · 0.25 cup · 95 cal"].tap()
        app.buttons["eventEditor.cancel"].tap()
        XCTAssertTrue(app.staticTexts["Corrected Breakfast · 0.25 cup · 95 cal"].waitForExistence(timeout: 5))
    }

    func testQuickAddMedicinePersistsVisibleEvent() {
        let app = launchApp()
        app.buttons["home.quickAdd.Medicine"].tap()
        app.buttons["eventCreation.destination"].tap()
        XCTAssertTrue(app.buttons["Cat One"].waitForExistence(timeout: 5))
        app.buttons["Cat One"].tap()
        app.buttons["medicineCreation.savedOption"].tap()
        app.buttons["Medicine Name"].tap()
        app.buttons["medicineCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Medicine Name · 1 tablet"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Medicine Name · 1 tablet"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Events"].tap()
        app.segmentedControls.buttons["Medicine"].tap()
        app.buttons["events.petFilter"].tap()
        app.buttons["Household"].tap()
        XCTAssertTrue(app.staticTexts["No events yet"].waitForExistence(timeout: 5))
        app.buttons["events.petFilter"].tap()
        app.buttons["Cat One"].tap()
        XCTAssertFalse(app.staticTexts["No events yet"].exists)
        XCTAssertTrue(app.staticTexts["Medicine Name · 1 tablet"].waitForExistence(timeout: 5))
    }

    func testReminderCompletionPersistsInHistory() {
        let app = launchApp()
        app.tabBars.buttons["Reminders"].tap()
        let activeID = "reminder.active.AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        let row = app.descendants(matching: .any)[activeID].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["reminder.complete"].tap()
        XCTAssertFalse(row.exists)
        app.buttons["Completed"].tap()
        let historyID = "reminder.completed.AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        XCTAssertTrue(app.descendants(matching: .any)[historyID].firstMatch.waitForExistence(timeout: 5))
        relaunch(app)
        app.tabBars.buttons["Reminders"].tap()
        XCTAssertFalse(app.descendants(matching: .any)[activeID].firstMatch.exists)
        app.buttons["Completed"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[historyID].firstMatch.waitForExistence(timeout: 5))
    }

    func testQuickAddLitterCreatesVisibleEvent() {
        let app = launchApp()
        app.buttons["home.quickAdd.Litter"].tap()
        app.buttons["litterCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Litter cleaned"].waitForExistence(timeout: 5))
    }

    func testSettingsTogglePersistsAcrossRelaunch() {
        let app = launchApp()
        openSettings(in: app)
        app.buttons["settings.notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers["settings.defaultDayOnlyNotificationHour"].exists)
        XCTAssertFalse(app.switches["settings.global.showsBanner"].exists)
        let defaults = app.switches["settings.Food.useDefault"]
        XCTAssertEqual(defaults.value as? String, "1")
        let banners = app.switches["settings.Food.showsBanner"]
        tapSwitch(banners)
        XCTAssertEqual(defaults.value as? String, "0")
        XCTAssertEqual(banners.value as? String, "0")
        relaunch(app)
        openSettings(in: app)
        app.buttons["settings.notifications"].tap()
        XCTAssertEqual(defaults.value as? String, "0")
        XCTAssertEqual(banners.value as? String, "0")
        tapSwitch(defaults)
        XCTAssertEqual(banners.value as? String, "1")
        captureUI(app, name: "Notification defaults and overrides")
    }

    func testDebugResetControlIsAvailableInDebugBuilds() {
        let app = launchApp()
        openSettings(in: app)

        let resetButton = app.buttons["settings.development.resetAndReseed"]
        XCTAssertTrue(scrollToElement(resetButton, in: app))

        resetButton.tap()
        XCTAssertTrue(app.buttons["Reset and Reseed"].waitForExistence(timeout: 8))
        // Confirm against the isolated test store; iOS may show a popover without Cancel.
        app.buttons["Reset and Reseed"].tap()
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Reset and Reseed"].exists)
    }

    func testEarlyDoseCancelAndOverridePersist() {
        let app = launchApp(doseTiming: true)
        beginMedicine(in: app)
        app.buttons["medicineCreation.save"].tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].waitForExistence(timeout: 5))
        beginMedicine(in: app)
        app.buttons["medicineCreation.save"].tap()
        let warning = app.alerts["Dose timing warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Add Medicine"].exists)
        app.buttons["medicineCreation.save"].tap()
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["Log anyway"].tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].waitForExistence(timeout: 5))
        relaunch(app)
        app.tabBars.buttons["Events"].tap()
        app.segmentedControls.buttons["Medicine"].tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "Medicine Name · 1 tablet").count, 2)
        app.staticTexts.matching(identifier: "Medicine Name · 1 tablet").firstMatch.tap()
        XCTAssertTrue(scrollToElement(app.staticTexts["Recorded timing override"], in: app))
        app.buttons["eventEditor.save"].tap()
        let editWarning = app.alerts["Dose timing warning"]
        XCTAssertTrue(editWarning.waitForExistence(timeout: 5))
        editWarning.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["eventEditor.save"].exists)
        app.buttons["eventEditor.cancel"].tap()
    }

    func testCompleteNowMedicationWarningDoesNotCompleteOnCancel() {
        let app = launchApp(doseTiming: true)
        beginMedicine(in: app)
        app.buttons["medicineCreation.save"].tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].waitForExistence(timeout: 5))
        let complete = app.buttons["reminder.completeNow.CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"]
        XCTAssertTrue(scrollToElement(complete, in: app))
        complete.tap()
        let warning = app.alerts["Dose timing warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["Cancel"].tap()
        XCTAssertTrue(complete.exists)
        complete.tap()
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["Log anyway"].tap()
        XCTAssertFalse(complete.exists)
        relaunch(app)
        app.tabBars.buttons["Reminders"].tap()
        app.buttons["Completed"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["reminder.completed.CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"].firstMatch.waitForExistence(timeout: 5))
    }

    func testReminderCompletionSheetPresentsMedicationWarning() {
        let app = launchApp(doseTiming: true)
        beginMedicine(in: app)
        app.buttons["medicineCreation.save"].tap()
        app.tabBars.buttons["Reminders"].tap()
        let row = app.descendants(matching: .any)["reminder.active.CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["reminder.complete"].tap()
        XCTAssertTrue(app.buttons["reminderCompletion.done"].waitForExistence(timeout: 5))
        app.buttons["reminderCompletion.done"].tap()
        let warning = app.alerts["Dose timing warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["reminderCompletion.done"].exists)
        app.buttons["reminderCompletion.done"].tap()
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        warning.buttons["Log anyway"].tap()
        XCTAssertTrue(app.navigationBars["Reminders"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
    }

    func testSavedMedicationIntervalCanBeConfiguredAndPersists() {
        let app = launchApp()
        openSettings(in: app)
        let medicine = app.buttons["settings.savedOptions.Medicine"]
        XCTAssertTrue(scrollToElement(medicine, in: app))
        medicine.tap()
        app.staticTexts["Medicine Name"].tap()
        let timing = app.switches["medicineTiming.enabled"]
        XCTAssertTrue(scrollToElement(timing, in: app))
        tapSwitch(timing)
        replaceText(app.textFields["medicineTiming.minimumHours"], with: "8")
        replaceText(app.textFields["medicineTiming.maximumHours"], with: "12")
        app.buttons["savedOption.save"].tap()
        XCTAssertTrue(app.staticTexts["Prescribed interval: 8–12 hours"].waitForExistence(timeout: 5))
        relaunch(app)
        openSettings(in: app)
        XCTAssertTrue(scrollToElement(app.buttons["settings.savedOptions.Medicine"], in: app))
        app.buttons["settings.savedOptions.Medicine"].tap()
        XCTAssertTrue(app.staticTexts["Prescribed interval: 8–12 hours"].waitForExistence(timeout: 5))
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let value = field.value as? String ?? ""
        field.tap()
        if value == "0" {
            field.doubleTap()
            field.typeText(text)
        } else {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count) + text)
        }
        XCTAssertEqual(field.value as? String, text)
    }

    func testHealthQuickAddRecentPetTimelineEditAndPersistence() {
        let app = launchApp()
        app.buttons["home.quickAdd.Health"].tap()
        let save = app.buttons["healthEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        app.buttons["healthEditor.pet"].coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        let petChoice = app.buttons["Cat One"]
        XCTAssertTrue(petChoice.waitForExistence(timeout: 5))
        petChoice.tap()
        XCTAssertTrue(app.buttons["healthEditor.weightUnit"].label.contains("lb"))
        replaceText(app.textFields["healthEditor.weight"], with: "9.5")
        save.tap()
        XCTAssertTrue(app.staticTexts["Weight · 9.5 lb"].waitForExistence(timeout: 5))
        app.staticTexts["Weight · 9.5 lb"].tap()
        XCTAssertTrue(app.navigationBars["Pet Tracker"].exists)
        app.staticTexts["Weight · 9.5 lb"].swipeLeft()
        app.buttons["home.event.edit"].tap()
        replaceText(app.textFields["healthEditor.weight"], with: "10")
        app.buttons["healthEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Weight · 10 lb"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Weight · 10 lb"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Pets"].tap()
        app.staticTexts["Cat One"].tap()
        app.segmentedControls.buttons["Health"].tap()
        app.buttons["healthTimeline.category"].tap()
        app.buttons["General note"].tap()
        XCTAssertTrue(app.staticTexts["No matching health entries"].waitForExistence(timeout: 5))
        app.buttons["healthTimeline.add"].tap()
        app.buttons["healthEditor.category"].tap()
        app.buttons["General note"].tap()
        replaceText(app.textFields["healthEditor.title"], with: "Feeling well")
        app.buttons["healthEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Feeling well"].waitForExistence(timeout: 5))
        app.staticTexts["Feeling well"].tap()
        replaceText(app.textFields["healthEditor.title"], with: "Canceled edit")
        app.buttons["healthEditor.cancel"].tap()
        XCTAssertTrue(app.staticTexts["Feeling well"].exists)
        app.tabBars.buttons["Pets"].tap()
        app.staticTexts["Cat Two"].tap()
        app.segmentedControls.buttons["Health"].tap()
        XCTAssertTrue(app.staticTexts["No health entries yet"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Home"].tap()
        let weight = app.staticTexts["Weight · 10 lb"]
        scrollTo(weight, in: app)
        weight.swipeLeft()
        app.buttons["home.event.delete"].tap()
        app.alerts["Delete event?"].buttons["Delete"].tap()
        relaunch(app)
        XCTAssertFalse(weight.exists)
        XCTAssertTrue(app.staticTexts["Feeling well"].exists)
    }

    func testPetAddEditCancelAndRelaunch() {
        let app = launchApp()
        app.tabBars.buttons["Pets"].tap()
        app.buttons["pets.add"].tap()
        XCTAssertFalse(app.buttons["petEditor.save"].isEnabled)
        replaceText(app.textFields["petEditor.name"], with: "New Cat")
        replaceText(app.textFields["petEditor.calories"], with: "250")
        app.buttons["petEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["New Cat"].waitForExistence(timeout: 5))
        app.staticTexts["New Cat"].tap()
        app.buttons["petDetail.edit"].tap()
        replaceText(app.textFields["petEditor.name"], with: "Renamed Cat")
        app.buttons["petEditor.save"].tap()
        XCTAssertTrue(app.navigationBars["Renamed Cat"].waitForExistence(timeout: 5))
        app.buttons["petDetail.edit"].tap()
        replaceText(app.textFields["petEditor.name"], with: "Canceled Cat")
        app.buttons["petEditor.cancel"].tap()
        XCTAssertTrue(app.navigationBars["Renamed Cat"].exists)
        relaunch(app)
        app.tabBars.buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Renamed Cat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 cal/day"].exists)
    }

    func testReminderCreateEditCancelAndRelaunch() {
        let app = launchApp()
        openReminders(in: app)
        app.buttons["reminders.add"].tap()
        XCTAssertFalse(app.buttons["reminderEditor.save"].isEnabled)
        replaceText(app.textFields["reminderEditor.title"], with: "Fountain reminder")
        chooseMenu(app.buttons["reminderEditor.repeat"], choice: "Every interval", in: app)
        app.buttons["reminderEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Fountain reminder"].waitForExistence(timeout: 5))
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "reminder.active.", "Fountain reminder")
        ).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Reminder"].waitForExistence(timeout: 5))
        replaceText(app.textFields["reminderEditor.title"], with: "Edited fountain")
        app.buttons["reminderEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Edited fountain"].waitForExistence(timeout: 5))
        let editedReminderRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "reminder.active.", "Edited fountain")
        ).firstMatch
        editedReminderRow.swipeLeft()
        app.buttons["reminder.edit"].tap()
        replaceText(app.textFields["reminderEditor.title"], with: "Canceled fountain")
        app.buttons["reminderEditor.cancel"].tap()
        XCTAssertTrue(app.staticTexts["Edited fountain"].exists)
        relaunch(app)
        openReminders(in: app)
        XCTAssertTrue(app.staticTexts["Edited fountain"].waitForExistence(timeout: 5))

        editedReminderRow.swipeRight()
        app.buttons["reminder.delete"].tap()
        let deleteAlert = app.alerts["Delete reminder?"]
        let deleteOccurrence = deleteAlert.buttons["reminder.deleteOccurrence"].firstMatch
        XCTAssertTrue(deleteOccurrence.waitForExistence(timeout: 5))
        XCTAssertTrue(deleteAlert.buttons["reminder.deleteAll"].firstMatch.exists)
        deleteOccurrence.tap()
        XCTAssertTrue(app.staticTexts["Edited fountain"].waitForExistence(timeout: 5))

        editedReminderRow.swipeRight()
        app.buttons["reminder.delete"].tap()
        app.alerts["Delete reminder?"].buttons["reminder.deleteAll"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Edited fountain"].exists)
        relaunch(app)
        openReminders(in: app)
        XCTAssertFalse(app.staticTexts["Edited fountain"].exists)
    }

    func testScheduledFoodEventCreatesAtScheduledTimeAndPersists() {
        let app = launchApp()
        app.tabBars.buttons["Events"].tap()
        XCTAssertFalse(app.staticTexts["No active recurring events"].exists)
        app.buttons["events.add"].tap()
        tapSwitch(app.switches["eventCreation.recurring"])
        XCTAssertTrue(app.buttons["scheduledEventEditor.repeat"].exists)
        chooseMenu(app.buttons["foodCreation.savedOption"], choice: "Breakfast Dry Food", in: app)
        scrollTo(app.textFields["foodCreation.amount.Household"], in: app)
        replaceText(app.textFields["foodCreation.amount.Household"], with: "1")
        app.buttons["foodCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food · 1 cup · 380 cal"].waitForExistence(timeout: 5))
        app.buttons["events.recurring"].tap()
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food"].waitForExistence(timeout: 5))
        captureUI(app, name: "Events recurring section and log")
        relaunch(app)
        app.tabBars.buttons["Events"].tap()
        XCTAssertFalse(app.staticTexts["Breakfast Dry Food"].exists)
        app.buttons["events.recurring"].tap()
        app.staticTexts["Breakfast Dry Food"].tap()
        XCTAssertTrue(app.navigationBars["Edit Scheduled Event"].waitForExistence(timeout: 5))
        app.buttons["scheduledEventEditor.cancel"].tap()
        app.tabBars.buttons["Reminders"].tap()
        XCTAssertFalse(app.buttons["scheduledEvents.add"].exists)
        XCTAssertFalse(app.staticTexts["Scheduled Events"].exists)
    }

    func testRecurringLitterCreatesAndDeletesScheduleWithoutDeletingLog() {
        let app = launchApp()
        app.tabBars.buttons["Events"].tap()
        app.segmentedControls.buttons["Litter"].tap()
        app.buttons["events.add"].tap()
        tapSwitch(app.switches["eventCreation.recurring"])
        app.buttons["litterCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Litter cleaned"].waitForExistence(timeout: 5))
        app.buttons["events.recurring"].tap()
        let schedule = app.staticTexts["Litter cleaning"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 5))
        schedule.swipeLeft()
        app.buttons["scheduledEvent.delete"].tap()
        app.alerts["Delete recurring event?"].buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(schedule.exists)
        XCTAssertTrue(app.staticTexts["Litter cleaned"].exists)
    }

    private func openReminders(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Reminders"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        let navigationBar = app.navigationBars["Reminders"]
        if !navigationBar.waitForExistence(timeout: 2) {
            tab.tap()
        }
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
    }

    func testGeneralMedicineReminderLogsStoredPetDose() {
        let app = launchApp()
        openReminders(in: app)
        app.buttons["reminders.add"].tap()
        replaceText(app.textFields["reminderEditor.title"], with: "Food and medicine")
        XCTAssertFalse(app.buttons["reminderEditor.mode"].exists)
        chooseMenu(app.buttons["reminderEditor.addEvent"], choice: "Food", in: app)
        chooseMenu(app.buttons["reminderAction.pet.Food"], choice: "Cat One", in: app)
        chooseMenu(app.buttons["reminderAction.option.Food"], choice: "Breakfast Dry Food", in: app)
        app.swipeDown()
        chooseMenu(app.buttons["reminderEditor.addEvent"], choice: "Medicine", in: app)
        chooseMenu(app.buttons["reminderAction.pet.Medicine"], choice: "Cat One", in: app)
        chooseMenu(app.buttons["reminderAction.option.Medicine"], choice: "Medicine Name", in: app)
        XCTAssertTrue(app.buttons["reminderEditor.save"].isEnabled)
        captureUI(app, name: "Reminder with multiple event types")
        app.buttons["reminderEditor.save"].tap()
        relaunch(app)
        openReminders(in: app)
        let title = app.staticTexts["Food and medicine"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.swipeLeft()
        app.buttons["reminder.complete"].tap()
        app.buttons["reminderCompletion.done"].tap()
        app.tabBars.buttons["Events"].tap()
        XCTAssertTrue(app.staticTexts["Breakfast Dry Food · 1 cup · 380 cal"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Medicine"].tap()
        XCTAssertTrue(app.staticTexts["Medicine Name · 1 tablet"].waitForExistence(timeout: 5))
    }

    private func tapWhenReady(_ element: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        element.tap()
    }

    private func captureUI(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            (app.collectionViews.allElementsBoundByIndex.last ?? app).swipeUp()
        }
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            (app.collectionViews.allElementsBoundByIndex.last ?? app).swipeDown()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func chooseMenu(_ picker: XCUIElement, choice: String, in app: XCUIApplication) {
        scrollTo(picker, in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        let option = app.buttons[choice]
        if !option.waitForExistence(timeout: 1) {
            scrollTo(picker, in: app)
            picker.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        }
        guard option.waitForExistence(timeout: 5) else {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            XCTFail("Menu choice missing: \(choice)")
            return
        }
        option.tap()
    }

    func testEventsAddRoutesToSelectedTypeAndPersists() {
        let app = launchApp()
        app.tabBars.buttons["Events"].tap()
        app.buttons["events.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Food"].waitForExistence(timeout: 5))
        app.buttons["eventCreation.close"].tap()
        app.segmentedControls.buttons["Medicine"].tap()
        app.buttons["events.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Medicine"].waitForExistence(timeout: 5))
        app.buttons["eventCreation.close"].tap()
        app.segmentedControls.buttons["Litter"].tap()
        app.buttons["events.add"].tap()
        app.buttons["litterCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Litter cleaned"].waitForExistence(timeout: 5))
        relaunch(app)
        app.tabBars.buttons["Events"].tap()
        app.segmentedControls.buttons["Litter"].tap()
        XCTAssertTrue(app.staticTexts["Litter cleaned"].waitForExistence(timeout: 5))
    }

    func testCareEventDeleteCancelConfirmAndRelaunch() {
        let app = launchApp()
        app.buttons["reminder.completeNow.99999999-9999-9999-9999-999999999999"].tap()
        app.tabBars.buttons["Events"].tap()
        let event = app.staticTexts["Breakfast Dry Food · 0.25 cup · 95 cal"]
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        event.swipeLeft()
        app.buttons["events.delete"].tap()
        app.alerts["Delete event?"].buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(event.exists)
        event.swipeLeft()
        app.buttons["events.delete"].tap()
        app.alerts["Delete event?"].buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No events yet"].waitForExistence(timeout: 5))
        relaunch(app)
        app.tabBars.buttons["Events"].tap()
        XCTAssertTrue(app.staticTexts["No events yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(event.exists)
    }

    func testInlineFoodSaveSelectsNewOptionAndCancelPreservesDraft() {
        let app = launchApp()
        app.buttons["home.quickAdd.Food"].tap()
        chooseMenu(app.buttons["foodCreation.savedOption"], choice: "Breakfast Dry Food", in: app)
        scrollTo(app.textFields["foodCreation.amount.Household"], in: app)
        replaceText(app.textFields["foodCreation.amount.Household"], with: "1")
        tapWhenReady(app.buttons["foodCreation.addOption"])
        replaceText(app.textFields["savedOption.name"], with: "Canceled food")
        app.buttons["savedOptionCreation.cancel"].tap()
        XCTAssertTrue(app.buttons["foodCreation.savedOption"].label.contains("Breakfast Dry Food"))
        XCTAssertEqual(app.textFields["foodCreation.amount.Household"].value as? String, "1")
        captureUI(app, name: "Food after cancel")
        tapWhenReady(app.buttons["foodCreation.addOption"])
        replaceText(app.textFields["savedOption.name"], with: "Inline food")
        let calories = app.steppers["savedOption.food.calories"]
        scrollTo(calories, in: app)
        calories.buttons["savedOption.food.calories-Increment"].tap()
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Inline food editor"
        proof.lifetime = .keepAlways
        add(proof)
        app.buttons["savedOption.save"].tap()
        XCTAssertTrue(app.buttons["foodCreation.savedOption"].label.contains("Inline food"))
        app.buttons["foodCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Inline food · 1 cup"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Events"].tap()
        XCTAssertTrue(app.staticTexts["Inline food · 1 cup · 5 cal"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Inline food · 1 cup"].waitForExistence(timeout: 5))
        app.buttons["home.quickAdd.Food"].tap()
        app.buttons["foodCreation.savedOption"].coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Inline food"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Canceled food"].exists)
        app.buttons["Inline food"].tap()
    }

    func testInlineMedicationSaveSelectsNewDoseAndCancelPreservesSelection() {
        let app = launchApp()
        beginMedicine(in: app)
        app.buttons["medicineCreation.addOption"].tap()
        replaceText(app.textFields["savedOption.name"], with: "Canceled medicine")
        app.buttons["savedOptionCreation.cancel"].tap()
        XCTAssertTrue(app.buttons["medicineCreation.savedOption"].label.contains("Medicine Name"))
        app.buttons["medicineCreation.addOption"].tap()
        replaceText(app.textFields["savedOption.name"], with: "Inline medicine")
        replaceText(app.textFields["savedOption.medicine.dose"], with: "2")
        replaceText(app.textFields["savedOption.medicine.unit"], with: "mL")
        app.buttons["savedOption.save"].tap()
        XCTAssertTrue(app.buttons["medicineCreation.savedOption"].label.contains("Inline medicine"))
        app.buttons["medicineCreation.save"].tap()
        XCTAssertTrue(app.staticTexts["Inline medicine · 2 mL"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Inline medicine · 2 mL"].waitForExistence(timeout: 5))
    }

    private func beginMedicine(in app: XCUIApplication) {
        app.buttons["home.quickAdd.Medicine"].tap()
        app.buttons["eventCreation.destination"].tap()
        app.buttons["Cat One"].tap()
        app.buttons["medicineCreation.savedOption"].tap()
        app.buttons["Medicine Name"].tap()
    }

    private func launchApp(doseTiming: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingReset"]
        if doseTiming { app.launchArguments.append("-uiTestingDoseTiming") }
        app.launch()
        return app
    }

    private func relaunch(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    private func openSettings(in app: XCUIApplication) {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8))
        settingsTab.tap()
    }

    private func tapSwitch(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.waitForExistence(timeout: 2) && element.isHittable {
            return true
        }

        for _ in 0..<5 {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) && element.isHittable {
                return true
            }
        }

        return false
    }
}
