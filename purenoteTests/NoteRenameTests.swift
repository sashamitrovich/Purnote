//
//  NoteRenameTests.swift
//  purenoteTests
//

@testable import Purnote
import XCTest

/// When editing finishes the app may rename the note's file to match its first
/// line -- but only a name the app made itself. A name given by hand on the
/// Mac, or a duplicate number like "Shopping 2", must survive an edit.
final class NoteRenameTests: XCTestCase {

    private var dir: URL!
    private var data: DataManager!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        dir = fm.temporaryDirectory
            .appendingPathComponent("purnote-rename-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        data = DataManager(url: dir)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: dir)
    }

    // MARK: helpers

    /// Writes `fileName` with `onDisk` as its content, and returns the Note as
    /// the editor holds it: content already replaced by what was typed.
    private func makeNote(file fileName: String, onDisk: String, typed: String) throws -> Note {
        let url = dir.appendingPathComponent(fileName)
        try onDisk.write(to: url, atomically: true, encoding: .utf8)
        let note = Note(type: .Note)
        note.id = fileName
        note.url = url
        note.content = typed
        return note
    }

    private func touch(_ fileName: String, _ body: String = "x") throws {
        try body.write(to: dir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    private func files() throws -> [String] {
        try fm.contentsOfDirectory(atPath: dir.path).sorted()
    }

    // MARK: renames that should happen

    func testGeneratedNameIsRenamedToFirstLine() throws {
        let note = try makeNote(file: "1603814400000.md", onDisk: "", typed: "Shopping\n- milk")
        data.finishEditing(note, previousContent: "")
        XCTAssertEqual(try files(), ["Shopping.md"])
        XCTAssertEqual(note.url.lastPathComponent, "Shopping.md")
        XCTAssertEqual(note.id, "Shopping.md")
    }

    func testDerivedNameFollowsTitleChange() throws {
        let note = try makeNote(file: "Shopping.md", onDisk: "Shopping\n- milk", typed: "Groceries\n- milk")
        data.finishEditing(note, previousContent: "Shopping\n- milk")
        XCTAssertEqual(try files(), ["Groceries.md"])
    }

    func testNumberedDuplicateOfDerivedNameFollowsTitleChange() throws {
        try touch("Shopping.md", "Shopping")
        let note = try makeNote(file: "Shopping 2.md", onDisk: "Shopping", typed: "Groceries")
        data.finishEditing(note, previousContent: "Shopping")
        XCTAssertEqual(try files(), ["Groceries.md", "Shopping.md"])
    }

    func testTitleCollisionWithExistingFileGetsSuffixAndAssetsFollow() throws {
        try touch("Groceries.md", "Groceries")
        let note = try makeNote(file: "1603814400000.md", onDisk: "",
                                typed: "Groceries\n![](<1603814400000.assets/image.jpg>)")
        let assets = dir.appendingPathComponent("1603814400000.assets")
        try fm.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: assets.appendingPathComponent("image.jpg"))

        data.finishEditing(note, previousContent: "")

        XCTAssertEqual(note.url.lastPathComponent, "Groceries 2.md")
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("Groceries 2.md").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("Groceries 2.assets/image.jpg").path))
        XCTAssertFalse(fm.fileExists(atPath: assets.path))
        XCTAssertTrue(note.content.contains("Groceries 2.assets/image.jpg"),
                      "the reference follows the folder: \(note.content)")
        let onDisk = try String(contentsOf: dir.appendingPathComponent("Groceries 2.md"), encoding: .utf8)
        XCTAssertTrue(onDisk.contains("Groceries 2.assets/image.jpg"))
    }

    func testCaseOnlyTitleChangeRenames() throws {
        let note = try makeNote(file: "shopping.md", onDisk: "shopping", typed: "Shopping")
        data.finishEditing(note, previousContent: "shopping")
        XCTAssertEqual(try files(), ["Shopping.md"])
    }

    // MARK: renames that must not happen

    func testFileRenamedByHandStaysAfterFirstLineChanges() throws {
        let note = try makeNote(file: "2026-11-12 standup.md", onDisk: "Standup notes",
                                typed: "Standup notes, edited title")
        data.finishEditing(note, previousContent: "Standup notes")
        XCTAssertEqual(try files(), ["2026-11-12 standup.md"])
        XCTAssertEqual(note.url.lastPathComponent, "2026-11-12 standup.md")
    }

    func testFileRenamedByHandStaysWithoutPreviousContent() throws {
        let note = try makeNote(file: "2026-11-12 standup.md", onDisk: "Standup", typed: "Standup 2")
        data.finishEditing(note)
        XCTAssertEqual(try files(), ["2026-11-12 standup.md"])
    }

    func testNumberedDuplicateKeepsItsNameWhenTitleIsUnchanged() throws {
        try touch("Shopping.md", "Shopping")
        let note = try makeNote(file: "Shopping 2.md", onDisk: "Shopping\n- milk", typed: "Shopping\n- milk, eggs")
        data.finishEditing(note, previousContent: "Shopping\n- milk")
        XCTAssertEqual(try files(), ["Shopping 2.md", "Shopping.md"])
        // and again: it must not drift to "Shopping 3"
        data.finishEditing(note, previousContent: "Shopping\n- milk")
        XCTAssertEqual(try files(), ["Shopping 2.md", "Shopping.md"])
        XCTAssertEqual(note.url.lastPathComponent, "Shopping 2.md")
    }

    func testEmptyFirstLineLeavesDerivedNameAlone() throws {
        let note = try makeNote(file: "Shopping.md", onDisk: "Shopping", typed: "")
        data.finishEditing(note, previousContent: "Shopping")
        XCTAssertEqual(try files(), ["Shopping.md"])
    }

    func testEmptyFirstLineLeavesGeneratedNameAlone() throws {
        let note = try makeNote(file: "1603814400000.md", onDisk: "", typed: "\n\n")
        data.finishEditing(note, previousContent: "")
        XCTAssertEqual(try files(), ["1603814400000.md"])
    }

    // MARK: NoteNaming helpers

    func testAvailableURLTreatsExcludedURLAsFree() throws {
        try touch("Shopping.md")
        try touch("Shopping 2.md")
        let own = dir.appendingPathComponent("Shopping 2.md")
        XCTAssertEqual(NoteNaming.availableURL(named: "Shopping", in: dir, excluding: own), own)
        // without the exclusion the next free number is used
        XCTAssertEqual(NoteNaming.availableURL(named: "Shopping", in: dir).lastPathComponent, "Shopping 3.md")
    }

    func testMayRenameRule() {
        // generated
        XCTAssertTrue(NoteNaming.mayRename(stem: "1603814400000", previousContent: nil))
        // derived from previous first line, plain and numbered
        XCTAssertTrue(NoteNaming.mayRename(stem: "Shopping", previousContent: "Shopping\n- milk"))
        XCTAssertTrue(NoteNaming.mayRename(stem: "Shopping 2", previousContent: "Shopping"))
        XCTAssertTrue(NoteNaming.mayRename(stem: "Shopping 17", previousContent: "# Shopping"))
        // not derived
        XCTAssertFalse(NoteNaming.mayRename(stem: "Shopping 1", previousContent: "Shopping"))
        XCTAssertFalse(NoteNaming.mayRename(stem: "Shopping 2x", previousContent: "Shopping"))
        XCTAssertFalse(NoteNaming.mayRename(stem: "Shopping", previousContent: nil))
        XCTAssertFalse(NoteNaming.mayRename(stem: "Standup", previousContent: "Shopping"))
        XCTAssertFalse(NoteNaming.mayRename(stem: "Shopping", previousContent: ""))
    }
}
