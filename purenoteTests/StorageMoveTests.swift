//
//  StorageMoveTests.swift
//  purenoteTests
//
//  Moving the local library into iCloud merges folders of the same name. A
//  failed move must never end with the source folder deleted: `.purnote`
//  (pins, the trash) exists on both sides, so a recursive remove of it would
//  delete trashed notes.
//

@testable import Purnote
import XCTest

final class StorageMoveTests: TrashFixtureCase {

    private var local: URL { root.appendingPathComponent("local", isDirectory: true) }
    private var icloud: URL { root.appendingPathComponent("icloud", isDirectory: true) }

    private func put(_ rel: String, in base: URL, _ text: String = "x") throws {
        let u = base.appendingPathComponent(rel)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: u, atomically: true, encoding: .utf8)
    }

    private func has(_ rel: String, in base: URL) -> Bool { fm.fileExists(atPath: base.appendingPathComponent(rel).path) }

    private func failing(on names: Set<String>) -> (URL, URL) throws -> Void {
        return { from, to in
            if names.contains(from.lastPathComponent) { throw Injected() }
            try CoordinatedFile.move(from: from, to: to)
        }
    }

    func testFailedMoveOfTheTrashFolderKeepsTheTrashedNotes() throws {
        try put(".purnote/trash/20260101120000-A/Gone.md", in: local, "trashed note")
        try put(".purnote/trash/20260101120000-A/origin.json", in: local, "{}")
        try put(".purnote/pins.json", in: icloud, "{\"version\":1,\"pins\":[]}")   // .purnote exists on both sides
        let result = Storage.move(from: local, to: icloud, mover: failing(on: ["trash"]))
        XCTAssertEqual(result.failed, 1)
        XCTAssertEqual(try String(contentsOf: local.appendingPathComponent(".purnote/trash/20260101120000-A/Gone.md")), "trashed note")
        XCTAssertTrue(has(".purnote/trash/20260101120000-A/origin.json", in: local))
    }

    func testFailedMoveOfOneItemFolderKeepsItAndMovesTheOthers() throws {
        try put(".purnote/trash/20260101120000-A/A.md", in: local, "a")
        try put(".purnote/trash/20260101120000-B/B.md", in: local, "b")
        try put(".purnote/trash/20260101120000-OLD/Old.md", in: icloud, "old")     // trash exists on both sides
        let result = Storage.move(from: local, to: icloud, mover: failing(on: ["20260101120000-A"]))
        XCTAssertEqual(result.failed, 1)
        XCTAssertTrue(has(".purnote/trash/20260101120000-A/A.md", in: local), "the one that failed is still where it was")
        XCTAssertTrue(has(".purnote/trash/20260101120000-B/B.md", in: icloud), "the other moved")
        XCTAssertTrue(has(".purnote/trash/20260101120000-OLD/Old.md", in: icloud))
    }

    func testFailedMoveOfANoteInAMergedFolderKeepsTheNote() throws {
        try put("Recipes/A.md", in: local, "a")
        try put("Recipes/B.md", in: local, "b")
        try put("Recipes/Existing.md", in: icloud, "e")
        let result = Storage.move(from: local, to: icloud, mover: failing(on: ["A.md"]))
        XCTAssertEqual(result.failed, 1)
        XCTAssertEqual(try String(contentsOf: local.appendingPathComponent("Recipes/A.md")), "a")
        XCTAssertTrue(has("Recipes/B.md", in: icloud))
        XCTAssertFalse(has("Recipes/B.md", in: local))
    }

    func testCleanMergeRemovesTheEmptiedSourceFolders() throws {
        try put("Recipes/A.md", in: local, "a")
        try put(".purnote/trash/20260101120000-A/A.md", in: local, "t")
        try put("Recipes/Existing.md", in: icloud, "e")
        try put(".purnote/trash/20260101120000-OLD/Old.md", in: icloud, "old")
        let result = Storage.move(from: local, to: icloud)
        XCTAssertEqual(result.failed, 0)
        XCTAssertFalse(has("Recipes", in: local), "emptied, so removed")
        XCTAssertFalse(has(".purnote", in: local))
        XCTAssertTrue(has("Recipes/A.md", in: icloud))
        XCTAssertTrue(has(".purnote/trash/20260101120000-A/A.md", in: icloud))
    }

    func testAMergedSourceFolderThatIsNotEmptyIsNeverRemovedRecursively() throws {
        // a hidden .Trash inside a same-named folder is skipped by the move and so is left behind
        try put("Recipes/A.md", in: local, "a")
        try put("Recipes/.Trash/old.md", in: local, "keep me")
        try put("Recipes/Existing.md", in: icloud, "e")
        let result = Storage.move(from: local, to: icloud)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(try String(contentsOf: local.appendingPathComponent("Recipes/.Trash/old.md")), "keep me")
        XCTAssertTrue(has("Recipes/A.md", in: icloud))
    }
}
