import XCTest

/// The styled-source editor with hanging syntax, driven through the real app.
///
/// Styling is attributes only, so none of these tests can see a font or an
/// indent. What they can see is the thing the styling must never touch: the
/// characters (the editor's `value`), the undo step, and where a tap puts the
/// caret. The look is checked by the screenshots at the end, which are
/// attached to the result bundle.
final class HangingEditorUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        launch([])
    }

    private func launch(_ extra: [String]) {
        if app.state != .notRunning { app.terminate() }
        app.launchArguments = ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"] + extra
        app.launch()
    }

    private var editor: XCUIElement { app.textViews.firstMatch }

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

    // MARK: - The stored text is exactly what was typed

    func testHeadingAndBodyAreStoredExactly() throws {
        try newNote()
        editor.typeText("# Title\nbody")
        XCTAssertEqual(try value(), "# Title\nbody")
    }

    /// "- one" then Return continues the list, so the second item is typed as
    /// its words only: the marker is the editor's, and nothing else is added.
    func testBulletsAreStoredExactly() throws {
        try newNote()
        editor.typeText("- one\ntwo")
        XCTAssertEqual(try value(), "- one\n- two")
    }

    func testMixedBlocksAreStoredExactly() throws {
        try newNote()
        // (Return on the empty "> " item ends the quote and leaves no blank line)
        editor.typeText("## Plan\n> quoted **bold** and _it_\n\n1. a\nb")
        XCTAssertEqual(try value(), "## Plan\n> quoted **bold** and _it_\n1. a\n2. b")
    }

    func testReturnAfterAHeadingGivesABodyLineAndNoMarker() throws {
        try newNote()
        editor.typeText("# Title\nbody")
        editor.typeText("\nmore")
        XCTAssertEqual(try value(), "# Title\nbody\nmore")
    }

    // MARK: - One undo undoes exactly one formatting edit

    /// Undo is a hardware-keyboard command in the simulator (Cmd-Z); the shake
    /// gesture is not available to a UI test. The editor must still have its
    /// undo history after the bar's edit: assigning `text` wiped it.
    private func undo() {
        editor.typeKey("z", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// The first Cmd-Z of a launch is sometimes swallowed by the simulator's
    /// hardware-keyboard path before any app code sees it (observed: with an
    /// edit already on the stack, the first press did nothing and the second
    /// undid it, in about three runs of four). A press on the still-empty
    /// editor has nothing to undo, so it is harmless, and it is made before
    /// anything under test happens.
    private func warmUpUndoShortcut() throws {
        undo()
        XCTAssertEqual(try value(), "", "the warm-up press must not change an empty note")
    }

    /// Taps a bar button and waits for the text to change. A tap on a bar
    /// button right after typing is sometimes not delivered on the simulator
    /// (seen in the app log: no edit was ever requested), the same flake as
    /// the List menu in #52; tap again only when the text did not change.
    private func tapBar(_ name: String, expecting expected: String) throws {
        for _ in 0..<2 {
            app.buttons[name].firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.8)
            if try value() == expected { return }
        }
        XCTAssertEqual(try value(), expected, "\(name) did not edit the text")
    }

    func testBoldThenUndoOnceRestoresTheExactPreEditText() throws {
        try newNote()
        try warmUpUndoShortcut()
        editor.typeText("abc")
        Thread.sleep(forTimeInterval: 0.5)
        let before = try value()
        XCTAssertEqual(before, "abc")

        try tapBar("Bold", expecting: "abc****")

        undo()
        XCTAssertEqual(try value(), before, "one undo must take back exactly the Bold edit")
        // and the typing before it is still on the undo stack (UIKit undoes
        // typing a few characters at a time, so only "it changed" is asserted)
        undo()
        XCTAssertNotEqual(try value(), before, "the typing was not undoable after the bar's edit")
        XCTAssertTrue("abc".hasPrefix(try value()), "undo of typing changed something else")
    }

    func testHeadingThenUndoOnceRestoresTheExactPreEditText() throws {
        try newNote()
        try warmUpUndoShortcut()
        editor.typeText("title")
        Thread.sleep(forTimeInterval: 0.5)
        try tapBar("Heading", expecting: "# title")
        undo()
        XCTAssertEqual(try value(), "title")
    }

    // MARK: - Tapping places the caret where the tap landed

    /// The editor's own layout, with a heading and a wrapped list item: a tap
    /// on a word must put the caret at that word (the hanging indents change
    /// where the words are, and UIKit must still agree).
    func testTapPlacesTheCaretOnTheHeadingAndOnTheWrappedLine() throws {
        try newNote()
        // the item is long enough to run onto three lines at this width
        let item = "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor whiskey xray yankee zulu alpha bravo charlie delta echo foxtrot golf hotel"
        editor.typeText("# Title\n- \(item)\ntail")
        let expected = "# Title\n- \(item)\n- tail"
        XCTAssertEqual(try value(), expected)

        let itemStart = ("# Title\n- " as NSString).length
        let itemLength = (item as NSString).length
        let top = editor.frame.minY
        let height = editor.frame.height

        func tap(x: CGFloat, y: CGFloat) {
            Thread.sleep(forTimeInterval: 1.2)    // not a double tap
            editor.coordinate(withNormalizedOffset: CGVector(dx: x / editor.frame.width,
                                                             dy: (y - top) / height)).tap()
            Thread.sleep(forTimeInterval: 0.8)
        }

        // on the heading's word "Title": line 1, near the left of the text
        // column (the column starts at x = 56)
        tap(x: 56 + 50, y: top + 8 + 24)
        editor.typeText("§")
        var text = try value()
        var at = try XCTUnwrap(text.range(of: "§")).lowerBound.utf16Offset(in: text)
        XCTAssertTrue((2...7).contains(at), "tap on the heading landed at \(at), not in 'Title'")
        editor.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(try value(), expected)

        // on the middle of the wrapped item: some line after the first, at
        // the right of the column, so well into the item
        tap(x: 330, y: top + 8 + 24 + 36 + 30)
        editor.typeText("§")
        text = try value()
        at = try XCTUnwrap(text.range(of: "§")).lowerBound.utf16Offset(in: text)
        XCTAssertTrue(at > itemStart + 30,
                      "tap on a wrapped line landed on the first line (\(at - itemStart) chars into the item)")
        XCTAssertTrue(at < itemStart + itemLength,
                      "tap on the wrapped item landed past it (\(at - itemStart))")
    }
}

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
