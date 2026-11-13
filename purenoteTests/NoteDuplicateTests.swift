@testable import Purnote
import XCTest

/// "Duplicate" on the note screen: a new file "<name> 2.md" beside the note,
/// with its pictures copied and the copy's image references pointing at its own
/// assets folder (never at the original's).
final class NoteDuplicateTests: XCTestCase {

    private var dir: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        dir = fm.temporaryDirectory.appendingPathComponent("dup-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: dir)
    }

    private func write(_ name: String, _ text: String = "# T\n") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: naming

    func testFirstDuplicateIsNameTwo() throws {
        let note = try write("Shopping.md")
        XCTAssertEqual(NoteDuplicate.destination(for: note).lastPathComponent, "Shopping 2.md")
    }

    func testSecondDuplicateIsNameThree() throws {
        let note = try write("Shopping.md")
        _ = try write("Shopping 2.md")
        XCTAssertEqual(NoteDuplicate.destination(for: note).lastPathComponent, "Shopping 3.md")
    }

    func testDuplicateStaysInTheNotesFolder() throws {
        let note = try write("Journal/Day.md")
        XCTAssertEqual(NoteDuplicate.destination(for: note).deletingLastPathComponent().lastPathComponent, "Journal")
    }

    func testAnOrphanedAssetsFolderMakesTheNameTaken() throws {
        // "Shopping 2.md" is free, but "Shopping 2.assets" is not: the copy's
        // pictures would land in somebody else's folder
        let note = try write("Shopping.md")
        try fm.createDirectory(at: dir.appendingPathComponent("Shopping 2.assets"), withIntermediateDirectories: true)
        XCTAssertEqual(NoteDuplicate.destination(for: note).lastPathComponent, "Shopping 3.md")
    }

    // MARK: content

    func testReferencesPointAtTheCopysFolder() {
        let content = "![](<Shopping.assets/image.jpg>)\ntext ![](<Shopping.assets/image 2.png>)"
        let out = NoteDuplicate.rewritingReferences(in: content,
                                                    from: "Shopping.assets", to: "Shopping 2.assets")
        XCTAssertEqual(out, "![](<Shopping 2.assets/image.jpg>)\ntext ![](<Shopping 2.assets/image 2.png>)")
    }

    func testRewriteLeavesAnUnrelatedMentionAlone() {
        // the folder name inside prose that is not an image reference is still
        // plain text; only "<folder>/" (a path) is rewritten
        let content = "I keep Shopping.assets in mind"
        XCTAssertEqual(NoteDuplicate.rewritingReferences(in: content, from: "Shopping.assets", to: "Shopping 2.assets"),
                       content)
    }

    // MARK: the copy on disk

    func testDuplicateCopiesTheNoteAndItsAssets() throws {
        let note = try write("Trip.md", "# Trip\n\n![](<Trip.assets/image.jpg>)\n")
        try fm.createDirectory(at: dir.appendingPathComponent("Trip.assets"), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: dir.appendingPathComponent("Trip.assets/image.jpg"))

        let copy = try NoteDuplicate.duplicate(noteAt: note, content: "# Trip\n\n![](<Trip.assets/image.jpg>)\n")

        XCTAssertEqual(copy.lastPathComponent, "Trip 2.md")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "# Trip\n\n![](<Trip 2.assets/image.jpg>)\n")
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("Trip 2.assets/image.jpg")), Data([1, 2, 3]))
        // the original is untouched
        XCTAssertEqual(try String(contentsOf: note, encoding: .utf8), "# Trip\n\n![](<Trip.assets/image.jpg>)\n")
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("Trip.assets/image.jpg").path))
    }

    func testDuplicateOfANoteWithoutAssetsMakesNoAssetsFolder() throws {
        let note = try write("Plain.md", "hello")
        let copy = try NoteDuplicate.duplicate(noteAt: note, content: "hello")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "hello")
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("Plain 2.assets").path))
    }

    func testDuplicateUsesTheGivenContentNotTheFile() throws {
        // the screen may hold text the file has not caught up with
        let note = try write("N.md", "old")
        let copy = try NoteDuplicate.duplicate(noteAt: note, content: "newer")
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "newer")
    }

    func testDuplicateNeverOverwrites() throws {
        let note = try write("N.md", "a")
        let first = try NoteDuplicate.duplicate(noteAt: note, content: "a")
        let second = try NoteDuplicate.duplicate(noteAt: note, content: "a")
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second.lastPathComponent, "N 3.md")
    }

    func testFailedAssetsCopyRemovesTheHalfMadeNote() throws {
        // the copy of the pictures fails: no note file is left behind claiming
        // pictures it does not have
        let note = try write("Trip.md", "![](<Trip.assets/a.jpg>)")
        try fm.createDirectory(at: dir.appendingPathComponent("Trip.assets"), withIntermediateDirectories: true)
        struct Boom: Error {}
        XCTAssertThrowsError(try NoteDuplicate.duplicate(noteAt: note, content: "![](<Trip.assets/a.jpg>)",
                                                         copyAssets: { _, _ in throw Boom() }))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("Trip 2.md").path))
    }
}
