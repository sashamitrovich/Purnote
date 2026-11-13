import XCTest

/// The editor's top bar: Undo, Redo and Find in Note, driven through the real
/// app. The buttons are found by identifier (editor.undo, editor.redo): the
/// home screen has its own "Undo" toast button, so a label would be ambiguous.
/// Items inside a Menu are found by label, since the simulator does not expose
/// their identifiers.
final class EditorUndoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
        app.launch()
    }

    private var editor: XCUIElement { app.textViews.firstMatch }
    private var undoButton: XCUIElement { app.buttons["editor.undo"] }
    private var redoButton: XCUIElement { app.buttons["editor.redo"] }

    /// A new note, focused and empty.
    private func newNote() throws {
        let compose = app.buttons["New note"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "no New note button")
        compose.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor never appeared")
        editor.tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    private func value() throws -> String {
        try XCTUnwrap(editor.value as? String)
    }

    /// Polls for a button's enabled state: the bar updates a beat after the
    /// edit that changed it.
    private func waitForEnabled(_ button: XCUIElement, _ expected: Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if button.exists && button.isEnabled == expected { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return button.exists && button.isEnabled == expected
    }

    private func tapBar(_ name: String, expecting expected: String) throws {
        for _ in 0..<2 {
            app.buttons[name].firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.8)
            if try value() == expected { return }
        }
        XCTAssertEqual(try value(), expected, "\(name) did not edit the text")
    }

    // MARK: - Undo and Redo

    func testUndoAndRedoAreInTheTopBarWithTheirLabels() throws {
        try newNote()
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5), "no editor.undo in the top bar")
        XCTAssertTrue(redoButton.exists, "no editor.redo in the top bar")
        XCTAssertEqual(undoButton.label, "Undo")
        XCTAssertEqual(redoButton.label, "Redo")
        XCTAssertTrue(app.buttons["Done"].exists, "Done is gone from the top bar")
    }

    func testBothAreDisabledOnAFreshNote() throws {
        try newNote()
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5))
        XCTAssertFalse(undoButton.isEnabled, "Undo is enabled with nothing to undo")
        XCTAssertFalse(redoButton.isEnabled, "Redo is enabled with nothing to redo")
    }

    /// UIKit takes typed text back a few characters at a time (observed here:
    /// one tap took back one of the three characters typed by XCUITest), so
    /// one tap is asserted to change something and the button is then tapped
    /// until it disables.
    func testTypingEnablesUndoAndUndoThenRedoRestoreTheText() throws {
        try newNote()
        editor.typeText("abc")
        XCTAssertEqual(try value(), "abc")
        XCTAssertTrue(waitForEnabled(undoButton, true), "typing did not enable Undo")
        XCTAssertFalse(redoButton.isEnabled)

        undoButton.tap()
        Thread.sleep(forTimeInterval: 0.6)
        let afterOne = try value()
        XCTAssertNotEqual(afterOne, "abc", "a tap on Undo changed nothing")
        XCTAssertTrue("abc".hasPrefix(afterOne), "Undo changed something other than the typing: '\(afterOne)'")
        XCTAssertTrue(waitForEnabled(redoButton, true), "Redo stayed disabled after an Undo")

        try tapUntilDisabled(undoButton)
        XCTAssertEqual(try value(), "", "Undo until disabled should leave the note as it was before typing")
        XCTAssertTrue(waitForEnabled(redoButton, true))

        try tapUntilDisabled(redoButton)
        XCTAssertEqual(try value(), "abc", "Redo until disabled did not bring the typing back")
        XCTAssertTrue(waitForEnabled(undoButton, true))
    }

    private func tapUntilDisabled(_ button: XCUIElement) throws {
        for _ in 0..<10 {
            guard waitForEnabled(button, true, timeout: 1.5) else { return }
            button.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertFalse(button.isEnabled, "\(button.identifier) still enabled after 10 taps")
    }

    func testBoldThenUndoRestoresExactlyAndRedoReapplies() throws {
        try newNote()
        editor.typeText("abc")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(try value(), "abc")

        try tapBar("Bold", expecting: "abc****")
        XCTAssertTrue(waitForEnabled(undoButton, true))

        undoButton.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try value(), "abc", "one tap on Undo must take back exactly the Bold edit")

        redoButton.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try value(), "abc****")
    }

    /// The second path into the editor: NoteEdit, an existing note.
    func testUndoWorksInAnExistingNote() throws {
        let note = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15), "sample note not in the list")
        note.tap()
        Thread.sleep(forTimeInterval: 1.5)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor never appeared")
        Thread.sleep(forTimeInterval: 1.2)
        editor.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(undoButton.waitForExistence(timeout: 5), "no editor.undo in an existing note")
        XCTAssertFalse(undoButton.isEnabled, "Undo is enabled before anything was typed")

        let before = try value()
        editor.typeText("ZZZ")
        XCTAssertEqual(try value().count, before.count + 3)
        XCTAssertTrue(waitForEnabled(undoButton, true))
        try tapUntilDisabled(undoButton)
        XCTAssertEqual(try value(), before, "Undo until disabled did not restore the note's text")
    }

    // MARK: - Screenshots of the top bar

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Top bar with Undo and Redo disabled (fresh note), then Undo enabled
    /// (typed), then both enabled (typed, Bold, one Undo). Attached to the result.
    func testTopBarStatesForScreenshots() throws {
        try newNote()
        XCTAssertTrue(undoButton.waitForExistence(timeout: 5))
        shot("topbar-1-both-disabled")
        editor.typeText("abc")
        XCTAssertTrue(waitForEnabled(undoButton, true))
        shot("topbar-2-undo-enabled")
        // Bold is one undo step on top of the typing, so after undoing it both
        // buttons have something to do
        Thread.sleep(forTimeInterval: 0.5)
        try tapBar("Bold", expecting: "abc****")
        undoButton.tap()
        XCTAssertTrue(waitForEnabled(redoButton, true))
        XCTAssertTrue(waitForEnabled(undoButton, true))
        shot("topbar-3-both-enabled")
    }

    // MARK: - Find in Note

    func testFindInNoteOpensTheFindNavigator() throws {
        try newNote()
        editor.typeText("needle in a haystack")

        let more = app.buttons.matching(NSPredicate(
            format: "label == 'More' AND identifier != 'menu.more'")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "More button missing")
        more.tap()

        let find = app.buttons["Find in Note"].firstMatch
        XCTAssertTrue(find.waitForExistence(timeout: 5), "no Find in Note item in the More menu")
        find.tap()

        // the system find bar: a search field (or text field) labelled Find /
        // Search, with Done in its bar
        let field = app.searchFields.firstMatch
        let anyField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'Search' OR placeholderValue CONTAINS[c] 'Find'")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5) || anyField.waitForExistence(timeout: 2),
                      "the find navigator did not appear")
        XCTAssertEqual(try value(), "needle in a haystack", "opening Find changed the note")
    }
}
