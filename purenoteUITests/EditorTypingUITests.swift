import XCTest

/// Typing, driven through the real app.
///
/// Unit tests say what Return *should* produce. They cannot see whether the
/// keystroke reaches that logic, or whether the editor applies the result where
/// the caret actually is -- and every bug in this feature so far has lived in
/// that gap.
///
/// The behaviour tests use a new note, where the caret is always at the end and
/// the text is only what was typed. Tapping into an existing note puts the
/// caret wherever the tap landed, which makes the expected result depend on the
/// sample note's layout rather than on the behaviour under test; the existing
/// note gets its own test for the thing that is specific to it.
final class EditorTypingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // the simulator has no iCloud, so start past the first run gate
        app.launchArguments += ["-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
        app.launch()
    }

    private var editor: XCUIElement { app.textViews.firstMatch }

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

    // MARK: - Continuing a list

    func testBulletContinues() throws {
        try newNote()
        editor.typeText("- milk\n")
        XCTAssertEqual(try value(), "- milk\n- ")
    }

    func testNumberedListAdvances() throws {
        try newNote()
        editor.typeText("1. first\n")
        XCTAssertEqual(try value(), "1. first\n2. ")
    }

    func testCheckboxContinuesUnticked() throws {
        try newNote()
        editor.typeText("- [x] done\n")
        XCTAssertEqual(try value(), "- [x] done\n- [ ] ")
    }

    func testQuoteContinues() throws {
        try newNote()
        editor.typeText("> quoted\n")
        XCTAssertEqual(try value(), "> quoted\n> ")
    }

    func testTypingAfterReturnLandsInTheNewItem() throws {
        try newNote()
        editor.typeText("- milk\nbread")
        XCTAssertEqual(try value(), "- milk\n- bread")
    }

    func testReturnOnAnEmptyItemEndsTheList() throws {
        try newNote()
        editor.typeText("- milk\n\n")
        XCTAssertEqual(try value(), "- milk\n")
    }

    // MARK: - Return where there is no list (the reported bug)

    /// Saša's report: caret on an empty line, press Return, "it skips a few
    /// lines". The old editor inferred where the newline had gone by comparing
    /// the text before and after, which cannot tell when the character after
    /// the caret is itself a newline -- so it rewrote the line below, leaving a
    /// blank line too many and a stray marker on the next item.
    func testReturnAboveAListDoesNotTouchTheListBelow() throws {
        try newNote()
        editor.typeText("hello\n")
        editor.typeText("- world")
        XCTAssertEqual(try value(), "hello\n- world")

        // back to the end of the first line: a newline directly after the
        // caret, a list line directly below it.
        // The pause matters -- tapping straight after typing is taken as a
        // double tap, which selects the word and makes the Return replace it.
        Thread.sleep(forTimeInterval: 1.2)
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.02)).tap()
        Thread.sleep(forTimeInterval: 0.8)

        editor.typeText("\n")
        XCTAssertEqual(try value(), "hello\n\n- world",
                       "Return above a list must add one newline and leave the list alone")
    }

    func testReturnOnAPlainLineAddsExactlyOneNewline() throws {
        try newNote()
        editor.typeText("just a sentence")
        let before = try value()
        editor.typeText("\n")
        let after = try value()

        XCTAssertEqual(after, before + "\n")
        XCTAssertEqual(after.count, before.count + 1, "Return added more than one character")
    }

    func testRepeatedReturnsAddOneLineEach() throws {
        try newNote()
        editor.typeText("a\n\n\n")
        XCTAssertEqual(try value(), "a\n\n\n")
    }

    // MARK: - Editing a note that already exists

    /// A new note binds the editor to @State; an existing one used to pass a
    /// binding that only wrote `note.content`. Note is a class, so that changed
    /// an object in place and SwiftUI was never told -- edits the app itself
    /// made never reached the editor. This checks the path still works.
    func testTypingWorksInAnExistingNote() throws {
        let note = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Marathon training")
        ).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15), "sample note not in the list")
        note.tap()

        Thread.sleep(forTimeInterval: 1.5)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor never appeared")
        Thread.sleep(forTimeInterval: 1.2)
        editor.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let before = try value()
        editor.typeText("ZZZ")
        let after = try value()

        XCTAssertTrue(after.contains("ZZZ"), "typing did not reach an existing note")
        XCTAssertEqual(after.count, before.count + 3, "typing changed more than it typed")
    }

    // MARK: - The formatting bar

    /// The bar scrolls horizontally, so only the first few buttons are on
    /// screen at once. That is how it has always been; this only pins that the
    /// visible ones are actually reachable.
    func testBarButtonsExistAndAreHittable() throws {
        try newNote()
        for name in ["Bold", "Heading", "Italic"] {
            let button = app.buttons[name].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(name) button missing")
            XCTAssertTrue(button.isHittable, "\(name) button is not hittable")
        }
    }

    func testBoldInsertsMarkersAtTheCaret() throws {
        try newNote()
        editor.typeText("abc")
        app.buttons["Bold"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try value(), "abc****")
    }

    func testBoldThenTypingLandsBetweenTheMarkers() throws {
        try newNote()
        editor.typeText("abc")
        app.buttons["Bold"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        editor.typeText("hi")
        XCTAssertEqual(try value(), "abc**hi**")
    }

    func testHeadingPrefixesTheLine() throws {
        try newNote()
        editor.typeText("title")
        app.buttons["Heading"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try value(), "# title")
    }

    func testBulletedListPrefixesTheLine() throws {
        try newNote()
        editor.typeText("milk")
        app.buttons["Bulleted list"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try value(), "- milk")
    }

    // MARK: - Checkboxes on the rendered page

    /// Opens a sample note that has a checklist, without entering the editor.
    private func openNoteWithChecklist() throws {
        let note = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Marathon training")
        ).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15), "sample note not in the list")
        note.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// The reported bug: tapping a checkbox on the rendered page opened the
    /// editor instead of ticking the box.
    ///
    /// A tick is written to the file, so it survives the run. The test therefore
    /// asserts that the box *changed*, never what it started as -- otherwise it
    /// passes once and fails every time after.
    func testTappingACheckboxTogglesItAndDoesNotOpenTheEditor() throws {
        try openNoteWithChecklist()

        let box = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Fri —")
        ).firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 10), "no checkbox on the page")

        let before = box.value as? String
        XCTAssertNotNil(before, "checkbox does not report whether it is ticked")

        box.tap()
        Thread.sleep(forTimeInterval: 1.0)

        XCTAssertFalse(editor.exists, "tapping a checkbox opened the editor")
        XCTAssertNotEqual(box.value as? String, before, "the box did not change")
    }

    func testTappingACheckboxTwiceLeavesItAsItWas() throws {
        try openNoteWithChecklist()

        let box = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Sun —")
        ).firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 10), "no checkbox on the page")
        let before = box.value as? String

        box.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertNotEqual(box.value as? String, before)

        box.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(box.value as? String, before, "two taps should cancel out")
        XCTAssertFalse(editor.exists, "tapping a checkbox opened the editor")
    }

    /// Tapping the words, rather than the box, still means "let me write here".
    func testTappingTheTextOpensTheEditor() throws {
        try openNoteWithChecklist()

        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Sixteen weeks")
        ).firstMatch.tap()

        XCTAssertTrue(editor.waitForExistence(timeout: 10),
                      "tapping the text should open the editor")
    }
}
