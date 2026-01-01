//
//  DBS_CompanionUITests.swift
//  DBS CompanionUITests
//
//  Created by Mikhail Dikov on 12/30/25.
//

import XCTest

class BaseEventUITestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITests"]
        app.launch()
        return app
    }

    func addManualEvent(app: XCUIApplication, optionIdentifier: String, details: String? = nil, notes: String? = nil) {
        app.buttons["addEventButton"].tap()
        app.buttons.matching(identifier: "addEventOption_text").firstMatch.tap()

        let pickerElement = app.descendants(matching: .any).matching(identifier: "eventTypePicker").firstMatch
        XCTAssertTrue(pickerElement.waitForExistence(timeout: 2))
        pickerElement.tap()

        let optionElement = app.descendants(matching: .any).matching(identifier: optionIdentifier).firstMatch
        XCTAssertTrue(optionElement.waitForExistence(timeout: 2))
        optionElement.tap()

        if let details {
            let detailsField = textInput(app, identifier: "eventSubtypeField")
            detailsField.tap()
            detailsField.typeText(details)
        }

        if let notes {
            let notesField = textInput(app, identifier: "eventNotesField")
            notesField.tap()
            notesField.typeText(notes)
        }

        app.buttons["saveEventButton"].tap()
    }

    func textInput(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        let textView = app.textViews[identifier]
        if textView.exists {
            return textView
        }
        return app.textFields[identifier]
    }
}

final class EventCreationUITests: BaseEventUITestCase {
    @MainActor
    func testCreateManualEventAndOpenDetail() {
        let app = launchApp()
        addManualEvent(app: app, optionIdentifier: "eventTypeOption_tremor", details: "Right hand", notes: "Test notes")

        XCTAssertTrue(app.staticTexts["Tremor"].waitForExistence(timeout: 2))
        app.staticTexts["Tremor"].tap()
        XCTAssertTrue(app.staticTexts["Tremor"].waitForExistence(timeout: 2))
    }
}

final class EventCompletionUITests: BaseEventUITestCase {
    @MainActor
    func testCompleteEventFromSwipe() {
        let app = launchApp()
        addManualEvent(app: app, optionIdentifier: "eventTypeOption_rigidity")

        let row = app.staticTexts["Rigidity"]
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        row.swipeRight()
        app.buttons["Complete"].tap()
        app.alerts["Mark as completed?"].buttons["Complete"].tap()

        let statusControl = app.segmentedControls["statusPicker"]
        statusControl.buttons["Completed"].tap()
        XCTAssertTrue(app.staticTexts["Rigidity"].waitForExistence(timeout: 2))
    }
}

final class SelectionActionsUITests: BaseEventUITestCase {
    @MainActor
    func testSelectionToolbarActions() {
        let app = launchApp()
        addManualEvent(app: app, optionIdentifier: "eventTypeOption_batteryCharge")
        addManualEvent(app: app, optionIdentifier: "eventTypeOption_stimulationChange")

        app.buttons["selectEventsButton"].tap()
        app.staticTexts["Battery Charge"].tap()
        app.staticTexts["Stimulation Change"].tap()

        XCTAssertTrue(app.buttons["shareSelectionButton"].isHittable)
        XCTAssertTrue(app.buttons["completeSelectionButton"].isHittable)
        XCTAssertTrue(app.buttons["deleteSelectionButton"].isHittable)

        app.buttons["shareSelectionButton"].tap()
        XCTAssertTrue(app.navigationBars["Share"].waitForExistence(timeout: 2))
    }
}
