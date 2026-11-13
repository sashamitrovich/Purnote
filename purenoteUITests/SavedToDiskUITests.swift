import XCTest

/// Coverage-gap probes (audit gaps 1b and 7): does what the user types reach
/// the FILE, and does a checkbox tick overwrite a file that changed on disk.
///
/// The fixture library is a folder in the app's own tmp directory
/// ("purnote-uitest-<UUID>", see Storage.uiTestFixtureRoot). On the simulator
/// the test runner can read the app's container, so the tests find that folder
/// by looking at the sibling containers of their own (newest "purnote-uitest-*"
/// folder that holds "Marathon training.md") and read/write the files there.
///
/// Tests that fail here are CONFIRMED BUGS and are left failing on purpose.
final class SavedToDiskUITests: XCTestCase {

    private var app: XCUIApplication!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
        app.launch()
    }

    /// The fixture library of the app launched by this test.
    private func fixtureRoot() throws -> URL {
        // <...>/Containers/Data/Application/<runner GUID>/tmp/  ->  .../Application
        let applications = URL(fileURLWithPath: NSTemporaryDirectory())
            .deletingLastPathComponent().deletingLastPathComponent()
        var found: [(URL, Date)] = []
        for container in (try? fm.contentsOfDirectory(at: applications, includingPropertiesForKeys: nil)) ?? [] {
            let tmp = container.appendingPathComponent("tmp")
            for dir in (try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? []
            where dir.lastPathComponent.hasPrefix("purnote-uitest-")
                && fm.fileExists(atPath: dir.appendingPathComponent("Marathon training.md").path) {
                let made = (try? dir.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                found.append((dir, made))
            }
        }
        let newest = found.max { $0.1 < $1.1 }
        return try XCTUnwrap(newest?.0, "could not find the app's fixture library under \(applications.path)")
    }

    private func allMarkdown(in root: URL) -> [URL] {
        (fm.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "md" }
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    // MARK: Gap 1b

    /// New note, type, Done: the typed text must be in a .md file in the library.
    func testTypedTextAndDoneReachTheFileOnDisk() throws {
        let root = try fixtureRoot()
        let compose = app.buttons["New note"].firstMatch
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "no New note button")
        compose.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "editor never appeared")
        editor.tap()
        Thread.sleep(forTimeInterval: 0.6)
        editor.typeText("hello persists")

        // before Done: the one-second autosave debounce alone must have written it
        let autosaved = waitUntil(4) {
            allMarkdown(in: root).contains { (try? String(contentsOf: $0, encoding: .utf8)) == "hello persists" }
        }
        XCTAssertTrue(autosaved, "typed text did not reach a file within 4 s of the last keystroke")

        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "no Done button")
        done.tap()
        Thread.sleep(forTimeInterval: 1.0)

        let hits = allMarkdown(in: root).filter {
            (try? String(contentsOf: $0, encoding: .utf8))?.contains("hello persists") == true
        }
        XCTAssertEqual(hits.count, 1, "exactly one file holds the typed text after Done")
        XCTAssertEqual(hits.first.flatMap { try? String(contentsOf: $0, encoding: .utf8) }, "hello persists")
    }

    // MARK: Gap 7

    /// Open the note on the rendered page, change the file on disk behind the
    /// app's back (what a Mac edit arriving through iCloud does), then tick a
    /// checkbox. The tick writes the whole in-memory text, so the on-disk
    /// change must not survive only if the bug is real.
    func testTickingACheckboxKeepsAnEditMadeOnDiskAfterTheNoteWasLoaded() throws {
        let root = try fixtureRoot()
        let file = root.appendingPathComponent("Marathon training.md")

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marathon training")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "fixture note not in the list")
        row.tap()
        let box = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Fri —")).firstMatch
        XCTAssertTrue(box.waitForExistence(timeout: 10), "no checkbox on the page")
        Thread.sleep(forTimeInterval: 1.0)

        // the "Mac" edit
        let marker = "EDITED ELSEWHERE AFTER LOAD"
        let original = try String(contentsOf: file, encoding: .utf8)
        try (original + "\n\(marker)\n").write(to: file, atomically: true, encoding: .utf8)

        box.tap()
        Thread.sleep(forTimeInterval: 1.5)

        let onDisk = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(onDisk.contains("- [x] Fri"), "test setup: the tick did not reach the file")
        // GAP 7 (fixed; this test guards the fix): the tick rewrote the file from stale in-memory text
        XCTAssertTrue(onDisk.contains(marker), "the tick overwrote a change made on disk after the note was loaded")
    }
}
