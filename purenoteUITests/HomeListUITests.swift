import XCTest

/// The restyled home screen, driven through the real app.
///
/// Fixture library (fresh per launch, see Storage.uiTestFixture): one note
/// ("Marathon training") in the root and the folders Journal and Recipes, each
/// holding one note. Sort choices are kept in a throwaway store under the
/// fixture, so a test that picks Title does not leak into the next launch.
final class HomeListUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func note() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).firstMatch
    }

    // (a) masthead, a folder, a note

    func testRootShowsMastheadFoldersAndNotes() throws {
        let masthead = element("home.masthead")
        XCTAssertTrue(masthead.waitForExistence(timeout: 20), "no masthead")
        XCTAssertEqual(masthead.label, "Purnote")
        XCTAssertEqual(element("home.meta").label, "1 note")
        XCTAssertTrue(app.staticTexts["Journal"].firstMatch.exists, "no Journal folder in the index")
        XCTAssertTrue(app.staticTexts["Recipes"].firstMatch.exists, "no Recipes folder in the index")
        XCTAssertTrue(note().exists, "the fixture note is not listed")
        XCTAssertTrue(element("home.monthHeader").exists, "date-sorted notes are not under a month heading")
        XCTAssertFalse(element("home.pinnedSection").exists, "a Pinned section with nothing pinned")
    }

    // the whole row opens the note, including the empty space beside a short title

    func testTappingTheEmptySpaceBesideTheTitleOpensTheNote() throws {
        let row = note()
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the fixture note is not listed")
        // Far right of the title line, in screen coordinates: before the fix the
        // row's own frame hugged its text, so a point relative to the row would
        // always have landed on the title and proved nothing.
        let window = app.windows.firstMatch.frame
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: window.width - 24, dy: row.frame.minY + 16)).tap()
        XCTAssertTrue(element("note.kicker").waitForExistence(timeout: 10),
                      "tapping beside the title did not open the note")
    }

    // (b) Sort from the "..." menu: month headings go with Title; a folder keeps its own sort

    func testSortFromTheMenuSwitchesToTitleAndIsPerFolder() throws {
        XCTAssertTrue(element("home.masthead").waitForExistence(timeout: 20))
        XCTAssertTrue(element("home.monthHeader").exists)

        let more = app.buttons["menu.more"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "no \"...\" menu")
        more.tap()
        let title = app.buttons["menu.sort.title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "no Sort > Title in the menu")
        XCTAssertTrue(app.buttons["menu.sort.dateEdited"].firstMatch.exists, "no Sort > Date Edited in the menu")
        XCTAssertTrue(app.buttons["menu.recentlyDeleted"].firstMatch.exists, "Recently Deleted left the root menu")
        title.tap()

        XCTAssertTrue(element("home.monthHeader").waitForNonExistence(timeout: 10),
                      "Title sort should show a plain list, not month groups")
        XCTAssertTrue(note().exists, "the note vanished with the sort change")

        // a folder has its own sort and a menu without Recently Deleted
        app.staticTexts["Journal"].firstMatch.tap()
        XCTAssertTrue(element("home.masthead").waitForExistence(timeout: 10))
        XCTAssertEqual(element("home.masthead").label, "Journal")
        XCTAssertTrue(element("home.monthHeader").waitForExistence(timeout: 10),
                      "Journal inherited the root's Title sort")
        app.buttons["menu.more"].firstMatch.tap()
        XCTAssertTrue(app.buttons["menu.sort.title"].firstMatch.waitForExistence(timeout: 5), "no Sort in a folder's menu")
        XCTAssertFalse(app.buttons["menu.recentlyDeleted"].firstMatch.exists, "Recently Deleted belongs at the root only")
    }

    // (c) Pin from the context menu

    func testPinningANoteMovesItToThePinnedSection() throws {
        let row = note()
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the fixture note is not in the list")
        row.press(forDuration: 1.2)
        let pin = app.buttons["Pin Note"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "no Pin Note in the context menu")
        pin.tap()

        XCTAssertTrue(element("home.pinnedSection").waitForExistence(timeout: 10), "no Pinned section after pinning")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).count, 1,
                       "the pinned note is listed twice")
        XCTAssertFalse(element("home.monthHeader").exists, "the month group stayed although its only note is pinned")
    }

    // (d) the bottom toolbar: search swaps in its field and Cancel brings the bar back

    func testSearchReplacesTheBottomBarAndCancelBringsItBack() throws {
        let search = app.buttons["Search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 20), "no Search button")
        XCTAssertTrue(app.buttons["New folder"].firstMatch.exists, "no New folder button")
        XCTAssertTrue(app.buttons["New note"].firstMatch.exists, "no New note button")
        attach("bottom-bar")

        search.tap()
        let field = app.textFields["Search your notes"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "no search field after tapping Search")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the keyboard did not come up")
        field.typeText("Berlin")
        XCTAssertTrue(element("home.masthead").waitForNonExistence(timeout: 5), "results did not replace the list")
        attach("search-open")

        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Search"].firstMatch.waitForExistence(timeout: 5), "the bar did not come back")
        XCTAssertTrue(element("home.masthead").waitForExistence(timeout: 5), "the list did not come back")
    }

    /// The Undo toast must sit above the bottom bar, not behind it.
    func testUndoToastSitsAboveTheBottomBar() throws {
        let folder = app.staticTexts["Journal"].firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 20))
        folder.press(forDuration: 1.2)
        app.buttons["Delete Folder"].firstMatch.tap()
        app.alerts.buttons["Delete"].firstMatch.tap()
        let undo = app.buttons["undo.button"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "no Undo toast")
        attach("undo-toast")
        let compose = app.buttons["New note"].firstMatch
        XCTAssertLessThanOrEqual(undo.frame.maxY, compose.frame.minY + 1,
                                 "the toast overlaps the bottom bar (undo \(undo.frame), compose \(compose.frame))")
        XCTAssertTrue(undo.isHittable, "the Undo button is covered")
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
