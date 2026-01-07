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
    func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UITests"]
        if !environment.isEmpty {
            app.launchEnvironment = environment
        }
        app.launch()
        return app
    }

    func openManualEventForm(app: XCUIApplication) {
        app.buttons["addEventButton"].tap()
        app.buttons.matching(identifier: "addEventOption_text").firstMatch.tap()
    }

    func selectEventType(app: XCUIApplication, optionIdentifier: String) {
        let pickerElement = app.descendants(matching: .any).matching(identifier: "eventTypePicker").firstMatch
        XCTAssertTrue(pickerElement.waitForExistence(timeout: 2))
        scrollToElement(app: app, element: pickerElement)
        tapElement(pickerElement, in: app)

        let optionElement = app.descendants(matching: .any).matching(identifier: optionIdentifier).firstMatch
        if optionElement.waitForExistence(timeout: 2) {
            optionElement.tap()
        } else {
            let label = eventTypeLabel(for: optionIdentifier)
            let labelElement = app.staticTexts[label].firstMatch
            XCTAssertTrue(labelElement.waitForExistence(timeout: 2))
            labelElement.tap()
        }
    }

    func setTime(app: XCUIApplication, to value: String) {
        let picker = app.datePickers["timestampPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.adjust(toPickerWheelValue: value)
    }

    func addManualEvent(app: XCUIApplication, optionIdentifier: String, details: String? = nil, notes: String? = nil) {
        openManualEventForm(app: app)
        selectEventType(app: app, optionIdentifier: optionIdentifier)

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

    func scrollToElement(app: XCUIApplication, element: XCUIElement) {
        let table = app.tables.firstMatch
        guard table.exists else { return }
        var attempts = 0
        while !element.isHittable && attempts < 5 {
            table.swipeUp()
            attempts += 1
        }
        attempts = 0
        while !element.isHittable && attempts < 5 {
            table.swipeDown()
            attempts += 1
        }
    }

    func tapElement(_ element: XCUIElement, in app: XCUIApplication) {
        if element.isHittable {
            element.tap()
            return
        }
        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }

    func eventTypeLabel(for optionIdentifier: String) -> String {
        let raw = optionIdentifier.replacingOccurrences(of: "eventTypeOption_", with: "")
        switch raw {
        case "dyskinesia":
            return "Dyskinesia"
        case "dystonia":
            return "Dystonia"
        case "wearingOff":
            return "Wearing OFF"
        case "tremor":
            return "Tremor"
        case "bradykinesia":
            return "Bradykinesia"
        case "rigidity":
            return "Rigidity"
        case "batteryCharge":
            return "Battery Charge"
        case "stimulationChange":
            return "Stimulation Change"
        case "physicalActivity":
            return "Physical Activity"
        case "medication":
            return "Medication"
        case "feelsGood":
            return "Feels Good"
        default:
            return raw
        }
    }

    func captureScreenshot(_ app: XCUIApplication, name: String, outputDirectory: URL) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Failed to save screenshot to \(url): \(error)")
        }
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

final class QuickDemoScreenshotUITests: BaseEventUITestCase {
    @MainActor
    func testQuickDemoScreenshots() {
        let app = launchApp(environment: ["DBS_UI_TEST_TIMES": "1:00 PM|2:05 PM"])
        let outputPath = ProcessInfo.processInfo.environment["SCREENSHOT_OUTPUT_DIR"] ?? NSTemporaryDirectory()
        let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        openManualEventForm(app: app)
        selectEventType(app: app, optionIdentifier: "eventTypeOption_medication")

        let medicationDetails = textInput(app, identifier: "eventSubtypeField")
        medicationDetails.tap()
        medicationDetails.typeText("Sinemet")

        let medicationNotes = textInput(app, identifier: "eventNotesField")
        medicationNotes.tap()
        medicationNotes.typeText("Taking second dose for the day.")

        app.buttons["saveEventButton"].tap()

        openManualEventForm(app: app)
        selectEventType(app: app, optionIdentifier: "eventTypeOption_dyskinesia")

        let dyskinesiaDetails = textInput(app, identifier: "eventSubtypeField")
        dyskinesiaDetails.tap()
        dyskinesiaDetails.typeText("left arm")

        let dyskinesiaNotes = textInput(app, identifier: "eventNotesField")
        dyskinesiaNotes.tap()
        dyskinesiaNotes.typeText("1h after I took my afternoon C/L dose. Scanned with Medtronic Percept Programmer.")

        captureScreenshot(app, name: "02-new-event-form", outputDirectory: outputURL)
        app.buttons["saveEventButton"].tap()

        XCTAssertTrue(app.staticTexts["Medication"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Dyskinesia"].waitForExistence(timeout: 2))

        captureScreenshot(app, name: "01-event-list", outputDirectory: outputURL)

        app.buttons["selectEventsButton"].tap()
        app.staticTexts["Medication"].tap()
        app.staticTexts["Dyskinesia"].tap()
        app.buttons["shareSelectionButton"].tap()

        XCTAssertTrue(app.navigationBars["Share"].waitForExistence(timeout: 2))
        captureScreenshot(app, name: "03-share-view", outputDirectory: outputURL)

        app.buttons["Share"].tap()
        let previewButton = app.scrollViews.buttons["Preview"]
        if previewButton.waitForExistence(timeout: 2) {
            previewButton.tap()
        }
    }
}
