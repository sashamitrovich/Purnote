//
//  SharedInboxTests.swift
//  purenoteTests
//
//  Tests for the App Group hand-off: how shared notes get named, placed in a
//  folder, and moved into the app's storage, plus the folder catalog the app
//  mirrors for the extension's picker. They exercise the logic against temp
//  directories rather than the real group container, which the unit-test
//  bundle has no entitlement to reach.
//

@testable import Purnote
import XCTest

final class SharedInboxTests: XCTestCase {

    private var inbox: URL!
    private var root: URL!
    private var base: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        base = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        inbox = base.appendingPathComponent("inbox", isDirectory: true)
        root = base.appendingPathComponent("root", isDirectory: true)
        try fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: base)
    }

    // MARK: - save

    func testSaveNamesNoteFromFirstLine() throws {
        let url = try SharedInbox.save("Hello shared world", to: inbox)
        XCTAssertEqual(url.lastPathComponent, "Hello shared world.md")
        XCTAssertEqual(try CoordinatedFile.read(url), "Hello shared world")
    }

    func testSaveAvoidsNameClashes() throws {
        let first = try SharedInbox.save("Same", to: inbox)
        let second = try SharedInbox.save("Same", to: inbox)
        XCTAssertEqual(first.lastPathComponent, "Same.md")
        XCTAssertEqual(second.lastPathComponent, "Same 2.md")
    }

    func testSaveIntoFolderCreatesTheSubdirectory() throws {
        let url = try SharedInbox.save("filed", to: inbox, in: "Work/Ideas")
        XCTAssertEqual(url.lastPathComponent, "filed.md")
        XCTAssertTrue(fm.fileExists(atPath: url.path))
        XCTAssertTrue(url.path.contains("/Work/Ideas/"))
    }

    // MARK: - import

    func testImportMovesNoteIntoRoot() throws {
        try SharedInbox.save("Incoming note", to: inbox)

        XCTAssertEqual(SharedInbox.importNotes(from: inbox, into: root), 1)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["Incoming note.md"])
        XCTAssertEqual(try CoordinatedFile.read(root.appendingPathComponent("Incoming note.md")),
                       "Incoming note")
    }

    func testImportPreservesTheChosenFolder() throws {
        try SharedInbox.save("filed", to: inbox, in: "Work")

        XCTAssertEqual(SharedInbox.importNotes(from: inbox, into: root), 1)
        let destination = root.appendingPathComponent("Work/filed.md")
        XCTAssertTrue(fm.fileExists(atPath: destination.path))
        XCTAssertEqual(try CoordinatedFile.read(destination), "filed")
    }

    func testImportCreatesAFolderThatDoesNotExistYet() throws {
        try SharedInbox.save("filed", to: inbox, in: "New Folder")

        XCTAssertEqual(SharedInbox.importNotes(from: inbox, into: root), 1)
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent("New Folder/filed.md").path))
    }

    func testImportAvoidsClashWithExistingNote() throws {
        try SharedInbox.save("Clash", to: inbox)
        try CoordinatedFile.write("old", to: root.appendingPathComponent("Clash.md"))

        XCTAssertEqual(SharedInbox.importNotes(from: inbox, into: root), 1)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path).sorted(),
                       ["Clash 2.md", "Clash.md"])
        XCTAssertEqual(try CoordinatedFile.read(root.appendingPathComponent("Clash 2.md")),
                       "Clash")
    }

    func testImportIntoEmptyInboxReturnsZero() {
        XCTAssertEqual(SharedInbox.importNotes(from: inbox, into: root), 0)
    }

    // MARK: - folder catalog

    func testFoldersEnumeratesNestedDirectories() throws {
        try fm.createDirectory(at: root.appendingPathComponent("Work"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Work/Ideas"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Archive"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".Trash"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".purnote"), withIntermediateDirectories: true)
        try "note".write(to: root.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)

        XCTAssertEqual(SharedInbox.folders(in: root),
                       ["Archive", "Work", "Work/Ideas"])
    }

    func testChildFoldersListsDirectChildrenOnly() {
        let catalog = ["Work/Ideas/Deep", "Work", "Work/Notes", "Archive", "Work/Ideas", "Personal"]

        XCTAssertEqual(SharedInbox.childFolders(of: "", in: catalog),
                       ["Archive", "Personal", "Work"])
        XCTAssertEqual(SharedInbox.childFolders(of: "Work", in: catalog),
                       ["Work/Ideas", "Work/Notes"])
        XCTAssertEqual(SharedInbox.childFolders(of: "Work/Ideas", in: catalog),
                       ["Work/Ideas/Deep"])
        XCTAssertEqual(SharedInbox.childFolders(of: "Archive", in: catalog), [])
        XCTAssertEqual(SharedInbox.childFolders(of: "", in: []), [])
    }

    func testSuggestedFolderFallsBackWhenLastIsGone() {
        let available = ["Archive", "Work", "Work/Ideas"]

        XCTAssertEqual(SharedInbox.suggestedFolder(lastUsed: "Work/Ideas", in: available),
                       "Work/Ideas")
        XCTAssertEqual(SharedInbox.suggestedFolder(lastUsed: "Deleted", in: available), "")
        XCTAssertEqual(SharedInbox.suggestedFolder(lastUsed: "", in: available), "")
    }

    func testCatalogRoundTripsThroughJson() throws {
        let url = base.appendingPathComponent("folders.json")
        SharedInbox.writeCatalog(["Work/Ideas", "Work", "Archive"], to: url)

        XCTAssertEqual(SharedInbox.readCatalog(from: url),
                       ["Archive", "Work", "Work/Ideas"])
    }

    func testReadCatalogFromMissingFileReturnsEmpty() {
        XCTAssertEqual(SharedInbox.readCatalog(from: base.appendingPathComponent("nope.json")), [])
    }
}
