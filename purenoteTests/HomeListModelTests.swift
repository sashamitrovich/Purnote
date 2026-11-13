@testable import Purnote
import XCTest

/// What the home / folder screen shows, decided as a pure function of the notes,
/// the pins, the sort and whether this is the library root.
final class HomeListModelTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US")
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func note(_ name: String, _ when: Date, in folder: String = "/lib") -> Note {
        Note(content: "# \(name)\n\nbody", date: when, path: "\(name).md", isLocal: true,
             url: URL(fileURLWithPath: "\(folder)/\(name).md"))
    }

    private func model(_ notes: [Note], pinned: [Note] = [], sort: NoteSort = .dateEdited,
                       isRoot: Bool = true, name: String = "Purnote", hasFolders: Bool = false) -> HomeListModel {
        HomeListModel(notes: notes, pinned: pinned, sort: sort, isRoot: isRoot, folderName: name,
                      hasFolders: hasFolders, now: date(2026, 11, 13), calendar: calendar)
    }

    private lazy var a = note("Alpha", date(2026, 11, 12))
    private lazy var b = note("Bravo", date(2026, 11, 2))
    private lazy var c = note("Charlie", date(2026, 10, 30))
    private lazy var d = note("Delta", date(2025, 10, 5))

    // MARK: Month groups

    func testMonthGroupsNewestFirstEvenWhenGivenShuffled() {
        let m = model([d, b, c, a])
        XCTAssertEqual(m.sections.map(\.kind), [.month, .month, .month])
        XCTAssertEqual(m.sections.map(\.title), ["November 2026", "October 2026", "October 2025"])
        XCTAssertEqual(m.sections[0].entries.map { $0.note.id }, ["Alpha.md", "Bravo.md"])
    }

    func testMonthEntriesCarryDayAndWeekdayInTheMargin() {
        let m = model([a])
        // 2026-11-12 is a Thursday
        XCTAssertEqual(m.sections[0].entries[0].margin, .day(number: 12, weekday: "Thu"))
    }

    // MARK: Title sort

    func testTitleSortIsOneFlatSectionWithoutDayNumerals() {
        let m = model([d, b, c, a], sort: .title)
        XCTAssertEqual(m.sections.count, 1)
        XCTAssertEqual(m.sections[0].kind, .flat)
        XCTAssertNil(m.sections[0].title)
        XCTAssertEqual(m.sections[0].entries.map { $0.note.id },
                       ["Alpha.md", "Bravo.md", "Charlie.md", "Delta.md"])
        XCTAssertTrue(m.sections[0].entries.allSatisfy { $0.margin == .none })
    }

    // MARK: Pins

    func testPinnedSectionComesFirstAtTheRootAndHasRibbons() {
        let m = model([a, b, c], pinned: [c])
        // Alpha and Bravo are both November, Charlie is pinned
        XCTAssertEqual(m.sections.map(\.kind), [.pinned, .month])
        XCTAssertEqual(m.sections[0].title, "Pinned")
        XCTAssertEqual(m.sections[0].entries.map { $0.note.id }, ["Charlie.md"])
        XCTAssertEqual(m.sections[0].entries[0].margin, .ribbon)
    }

    func testPinnedNoteIsNotRepeatedInTheMonthGroups() {
        let m = model([a, b, c], pinned: [b])
        let monthIDs = m.sections.filter { $0.kind == .month }.flatMap { $0.entries.map { $0.note.id } }
        XCTAssertEqual(monthIDs, ["Alpha.md", "Charlie.md"])
        XCTAssertEqual(m.sections.map(\.title), ["Pinned", "November 2026", "October 2026"])
    }

    func testMonthWithOnlyAPinnedNoteDisappears() {
        let m = model([a, d], pinned: [d])
        XCTAssertEqual(m.sections.map(\.title), ["Pinned", "November 2026"])
    }

    func testPinnedNotDuplicatedInTitleSortEither() {
        let m = model([a, b], pinned: [a], sort: .title)
        XCTAssertEqual(m.sections.map(\.kind), [.pinned, .flat])
        XCTAssertEqual(m.sections[1].entries.map { $0.note.id }, ["Bravo.md"])
    }

    func testNoPinnedSectionInASubfolderAndNothingIsRemoved() {
        let inFolder = note("Alpha", date(2026, 11, 12), in: "/lib/Travel")
        let m = model([inFolder, b], pinned: [inFolder], isRoot: false, name: "Travel")
        XCTAssertEqual(m.sections.map(\.kind), [.month])
        XCTAssertEqual(m.sections[0].entries.count, 2, "a pinned note still shows in its own folder")
        XCTAssertNotEqual(m.sections[0].entries[0].margin, .ribbon)
    }

    func testPinnedFromAnotherFolderShowsAtTheRootAndDoesNotTouchTheMonths() {
        let elsewhere = note("Elsewhere", date(2026, 11, 1), in: "/lib/Travel")
        let m = model([a], pinned: [elsewhere])
        XCTAssertEqual(m.sections.map(\.kind), [.pinned, .month])
        XCTAssertEqual(m.sections[1].entries.map { $0.note.id }, ["Alpha.md"])
        XCTAssertEqual(m.sections[0].entries[0].note.url.path, "/lib/Travel/Elsewhere.md")
    }

    func testSameFileNameInTwoFoldersGetsTwoDistinctEntryIDs() {
        let other = note("Alpha", date(2026, 11, 1), in: "/lib/Travel")
        let m = model([a], pinned: [other])
        let ids = m.sections.flatMap { $0.entries.map(\.id) }
        XCTAssertEqual(Set(ids).count, 2)
    }

    func testPinnedPlaceholderMatchesTheRealNoteInTheList() {
        // the list shows a not-downloaded note under its placeholder name
        let placeholder = Note(content: ".Alpha.md.icloud", date: a.date, path: ".Alpha.md.icloud",
                               isLocal: false, url: URL(fileURLWithPath: "/lib/.Alpha.md.icloud"))
        let m = model([placeholder, b], pinned: [a])
        XCTAssertEqual(m.sections.map(\.kind), [.pinned, .month])
        XCTAssertEqual(m.sections[1].entries.count, 1, "the downloaded pin and its placeholder are one note")
    }

    func testPinOrderIsKept() {
        let m = model([a, b, c], pinned: [c, a])
        XCTAssertEqual(m.sections[0].entries.map { $0.note.id }, ["Charlie.md", "Alpha.md"])
    }

    // MARK: Masthead

    func testMastheadTitleIsPurnoteAtTheRootAndTheFolderNameElsewhere() {
        XCTAssertEqual(model([a]).title, "Purnote")
        XCTAssertEqual(model([a], isRoot: false, name: "Travel").title, "Travel")
    }

    func testLongNamesUseTheSmallerMasthead() {
        XCTAssertFalse(model([a], isRoot: false, name: "Travel").titleIsLong)
        XCTAssertTrue(model([a], isRoot: false, name: "Reading list for the summer").titleIsLong)
    }

    func testCountText() {
        XCTAssertEqual(model([]).countText, "No notes yet")
        XCTAssertEqual(model([a]).countText, "1 note")
        XCTAssertEqual(model([a, b]).countText, "2 notes")
    }

    func testSortNames() {
        XCTAssertEqual(NoteSort.dateEdited.displayName, "Date Edited")
        XCTAssertEqual(NoteSort.title.displayName, "Title")
        XCTAssertEqual(model([a], sort: .title).sortName, "Title")
    }

    func testMetaLineShowsTheSortInFoldersAndNotAtTheRoot() {
        XCTAssertEqual(model([a, b], isRoot: false, name: "Travel").metaLine(location: nil), "2 notes · Date Edited")
        XCTAssertEqual(model([a, b], sort: .title, isRoot: false, name: "Travel").metaLine(location: nil), "2 notes · Title")
        XCTAssertEqual(model([a, b]).metaLine(location: nil), "2 notes")
        XCTAssertEqual(model([a, b]).metaLine(location: "On this iPhone"), "2 notes · On this iPhone")
        XCTAssertFalse(model([a]).showsSort)
        XCTAssertTrue(model([a], isRoot: false, name: "T").showsSort)
    }

    // MARK: Empty states

    func testEmptyLibraryAtTheRoot() {
        XCTAssertEqual(model([]).emptyState, .library)
        XCTAssertTrue(model([]).sections.isEmpty)
    }

    func testEmptyFolder() {
        XCTAssertEqual(model([], isRoot: false, name: "Garden").emptyState, .folder)
    }

    func testNoNotesButFoldersIsAQuietLineNotTheBigEmptyState() {
        XCTAssertEqual(model([], hasFolders: true).emptyState, .noNotes)
        XCTAssertEqual(model([], isRoot: false, name: "Garden", hasFolders: true).emptyState, .noNotes)
    }

    func testPinnedNoteFromAFolderMeansTheRootIsNotEmpty() {
        let elsewhere = note("Elsewhere", date(2026, 11, 1), in: "/lib/Travel")
        let m = model([], pinned: [elsewhere])
        XCTAssertNil(m.emptyState)
        XCTAssertEqual(m.sections.map(\.kind), [.pinned])
    }

    func testNoEmptyStateWhenThereAreNotes() {
        XCTAssertNil(model([a]).emptyState)
    }

    // MARK: Sort preference per folder (DataManager)

    private func isolatedPreferences() -> SortPreferences {
        let suite = "purnote-home-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SortPreferences(defaults: defaults)
    }

    func testSortIsRememberedPerFolderNotSharedWithTheRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-home-\(UUID().uuidString)")
        let sub = root.appendingPathComponent("Sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let prefs = isolatedPreferences()

        let top = DataManager(url: root, sortPreferences: prefs)
        let inner = DataManager(url: sub, sortPreferences: prefs, libraryRoot: root)
        XCTAssertEqual(top.sort, .dateEdited)
        XCTAssertEqual(inner.sort, .dateEdited)

        inner.setSort(.title)
        XCTAssertEqual(inner.sort, .title)
        XCTAssertEqual(top.sort, .dateEdited, "a subfolder's choice must not change the root's")
        XCTAssertEqual(DataManager(url: sub, sortPreferences: prefs, libraryRoot: root).sort, .title, "and it is remembered")
    }

    func testSetSortReordersTheNotes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-home-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        try "Zebra".write(to: root.appendingPathComponent("1.md"), atomically: true, encoding: .utf8)
        try "Apple".write(to: root.appendingPathComponent("2.md"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2_000_000)],
                                              ofItemAtPath: root.appendingPathComponent("1.md").path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)],
                                              ofItemAtPath: root.appendingPathComponent("2.md").path)
        let dm = DataManager(url: root, sortPreferences: isolatedPreferences())
        XCTAssertEqual(dm.notes.map { $0.url.lastPathComponent }, ["1.md", "2.md"])
        dm.setSort(.title)
        XCTAssertEqual(dm.notes.map { $0.url.lastPathComponent }, ["2.md", "1.md"])
    }
}
