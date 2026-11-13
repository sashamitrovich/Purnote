// Moved out of HangingEditorUITests.swift. Not compiled into any test target:
// this folder is not in Purnote.xcodeproj. To run, add the file to purenoteUITests.

import XCTest

/// Screenshots of the look, attached to the result bundle. These are also
/// smoke tests: every state must open and show the typed text.
final class HangingEditorShotsUITests: XCTestCase {

    private var app: XCUIApplication!

    private func launch(_ extra: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"] + extra
        app.launch()
    }

    private var editor: XCUIElement { app.textViews.firstMatch }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func typeNote(_ text: String) throws {
        let compose = app.buttons["New note"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 15))
        compose.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        Thread.sleep(forTimeInterval: 0.6)
        editor.typeText(text)
    }

    /// Takes the keyboard down so the shot shows the page, not the keys.
    private func hideKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let from = keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        let to = keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.6))
        from.press(forDuration: 0.1, thenDragTo: to)
        Thread.sleep(forTimeInterval: 0.8)
    }

    func testShotsDefaultSizeLightAndDark() throws {
        launch([])
        // Return in a list continues it, so each item's words are typed alone
        try typeNote("# Marathon plan\nSixteen weeks to Berlin: keep it **boring** and _consistent_ and `simple`.\n\n"
                     + "## This week\n- [x] Mon easy run\nWed intervals, 6 x 800 m, with a long enough description to wrap onto a second line\nFri easy run\n\n"
                     + "- Goal pace 4:58\nLong run pace is easy and conversational for the whole of the run, however long it takes to finish\n\n"
                     + "> Nothing new on race day.\n\n1. Breakfast\nGel at km 10\n\n")
        hideKeyboard()
        Thread.sleep(forTimeInterval: 0.5)
        XCUIDevice.shared.appearance = .light
        Thread.sleep(forTimeInterval: 0.8)
        shot("editor-default-light")
        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: 1.0)
        shot("editor-default-dark")
        XCUIDevice.shared.appearance = .light
    }

    func testShotAccessibilitySize() throws {
        launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        try typeNote("# Plan\nBody text **bold**.\n\n- [x] Done thing\nOpen thing that is long enough to wrap around\n\n> A quote\n\n")
        hideKeyboard()
        Thread.sleep(forTimeInterval: 0.5)
        shot("editor-accessibility-xl-light")
    }
}
