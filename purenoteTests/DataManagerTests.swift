@testable import Purnote
import XCTest

/// Listing a notes directory: classify files vs folders, ignore non-Markdown
/// and the Trash, sort newest-first, and — the 1.2 hardening — never crash on a
/// file whose creation date can't be read.
final class DataManagerTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-dm-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func write(_ name: String, _ body: String = "x", created: Date? = nil) throws {
        let url = root.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        if let created {
            try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path)
        }
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

    func testNotesAreSortedNewestFirst() throws {
        let old = Date(timeIntervalSince1970: 1_000_000)
        let new = Date(timeIntervalSince1970: 2_000_000)
        try write("older.md", created: old)
        try write("newer.md", created: new)

        let dm = DataManager(url: root)
        XCTAssertEqual(dm.notes.first?.url.lastPathComponent, "newer.md")
    }

    func testListingDoesNotCrashOnAssortedFiles() throws {
        // Exercises the `as? Date ?? Date()` path that replaced a force-cast.
        try write("normal.md")
        try write("weird name.md", "# Title\n\ncontent")
        XCTAssertNoThrow(DataManager(url: root))
    }
}
