//
//  SmartFolderTests.swift
//  purenoteTests
//

@testable import Purnote
import XCTest

final class SmartFolderTests: XCTestCase {

    private var root: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    // MARK: - matching

    func testMatchesRequiresEveryTag() {
        let folder = SmartFolder(name: "Work", tags: ["work", "ideas"])
        XCTAssertTrue(folder.matches(noteTags: ["Work", "Ideas", "other"]))
        XCTAssertFalse(folder.matches(noteTags: ["Work"]))
        XCTAssertFalse(folder.matches(noteTags: []))
    }

    func testMatchingIsCaseInsensitive() {
        let folder = SmartFolder(name: "Work", tags: ["Work"])
        XCTAssertTrue(folder.matches(noteTags: ["WORK"]))
    }

    func testEmptyTagListMatchesNothing() {
        let folder = SmartFolder(name: "Empty", tags: [])
        XCTAssertFalse(folder.matches(noteTags: ["anything"]))
    }

    // MARK: - persistence

    func testStoreRoundTrips() throws {
        let folders = [
            SmartFolder(name: "Work", tags: ["work"]),
            SmartFolder(name: "Read", tags: ["read-later"]),
        ]
        try SmartFolderStore.save(folders, to: root)

        let loaded = SmartFolderStore.load(from: root)
        XCTAssertEqual(loaded.map(\.name), ["Work", "Read"])
        XCTAssertEqual(loaded.map(\.tags), [["work"], ["read-later"]])
    }

    func testLoadFromEmptyRootReturnsEmpty() {
        XCTAssertEqual(SmartFolderStore.load(from: root), [])
    }
}
