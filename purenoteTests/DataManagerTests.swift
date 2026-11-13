@testable import Purnote
import XCTest

/// Listing a notes directory: classify files vs folders, ignore non-Markdown
/// and the Trash, sort newest-edited-first (by modification date), and never crash on a
/// file whose dates can't be read.
final class DataManagerTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-dm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func write(_ name: String, _ body: String = "x", modified: Date? = nil) throws {
        let url = root.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    private func setModified(_ name: String, _ date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date],
                                              ofItemAtPath: root.appendingPathComponent(name).path)
    }

    private func isolatedPreferences() -> SortPreferences {
        let suite = "purnote-dm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SortPreferences(defaults: defaults)
    }

    func testListsMarkdownFilesAndFoldersButNotTrashOrOtherFiles() throws {
        try write("a.md"); try write("b.md")
        try write("notes.txt")                 // not markdown -> ignored
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Recipes"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".Trash"), withIntermediateDirectories: true)

        let dm = DataManager(url: root)
        XCTAssertEqual(dm.notes.count, 2, "only the two .md files are notes")
        XCTAssertEqual(dm.folders.map(\.id).sorted(), ["Recipes"], "Trash is hidden")
    }

    func testEmptyDirectoryHasNoNotesOrFolders() {
        let dm = DataManager(url: root)
        XCTAssertTrue(dm.notes.isEmpty)
        XCTAssertTrue(dm.folders.isEmpty)
    }

    func testNoteModifiedOnDiskLaterMovesToTopAfterRefresh() throws {
        try write("a.md", modified: Date(timeIntervalSince1970: 2_000_000))
        try write("b.md", modified: Date(timeIntervalSince1970: 1_000_000))
        let dm = DataManager(url: root, sortPreferences: isolatedPreferences())
        XCTAssertEqual(dm.notes.first?.url.lastPathComponent, "a.md")

        // edited elsewhere (Mac, another app): same file, later modification date
        try setModified("b.md", Date(timeIntervalSince1970: 3_000_000))
        dm.refresh(url: root)

        XCTAssertEqual(dm.notes.map { $0.url.lastPathComponent }, ["b.md", "a.md"])
        XCTAssertEqual(dm.notes.first?.date, Date(timeIntervalSince1970: 3_000_000))
    }

    func testEqualDatesOrderByTitleThenName() throws {
        let same = Date(timeIntervalSince1970: 1_500_000)
        try write("z-file.md", "Apple", modified: same)
        try write("b-file.md", "Banana", modified: same)
        try write("a-file.md", "Banana", modified: same)
        for _ in 0..<3 {
            let dm = DataManager(url: root, sortPreferences: isolatedPreferences())
            XCTAssertEqual(dm.notes.map { $0.url.lastPathComponent },
                           ["z-file.md", "a-file.md", "b-file.md"])
        }
    }

    func testFoldersAreSortedCaseInsensitively() throws {
        for name in ["banana", "Apple", "cherry", "apricot"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let dm = DataManager(url: root, sortPreferences: isolatedPreferences())
        XCTAssertEqual(dm.folders.map(\.id), ["Apple", "apricot", "banana", "cherry"])
    }

    func testRootUsesItsOwnSortPreferenceAndSubfolderDefaults() throws {
        let sub = root.appendingPathComponent("Sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        for dir in [root!, sub] {
            try "Zebra".write(to: dir.appendingPathComponent("1.md"), atomically: true, encoding: .utf8)
            try "Apple".write(to: dir.appendingPathComponent("2.md"), atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2_000_000)], ofItemAtPath: dir.appendingPathComponent("1.md").path)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: dir.appendingPathComponent("2.md").path)
        }
        var prefs = isolatedPreferences()
        prefs.set(.title, forFolder: root, root: root)

        let dm = DataManager(url: root, sortPreferences: prefs)
        XCTAssertEqual(dm.notes.map { $0.url.lastPathComponent }, ["2.md", "1.md"], "root sorted by title")
        dm.refresh(url: sub)
        XCTAssertEqual(dm.notes.map { $0.url.lastPathComponent }, ["1.md", "2.md"], "subfolder keeps the default, date edited")
    }

}
