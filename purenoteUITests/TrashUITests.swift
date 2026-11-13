import XCTest

/// Deleting and getting things back, driven through the real app.
///
/// The unit tests cover the logic (toast, list, restore, failures). This class
/// covers what only the running app can show: the context menu reaches the
/// delete, the toast and its Undo button are really on screen and tappable, the
/// "..." menu opens Recently Deleted, and Restore there brings the note home.
///
/// The fixture library is fresh per launch (see Storage.uiTestFixture): one note
/// ("Marathon training") in the root and the folders Journal and Recipes.
final class TrashUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
        app.launch()
    }

    private func note() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Set TEST_RUNNER_SHOT_PAUSE=1 to hold each interesting screen for a second,
    /// so a screenshot can be taken from outside. Without it nothing waits.
    private func pauseForScreenshot() {
        if ProcessInfo.processInfo.environment["SHOT_PAUSE"] != nil { Thread.sleep(forTimeInterval: 2.5) }
    }

    private func deleteNoteFromTheList() {
        let row = note()
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the fixture note is not in the list")
        row.press(forDuration: 1.2)
        let delete = app.buttons["Delete Note"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "no Delete Note in the context menu")
        delete.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "the row is still there after Delete Note")
    }

    // MARK: - A note

    func testDeleteUndoThenDeleteAndRestoreFromRecentlyDeleted() throws {
        // delete -> toast with Undo
        deleteNoteFromTheList()
        let toast = element("undo.toast")
        let undo = app.buttons["undo.button"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "no Undo button after deleting")
        XCTAssertTrue(toast.exists, "no toast container")
        XCTAssertTrue(app.staticTexts["Moved to Recently Deleted"].firstMatch.exists, "the toast does not say where it went")
        pauseForScreenshot()

        // Undo -> the note is back
        undo.tap()
        XCTAssertTrue(note().waitForExistence(timeout: 10), "the note did not come back after Undo")
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5), "the toast stayed after Undo")

        // delete again, then find it in Recently Deleted
        deleteNoteFromTheList()
        let more = app.buttons["menu.more"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "no \"...\" menu on the home screen")
        more.tap()
        let recently = app.buttons["menu.recentlyDeleted"].firstMatch
        XCTAssertTrue(recently.waitForExistence(timeout: 5), "no Recently Deleted entry in the menu")
        XCTAssertTrue(app.buttons["menu.about"].firstMatch.exists, "no About entry in the menu")
        recently.tap()

        XCTAssertTrue(app.navigationBars["Recently Deleted"].waitForExistence(timeout: 10), "Recently Deleted did not open")
        XCTAssertTrue(element("recentlyDeleted.row").waitForExistence(timeout: 10), "no row in Recently Deleted")
        XCTAssertTrue(app.staticTexts["Marathon training"].firstMatch.exists, "the deleted note is not listed by its title")
        XCTAssertTrue(app.staticTexts["Kept until you delete them here."].firstMatch.exists)
        XCTAssertTrue(app.buttons["recentlyDeleted.deleteAll"].firstMatch.isEnabled)
        pauseForScreenshot()

        // Restore -> gone from the list, "Nothing deleted.", and back on the home screen
        let restore = app.buttons["recentlyDeleted.restore"].firstMatch
        XCTAssertTrue(restore.exists, "no Restore button on the row")
        restore.tap()
        XCTAssertTrue(app.staticTexts["Nothing deleted."].firstMatch.waitForExistence(timeout: 10), "the list did not empty")

        app.navigationBars["Recently Deleted"].buttons.firstMatch.tap()
        XCTAssertTrue(note().waitForExistence(timeout: 10), "the restored note is not on the home screen")
    }

    // MARK: - A folder

    func testDeletingAFolderSaysWhereItGoesAndOffersUndo() throws {
        let folder = app.staticTexts["Journal"].firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 20), "no Journal folder in the fixture")
        folder.press(forDuration: 1.2)
        let delete = app.buttons["Delete Folder"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "no Delete Folder in the context menu")
        delete.tap()

        XCTAssertTrue(app.staticTexts["The folder and the notes in it move to Recently Deleted."].firstMatch
            .waitForExistence(timeout: 5), "the confirmation does not say where the folder goes")
        app.alerts.buttons["Delete"].firstMatch.tap()

        XCTAssertTrue(folder.waitForNonExistence(timeout: 10), "the folder row stayed")
        XCTAssertTrue(app.buttons["undo.button"].firstMatch.waitForExistence(timeout: 5), "no Undo after deleting a folder")
        app.buttons["undo.button"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Journal"].firstMatch.waitForExistence(timeout: 10), "the folder did not come back after Undo")
    }
}
