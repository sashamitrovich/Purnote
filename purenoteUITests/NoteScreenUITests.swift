import XCTest

/// The note screen (reading view), driven through the real app.
///
/// Fixture library (fresh per launch, see Storage.uiTestFixture): "Marathon
/// training" in the root, the folders Journal and Recipes.
///
/// Menu items are addressed by their LABEL ("Pin", "Delete"): on the iOS 27
/// runtime UITests cannot see accessibility identifiers of items inside a Menu
/// (known issue #52). The buttons on the bar itself (note.edit, note.more) are
/// found by identifier.
final class NoteScreenUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches on the fixture library. `accessibility` runs the app at the
    /// AX-XL content size, where New York is far bigger than at the default.
    private func launch(accessibility: Bool = false) {
        app = XCUIApplication()
        app.launchArguments += ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
        if accessibility {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        }
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func marathonRow() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).firstMatch
    }

    private var editor: XCUIElement { app.textViews.firstMatch }

    private func openMarathon() {
        let row = marathonRow()
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the fixture note is not in the list")
        row.tap()
        XCTAssertTrue(element("note.kicker").waitForExistence(timeout: 10), "the note did not open")
    }

    private func openMoreMenu() {
        let more = app.buttons["note.more"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "no \"...\" button on the note")
        more.tap()
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: - (a) kicker and Edit

    func testKickerAndEditButtonExist() throws {
        launch()
        openMarathon()

        let kicker = element("note.kicker")
        // a note at the library root: "Purnote · Edited ..."; never the file name
        XCTAssertTrue(kicker.label.lowercased().hasPrefix("purnote · edited"),
                      "unexpected kicker: \(kicker.label)")
        XCTAssertFalse(kicker.label.contains(".md"), "the kicker shows the file name: \(kicker.label)")
        XCTAssertFalse(kicker.label.contains("Untitled"), "the kicker says Untitled: \(kicker.label)")
        XCTAssertFalse(element("note.ribbon").exists, "a ribbon on a note that is not pinned")

        let edit = app.buttons["note.edit"].firstMatch
        XCTAssertTrue(edit.exists, "no Edit button")
        XCTAssertEqual(edit.label, "Edit")
        XCTAssertTrue(app.buttons["note.more"].firstMatch.exists, "no \"...\" button")

        // Edit opens the editor
        edit.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "Edit did not open the editor")
    }

    // MARK: - (b) Pin from the menu

    func testPinFromTheMenuShowsTheRibbonAndListsTheNoteUnderPinned() throws {
        launch()
        openMarathon()
        XCTAssertFalse(element("note.ribbon").exists)

        openMoreMenu()
        let pin = app.buttons["Pin"].firstMatch   // by label (see the class comment)
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "no Pin in the menu")
        pin.tap()

        XCTAssertTrue(element("note.ribbon").waitForExistence(timeout: 5), "no ribbon after pinning")

        // back to the list: the note is under Pinned, once
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("home.pinnedSection").waitForExistence(timeout: 10), "no Pinned section after going back")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).count, 1,
                       "the pinned note is listed twice")

        // and the menu now offers Unpin
        marathonRow().tap()
        XCTAssertTrue(element("note.ribbon").waitForExistence(timeout: 10), "the ribbon is gone after reopening")
        openMoreMenu()
        XCTAssertTrue(app.buttons["Unpin"].firstMatch.waitForExistence(timeout: 5), "no Unpin in the menu of a pinned note")
    }

    // MARK: - (c) Delete from the menu

    func testDeleteFromTheMenuReturnsToTheListWithUndo() throws {
        launch()
        openMarathon()

        openMoreMenu()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "no Delete in the menu")
        delete.tap()

        // back on the list, the toast is up, the note is gone
        let undo = app.buttons["undo.button"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 10), "no Undo toast after deleting from the note")
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].firstMatch.exists)
        XCTAssertTrue(element("home.masthead").exists, "did not go back to the list")
        XCTAssertFalse(marathonRow().exists, "the note is still in the list")

        undo.tap()
        XCTAssertTrue(marathonRow().waitForExistence(timeout: 10), "the note did not come back after Undo")
    }

    // MARK: - Duplicate and Move from the menu

    func testDuplicateFromTheMenuAddsACopyToTheList() throws {
        launch()
        openMarathon()
        openMoreMenu()
        let duplicate = app.buttons["Duplicate"].firstMatch
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5), "no Duplicate in the menu")
        duplicate.tap()

        XCTAssertTrue(element("home.masthead").waitForExistence(timeout: 10), "did not go back to the list")
        let copy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).element(boundBy: 1)
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "no second note in the list after Duplicate")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).count, 2)
    }

    func testMoveFromTheMenuMovesTheNoteAndLeavesTheScreen() throws {
        launch()
        openMarathon()
        openMoreMenu()
        let move = app.buttons["Move to Folder\u{2026}"].firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 5), "no Move to Folder in the menu")
        move.tap()

        /// The element with this label that is on screen: the home list behind the
        /// sheet has a "Journal" too.
        func hittable(_ label: String) -> XCUIElement {
            let query = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
            for _ in 0..<20 {
                if let found = query.allElementsBoundByIndex.first(where: { $0.isHittable }) { return found }
                Thread.sleep(forTimeInterval: 0.5)
            }
            return query.firstMatch
        }
        let journal = hittable("Journal")
        XCTAssertTrue(journal.exists, "no Journal in the Move sheet")
        journal.tap()
        let here = hittable("Move to Journal")
        XCTAssertTrue(here.exists, "no \"Move to Journal\" in the Move sheet")
        here.tap()

        // the sheet closes and the note screen is left: its note is no longer where it was
        XCTAssertTrue(element("home.masthead").waitForExistence(timeout: 10), "did not go back to the list")
        XCTAssertFalse(marathonRow().exists, "the note is still in the root list")
    }

    // MARK: - (d) Serif body, spike S5: tap-to-caret and link taps, at two sizes

    /// A note with three paragraphs, the second long (it wraps onto many lines)
    /// and opening with a link. Made through the editor so the test needs no
    /// access to the library.
    private func makeFieldNotes() throws {
        let compose = app.buttons["New note"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 20), "no New note button")
        compose.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor never appeared")
        editor.tap()
        Thread.sleep(forTimeInterval: 0.6)
        editor.typeText("# Field notes\n\nFirst paragraph. It is short and plain.\n\n"
            + "[Tile museum](https://example.com) opens in the browser when tapped. The rest of this paragraph "
            + "is long on purpose so that it wraps onto several lines at the default text size and onto many "
            + "more at an accessibility size, which is what the caret check needs.\n\n"
            + "Third paragraph closes the note.")
        app.buttons["Done"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Field notes")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the new note is not in the list")
        row.tap()
        XCTAssertTrue(element("note.kicker").waitForExistence(timeout: 10), "the note did not open")
    }

    private func paragraph(containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Taps near the end of the long second paragraph, opens the editor and
    /// checks the caret landed inside that paragraph, in its second half --
    /// found by typing a marker, the only way to see a caret from outside.
    private func assertTapPutsTheCaretInTheParagraph() throws {
        let long = paragraph(containing: "opens in the browser")
        XCTAssertTrue(long.waitForExistence(timeout: 10), "the second paragraph is not on the page")
        // At an accessibility size this paragraph is taller than the screen: scroll
        // until its end is on screen, then tap the last line, four fifths along it
        // (12 pt up from the bottom edge, which stays on that line at any size).
        var tries = 0
        while long.frame.maxY > app.frame.maxY - 140, tries < 8 {
            app.swipeUp()
            tries += 1
        }
        long.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 1.0)).withOffset(CGVector(dx: 0, dy: -12)).tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "tapping the paragraph did not open the editor")
        Thread.sleep(forTimeInterval: 1.5)

        editor.typeText("§")
        let typed = try XCTUnwrap(editor.value as? String)
        let marker = try XCTUnwrap(typed.range(of: "§"), "marker was not typed")
        let at = typed.distance(from: typed.startIndex, to: marker.lowerBound)
        // positions are measured in the text without the marker, so a marker
        // that landed inside a phrase does not hide the phrase
        let text = typed.replacingOccurrences(of: "§", with: "")

        let start = text.distance(from: text.startIndex,
                                  to: try XCTUnwrap(text.range(of: "[Tile museum]"), "paragraph start not in \(text)").lowerBound)
        let end = text.distance(from: text.startIndex,
                                to: try XCTUnwrap(text.range(of: "the caret check needs."), "paragraph end not in \(text)").upperBound)

        XCTAssertTrue(at > start, "caret landed before the paragraph (\(at) vs \(start))")
        XCTAssertTrue(at <= end + 2, "caret landed past the paragraph (\(at) vs end \(end))")
        XCTAssertTrue(at > start + (end - start) / 2,
                      "caret landed in the first half of the paragraph, not where the tap was (\(at - start) of \(end - start))")
    }

    /// Taps the link at the start of the second paragraph: Safari opens, the editor does not.
    private func assertTapOnTheLinkOpensIt() throws {
        let long = paragraph(containing: "opens in the browser")
        XCTAssertTrue(long.waitForExistence(timeout: 10), "the second paragraph is not on the page")
        // inside the first word of the first line, an absolute offset so it
        // stays on that line however many lines the paragraph wraps to
        long.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 22, dy: 11)).tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        let opened = safari.wait(for: .runningForeground, timeout: 20)
        let editorOpened = opened ? false : editor.exists
        if opened { app.activate() }
        XCTAssertTrue(opened, "tapping the link did not open it (editor opened: \(editorOpened))")
        XCTAssertFalse(app.textViews.firstMatch.waitForExistence(timeout: 2), "the link tap also opened the editor")
    }

    func testS5TapPutsTheCaretInTheParagraph_defaultSize() throws {
        launch()
        try makeFieldNotes()
        try assertTapPutsTheCaretInTheParagraph()
    }

    func testS5LinkTapOpensTheLink_defaultSize() throws {
        launch()
        try makeFieldNotes()
        try assertTapOnTheLinkOpensIt()
    }

    func testS5TapPutsTheCaretInTheParagraph_accessibilitySize() throws {
        launch(accessibility: true)
        try makeFieldNotes()
        try assertTapPutsTheCaretInTheParagraph()
    }

    func testS5LinkTapOpensTheLink_accessibilitySize() throws {
        launch(accessibility: true)
        try makeFieldNotes()
        try assertTapOnTheLinkOpensIt()
    }

    // MARK: - Screenshots (run on request: TEST_RUNNER_M4A_SHOTS=default|ax)

    /// Not a check: takes the pictures for the milestone report, light and
    /// dark, of the Marathon note (headings, list, checklist, table, quote),
    /// pinned and not, and of a note with a link. Skipped unless asked for.
    func testShots() throws {
        let mode = ProcessInfo.processInfo.environment["M4A_SHOTS"]
        try XCTSkipIf(mode == nil, "screenshots only on request")
        let size = mode ?? "default"
        launch(accessibility: size == "ax")
        XCUIDevice.shared.appearance = .light
        // leave the simulator in light mode (`.unspecified` is not a value it accepts)
        defer { XCUIDevice.shared.appearance = .light }

        openMarathon()
        Thread.sleep(forTimeInterval: 1)
        attach("note-light-\(size)-top")
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        Thread.sleep(forTimeInterval: 0.5)
        attach("note-light-\(size)-bottom-quote")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)

        openMoreMenu()
        let pin = app.buttons["Pin"].firstMatch
        if pin.waitForExistence(timeout: 5) { pin.tap() }
        XCTAssertTrue(element("note.ribbon").waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        attach("note-light-\(size)-pinned")

        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: 1.5)
        attach("note-dark-\(size)-pinned")
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        Thread.sleep(forTimeInterval: 0.5)
        attach("note-dark-\(size)-bottom-quote")

        openMoreMenu()
        Thread.sleep(forTimeInterval: 0.8)
        attach("note-dark-\(size)-menu")
        XCUIDevice.shared.appearance = .light
        Thread.sleep(forTimeInterval: 1.0)
        attach("note-light-\(size)-menu")
        // close the menu by tapping the page outside it
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.97)).tap()
        Thread.sleep(forTimeInterval: 0.8)

        // back and make the note with a link
        app.navigationBars.buttons.element(boundBy: 0).tap()
        try makeFieldNotes()
        Thread.sleep(forTimeInterval: 1)
        attach("link-note-light-\(size)")
        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: 1.5)
        attach("link-note-dark-\(size)")
    }
}
