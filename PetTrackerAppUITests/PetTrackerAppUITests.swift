import XCTest

@MainActor
final class PetTrackerAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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

        let banners = app.switches["settings.global.showsBanner"]
        XCTAssertTrue(banners.waitForExistence(timeout: 8))
        let originalValue = banners.value as? String

        tapSwitch(banners)
        let toggledValue = banners.value as? String
        XCTAssertNotEqual(toggledValue, originalValue)

        relaunch(app)
        openSettings(in: app)

        let relaunchedBanners = app.switches["settings.global.showsBanner"]
        XCTAssertTrue(relaunchedBanners.waitForExistence(timeout: 8))
        XCTAssertEqual(relaunchedBanners.value as? String, toggledValue)

        tapSwitch(relaunchedBanners)
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
        let complete = app.buttons["reminder.completeNow.CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
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
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count) + text)
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
        XCTAssertTrue(app.buttons["healthTimeline.add"].waitForExistence(timeout: 5))
        app.staticTexts["Weight · 9.5 lb"].tap()
        replaceText(app.textFields["healthEditor.weight"], with: "10")
        app.buttons["healthEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Weight · 10 lb"].waitForExistence(timeout: 5))
        relaunch(app)
        XCTAssertTrue(app.staticTexts["Weight · 10 lb"].waitForExistence(timeout: 8))
        app.staticTexts["Weight · 10 lb"].tap()
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
