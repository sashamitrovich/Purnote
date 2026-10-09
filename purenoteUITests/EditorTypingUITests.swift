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
        let note = sampleNote()
        XCTAssertTrue(note.waitForExistence(timeout: 5), "sample note not in the list")
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

    /// Every visible bar button is reachable without scrolling, so the row
    /// fits the screen rather than spilling past its edge. Strikethrough, Code
    /// and Table moved into the "···" overflow menu (its "More" button must be
    /// present too).
    func testBarButtonsExistAndAreHittable() throws {
        try newNote()
        for name in ["Bold", "Italic", "Heading", "List", "Quote", "Link", "Photo"] {
            let button = app.buttons[name].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), "\(name) button missing")
            XCTAssertTrue(button.isHittable, "\(name) button is not hittable")
        }
        let more = app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "More button missing")
        XCTAssertTrue(more.isHittable, "More button is not hittable")
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
        app.buttons["List"].firstMatch.tap()
        // wait for the menu item rather than a fixed sleep. Known flaky on
        // the simulator (fails on 1.4.0 too): the tap on "List" sometimes
        // does not open the menu at all. See #52.
        let item = app.buttons["Bulleted list"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Bulleted list menu item missing")
        item.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(try value(), "- milk")
    }

    /// The reported bug: applying a list style from the menu left the caret at
    /// the start of the line, so the next thing typed landed before the marker
    /// instead of in the list. A bar button must leave the caret where the
    /// change was made, ready to type the item's text.
    func testChecklistPutsTheCaretAfterTheMarker() throws {
        try newNote()
        editor.typeText("milk")
        app.buttons["List"].firstMatch.tap()
        // wait for the menu item rather than a fixed sleep. Known flaky on
        // the simulator (fails on 1.4.0 too): the tap on "List" sometimes
        // does not open the menu at all. See #52.
        let item = app.buttons["Checklist"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Checklist menu item missing")
        item.tap()
        Thread.sleep(forTimeInterval: 0.6)
        editor.typeText("!")
        XCTAssertEqual(try value(), "- [ ] milk!")
    }

    // MARK: - Checkboxes on the rendered page

    /// Opens a sample note that has a checklist, without entering the editor.
    private func openNoteWithChecklist() throws {
        let note = sampleNote()
        XCTAssertTrue(note.waitForExistence(timeout: 5), "sample note not in the list")
        note.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// The seeded "Marathon training" note, scrolled into view. The list renders
    /// lazily, and the tests before this one leave new notes above it, so the
    /// sample can sit below the fold; scroll until it exists rather than
    /// assuming it is on screen.
    private func sampleNote() -> XCUIElement {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "Marathon training")
        let note = app.buttons.matching(predicate).firstMatch

        var swipes = 0
        while !note.exists && swipes < 15 {
            app.swipeUp()
            swipes += 1
        }
        return note
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

    // MARK: - Where the caret lands

    /// Tapping a word on the rendered page should open the editor with the
    /// caret at that word, not at the top of the paragraph.
    ///
    /// Asserted by typing a marker and looking at where it ended up, which is
    /// the only way to see a caret from outside.
    func testCaretLandsNearTheTappedWord() throws {
        try openNoteWithChecklist()

        // the opening paragraph, whose text we know
        let paragraph = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Sixteen weeks")
        ).firstMatch
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10), "paragraph not found")

        // tap near the end of the paragraph rather than its start
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.75)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor never opened")
        Thread.sleep(forTimeInterval: 1.5)

        editor.typeText("§")
        let text = try XCTUnwrap(editor.value as? String)

        let marker = try XCTUnwrap(text.range(of: "§"), "marker was not typed")
        let at = text.distance(from: text.startIndex, to: marker.lowerBound)

        let paragraphStart = try XCTUnwrap(text.range(of: "Sixteen weeks")).lowerBound
        let start = text.distance(from: text.startIndex, to: paragraphStart)
        let end = start + 118   // the paragraph is ~118 characters long

        XCTAssertTrue(at > start, "caret landed at or before the start of the paragraph (\(at) vs \(start))")
        XCTAssertTrue(at <= end + 2, "caret landed past the paragraph (\(at) vs \(end))")
        // tapped four fifths of the way along the last line, so it should be
        // well into the second half of the paragraph
        XCTAssertTrue(at > start + 50,
                      "caret landed near the start rather than where the tap was (\(at - start) chars in)")
    }

    // MARK: - Folder create & rename (native alerts)

    /// New Folder and Rename Folder are native alerts now; both must still
    /// create and rename a real folder.
    func testCreateAndRenameFolder() throws {
        let newFolderButton = app.buttons["New folder"].firstMatch
        XCTAssertTrue(newFolderButton.waitForExistence(timeout: 20), "no New folder button")

        // New Folder → menu → alert
        newFolderButton.tap()
        let menuItem = app.buttons["New Folder"].firstMatch
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "no New Folder menu item")
        menuItem.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no alert text field")
        field.typeText("Test Folder")
        app.buttons["Create"].firstMatch.tap()

        let folderRow = app.staticTexts["Test Folder"].firstMatch
        XCTAssertTrue(folderRow.waitForExistence(timeout: 10), "folder was not created")

        // Rename via the row's context menu → alert (pre-filled with the name)
        folderRow.press(forDuration: 1.2)
        let renameItem = app.buttons["Rename Folder"].firstMatch
        XCTAssertTrue(renameItem.waitForExistence(timeout: 5), "no Rename Folder menu item")
        renameItem.tap()

        let renameField = app.textFields.firstMatch
        XCTAssertTrue(renameField.waitForExistence(timeout: 5), "no rename text field")
        renameField.typeText(" Renamed")
        app.buttons["Save"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Test Folder Renamed"].firstMatch
            .waitForExistence(timeout: 10), "folder was not renamed")
    }
}
