//
//  NoteAssetsTests.swift
//  purenoteTests
//

@testable import Purnote
import XCTest

final class NoteAssetsTests: XCTestCase {

    private var dir: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        dir = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: dir)
    }

    func testFolderURLUsesNoteStem() {
        let note = dir.appendingPathComponent("My Note.md")
        XCTAssertEqual(NoteAssets.folderURL(for: note).lastPathComponent, "My Note.assets")
    }

    func testAddImageWritesFileAndReturnsRelativePath() throws {
        let note = dir.appendingPathComponent("Trip.md")
        let rel = try NoteAssets.addImage(Data([1, 2, 3]), fileExtension: "jpg", to: note)
        XCTAssertEqual(rel, "Trip.assets/image.jpg")
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("Trip.assets/image.jpg").path))
    }

    func testAddImageAvoidsNameClashes() throws {
        let note = dir.appendingPathComponent("Trip.md")
        _ = try NoteAssets.addImage(Data([1]), fileExtension: "jpg", to: note)
        let rel = try NoteAssets.addImage(Data([2]), fileExtension: "jpg", to: note)
        XCTAssertEqual(rel, "Trip.assets/image 2.jpg")
    }

    func testImageMarkdownUsesAngleBrackets() {
        XCTAssertEqual(NoteAssets.imageMarkdown(relativePath: "My Note.assets/photo.jpg"),
                       "![](<My Note.assets/photo.jpg>)")
    }

    func testMoveAssetsFolderKeepsNameAcrossParentMove() throws {
        let note = dir.appendingPathComponent("Trip.md")
        _ = try NoteAssets.addImage(Data([1]), fileExtension: "jpg", to: note)
        let sub = dir.appendingPathComponent("Work", isDirectory: true)
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)

        try NoteAssets.moveAssetsFolder(forNoteAt: note, to: sub.appendingPathComponent("Trip.md"))

        // the folder moved WITH the note, keeping its name so the relative
        // reference still resolves from the note's new location
        XCTAssertTrue(fm.fileExists(atPath: sub.appendingPathComponent("Trip.assets/image.jpg").path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("Trip.assets").path))
    }

    func testMoveAssetsFolderDoesNothingWhenAbsent() throws {
        let note = dir.appendingPathComponent("NoAssets.md")
        try NoteAssets.moveAssetsFolder(forNoteAt: note,
                                        to: dir.appendingPathComponent("elsewhere/NoAssets.md"))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("elsewhere").path))
    }

    func testTrashAssetsFolderDoesNothingWhenAbsent() throws {
        let note = dir.appendingPathComponent("NoAssets.md")
        try NoteAssets.trashAssetsFolder(forNoteAt: note) // no crash, no error
    }
}
