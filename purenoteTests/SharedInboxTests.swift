//
//  SharedInboxTests.swift
//  purenoteTests
//
//  Tests for the App Group inbox: how shared notes get named, listed and moved
//  into the app's storage. They exercise the logic against temp directories
//  rather than the real group container, which the unit-test bundle has no
//  entitlement to reach.
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

    // MARK: - pendingNotes

    func testPendingNotesListsOnlyMarkdownFiles() throws {
        try SharedInbox.save("one", to: inbox)
        try SharedInbox.save("two", to: inbox)
        // a non-.md file and a subfolder are both ignored
        try "not a note".write(to: inbox.appendingPathComponent("ignore.txt"),
                               atomically: true, encoding: .utf8)
        try fm.createDirectory(at: inbox.appendingPathComponent("folder", isDirectory: true),
                               withIntermediateDirectories: true)

        let pending = SharedInbox.pendingNotes(in: inbox)
        XCTAssertEqual(pending.map(\.lastPathComponent).sorted(), ["one.md", "two.md"])
    }

    // MARK: - import

    func testImportMovesNoteIntoRoot() throws {
        try SharedInbox.save("Incoming note", to: inbox)

        XCTAssertEqual(SharedInbox.importNotes(from: inbox, into: root), 1)
        XCTAssertTrue(SharedInbox.pendingNotes(in: inbox).isEmpty)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["Incoming note.md"])
        XCTAssertEqual(try CoordinatedFile.read(root.appendingPathComponent("Incoming note.md")),
                       "Incoming note")
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
}
