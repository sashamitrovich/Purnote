@testable import Purnote
import XCTest

final class NoteSortTests: XCTestCase {

    private func note(_ name: String, _ content: String, _ seconds: TimeInterval) -> Note {
        Note(content: content, date: Date(timeIntervalSince1970: seconds), path: name, isLocal: true,
             url: URL(fileURLWithPath: "/lib/\(name)"))
    }

    // MARK: date edited

    func testDateEditedIsNewestFirst() {
        let notes = [note("a.md", "A", 10), note("b.md", "B", 30), note("c.md", "C", 20)]
        XCTAssertEqual(NoteSort.sorted(notes, by: .dateEdited).map(\.id), ["b.md", "c.md", "a.md"])
    }

    func testDateEditedTiesBreakByTitleThenName() {
        let notes = [note("z.md", "Apple", 10), note("b.md", "Banana", 10), note("a.md", "Banana", 10)]
        let expected = ["z.md", "a.md", "b.md"]
        XCTAssertEqual(NoteSort.sorted(notes, by: .dateEdited).map(\.id), expected)
        XCTAssertEqual(NoteSort.sorted(notes.reversed(), by: .dateEdited).map(\.id), expected,
                       "input order must not matter")
    }

    // MARK: title

    func testTitleIsCaseInsensitive() {
        let notes = [note("1.md", "banana", 1), note("2.md", "Apple", 1), note("3.md", "cherry", 1)]
        XCTAssertEqual(NoteSort.sorted(notes, by: .title).map(\.id), ["2.md", "1.md", "3.md"])
    }

    func testTitleIsDiacriticInsensitive() {
        let notes = [note("1.md", "Zebra", 1), note("2.md", "Émile", 1), note("3.md", "Eagle", 1)]
        XCTAssertEqual(NoteSort.sorted(notes, by: .title).map(\.id), ["3.md", "2.md", "1.md"])
    }

    func testTitleUsesNaturalNumberOrder() {
        let notes = [note("1.md", "Note 10", 1), note("2.md", "Note 2", 1), note("3.md", "Note 1", 1)]
        XCTAssertEqual(NoteSort.sorted(notes, by: .title).map(\.id), ["3.md", "2.md", "1.md"])
    }

    func testTitleIgnoresMarkdownHeadingMarker() {
        let notes = [note("1.md", "# Beta", 1), note("2.md", "Alpha", 1)]
        XCTAssertEqual(NoteSort.sorted(notes, by: .title).map(\.id), ["2.md", "1.md"])
    }

    func testTitleTiesBreakByNewestThenName() {
        let notes = [note("b.md", "Same", 10), note("a.md", "Same", 10), note("c.md", "Same", 20)]
        XCTAssertEqual(NoteSort.sorted(notes, by: .title).map(\.id), ["c.md", "a.md", "b.md"])
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(NoteSort.dateEdited.rawValue, "dateEdited")
        XCTAssertEqual(NoteSort.title.rawValue, "title")
        XCTAssertEqual(NoteSort.allCases.count, 2, "Date Created must not be an option")
    }

    // MARK: folders

    func testFoldersSortCaseInsensitivelyByName() {
        let folders = ["banana", "Apple", "cherry", "apricot"].map {
            Folder(id: $0, url: URL(fileURLWithPath: "/lib/\($0)"))
        }
        XCTAssertEqual(FolderSort.sorted(folders).map(\.id), ["Apple", "apricot", "banana", "cherry"])
    }

    // MARK: preferences

    private func defaults() -> UserDefaults {
        let suite = "purnote-sort-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        addTeardownBlock { d.removePersistentDomain(forName: suite) }
        return d
    }

    func testPreferenceDefaultsToDateEdited() {
        let prefs = SortPreferences(defaults: defaults())
        let root = URL(fileURLWithPath: "/lib")
        XCTAssertEqual(prefs.sort(forFolder: root, root: root), .dateEdited)
        XCTAssertEqual(prefs.sort(forFolder: root.appendingPathComponent("Trips"), root: root), .dateEdited)
    }

    func testPreferenceIsPerFolderAndRootHasItsOwn() {
        var prefs = SortPreferences(defaults: defaults())
        let root = URL(fileURLWithPath: "/lib")
        let trips = root.appendingPathComponent("Trips")
        let nested = trips.appendingPathComponent("Italy")

        prefs.set(.title, forFolder: trips, root: root)
        XCTAssertEqual(prefs.sort(forFolder: trips, root: root), .title)
        XCTAssertEqual(prefs.sort(forFolder: root, root: root), .dateEdited, "root unaffected")
        XCTAssertEqual(prefs.sort(forFolder: nested, root: root), .dateEdited, "nested unaffected")

        prefs.set(.title, forFolder: root, root: root)
        prefs.set(.dateEdited, forFolder: trips, root: root)
        XCTAssertEqual(prefs.sort(forFolder: root, root: root), .title)
        XCTAssertEqual(prefs.sort(forFolder: trips, root: root), .dateEdited)
    }

    func testPreferencePersistsAcrossInstances() {
        let d = defaults()
        let root = URL(fileURLWithPath: "/lib")
        var first = SortPreferences(defaults: d)
        first.set(.title, forFolder: root, root: root)
        XCTAssertEqual(SortPreferences(defaults: d).sort(forFolder: root, root: root), .title)
    }

    func testRelativePath() {
        let root = URL(fileURLWithPath: "/lib/Documents")
        XCTAssertEqual(SortPreferences.relativePath(of: root, root: root), "")
        XCTAssertEqual(SortPreferences.relativePath(of: root.appendingPathComponent("A/B"), root: root), "A/B")
        XCTAssertEqual(SortPreferences.relativePath(of: URL(fileURLWithPath: "/lib/Documents/A/"), root: root), "A")
    }

    func testUnknownStoredValueFallsBackToDefault() {
        let d = defaults()
        let root = URL(fileURLWithPath: "/lib")
        d.set("dateCreated", forKey: SortPreferences.key(forRelativePath: ""))
        XCTAssertEqual(SortPreferences(defaults: d).sort(forFolder: root, root: root), .dateEdited)
    }

    // MARK: date helper

    func testModifiedDateReadsContentModificationDate() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nd-\(UUID().uuidString).md")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let when = Date(timeIntervalSince1970: 1_234_567)
        try FileManager.default.setAttributes([.modificationDate: when], ofItemAtPath: url.path)
        XCTAssertEqual(NoteDates.modified(of: url), when)
    }

    func testModifiedDateOfMissingFileIsNow() {
        let d = NoteDates.modified(of: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).md"))
        XCTAssertLessThan(abs(d.timeIntervalSinceNow), 5)
    }
}
