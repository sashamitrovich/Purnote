//
//  AssetsRewriteGapTests.swift
//  purenoteTests
//
//  Coverage-gap probes from the test-suite audit (gaps 3 and 6): the assets
//  folder rename rewriting more than the image references, and a same-named
//  X.assets folder merging when two libraries are combined. Failing tests are
//  CONFIRMED BUGS and stay failing on purpose.
//

@testable import Purnote
import XCTest

final class AssetsRewriteGapTests: TrashFixtureCase {

    // MARK: Gap 3 -- NoteAssets.renameAssetsFolder rewrites every occurrence of the folder name

    private func renamed(_ content: String) throws -> String {
        let old = try write("Trip.md", content)
        try mkdir("Trip.assets")
        try Data([1]).write(to: url("Trip.assets/image.jpg"))
        let new = url("Trip 2.md")
        try fm.moveItem(at: old, to: new)
        return NoteAssets.renameAssetsFolder(from: old, to: new, content: content)
    }

    func testRenameRewritesTheImageReference() throws {
        let out = try renamed("![](<Trip.assets/image.jpg>)\n")
        XCTAssertEqual(out, "![](<Trip 2.assets/image.jpg>)\n")
        XCTAssertTrue(exists("Trip 2.assets/image.jpg"))
        XCTAssertFalse(exists("Trip.assets"))
    }

    func testRenameLeavesProseMentioningTheFolderNameAlone() throws {
        let content = "![](<Trip.assets/image.jpg>)\nMy Trip.assets backup is on the NAS\n"
        let out = try renamed(content)
        // GAP 3 (fixed; this test guards the fix): prose is rewritten along with the reference
        XCTAssertEqual(out, "![](<Trip 2.assets/image.jpg>)\nMy Trip.assets backup is on the NAS\n")
    }

    func testRenameLeavesALongerFolderNameContainingTheOldOneAlone() throws {
        let content = "![](<Trip.assets/image.jpg>)\n![](<Trip.assets2/other.jpg>)\n![](<Old Trip.assets/x.jpg>)\n"
        let out = try renamed(content)
        // GAP 3 (fixed; this test guards the fix): references into OTHER folders whose name contains
        // "Trip.assets" are rewritten too, which breaks them
        XCTAssertEqual(out, "![](<Trip 2.assets/image.jpg>)\n![](<Trip.assets2/other.jpg>)\n![](<Old Trip.assets/x.jpg>)\n")
    }

    /// For comparison: the Duplicate rewriter (only "<folder>/") on the same inputs.
    func testDuplicateRewriterOnTheSameInputs() {
        let prose = NoteDuplicate.rewritingReferences(in: "My Trip.assets backup\n![](<Trip.assets/image.jpg>)\n",
                                                      from: "Trip.assets", to: "Trip 2.assets")
        XCTAssertEqual(prose, "My Trip.assets backup\n![](<Trip 2.assets/image.jpg>)\n")
        let longer = NoteDuplicate.rewritingReferences(in: "![](<Trip.assets2/o.jpg>)\n![](<Old Trip.assets/x.jpg>)\n",
                                                       from: "Trip.assets", to: "Trip 2.assets")
        // "Trip.assets2/" is safe (needs the slash); "Old Trip.assets/" is NOT (suffix match)
        XCTAssertEqual(longer, "![](<Trip.assets2/o.jpg>)\n![](<Old Trip.assets/x.jpg>)\n",
                       "the Duplicate rewriter also rewrites a reference into \"Old Trip.assets/\"")
    }

    // MARK: Gap 6 -- Storage.move note-name clash with same-named X.assets folders

    func testClashingNoteKeepsPointingAtItsOwnPictures() throws {
        let local = root.appendingPathComponent("local", isDirectory: true)
        let icloud = root.appendingPathComponent("icloud", isDirectory: true)
        func put(_ rel: String, in base: URL, _ data: Data) throws {
            let u = base.appendingPathComponent(rel)
            try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: u)
        }
        let ref = "# Trip\n\n![](<Trip.assets/image.jpg>)\n"
        try put("Trip.md", in: local, Data(ref.utf8))
        try put("Trip.assets/image.jpg", in: local, Data([0xAA]))     // the phone note's picture
        try put("Trip.md", in: icloud, Data(ref.utf8))
        try put("Trip.assets/image.jpg", in: icloud, Data([0xBB]))    // the iCloud note's picture

        let result = Storage.move(from: local, to: icloud)

        let listing = try fm.subpathsOfDirectory(atPath: icloud.path).sorted()
        let renamedURL = icloud.appendingPathComponent("Trip (from iPhone).md")
        let renamedText = try String(contentsOf: renamedURL, encoding: .utf8)

        XCTAssertEqual(result.failed, 0)
        // GAP 6 (fixed; this test guards the fix): the renamed note used to resolve its
        // "Trip.assets/image.jpg" reference to the iCloud note's picture (0xBB).
        XCTAssertEqual(renamedText, "# Trip\n\n![](<Trip (from iPhone).assets/image.jpg>)\n")
        let shown = try Data(contentsOf: icloud.appendingPathComponent("Trip (from iPhone).assets/image.jpg"))
        XCTAssertEqual(Array(shown), [0xAA], "the renamed note shows its own picture")
        XCTAssertEqual(Array(try Data(contentsOf: icloud.appendingPathComponent("Trip.assets/image.jpg"))), [0xBB],
                       "the iCloud note's own picture is untouched; tree=\(listing)")
    }

    /// Gap 6: the phone note's pictures come along under the matching new name,
    /// the iCloud note's own folder is untouched, and nothing is lost.
    func testClashingNoteBringsItsOwnAssetsFolderUnderTheNewName() throws {
        let local = root.appendingPathComponent("local", isDirectory: true)
        let icloud = root.appendingPathComponent("icloud", isDirectory: true)
        func put(_ rel: String, in base: URL, _ data: Data) throws {
            let u = base.appendingPathComponent(rel)
            try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: u)
        }
        try put("Trip.md", in: local, Data("![](<Trip.assets/image.jpg>) Trip.assets stays".utf8))
        try put("Trip.assets/image.jpg", in: local, Data([0xAA]))
        try put("Trip.md", in: icloud, Data("theirs ![](<Trip.assets/image.jpg>)".utf8))
        try put("Trip.assets/image.jpg", in: icloud, Data([0xBB]))
        try put("Trip (from iPhone).assets/squatter.jpg", in: icloud, Data([0xCC]))   // the first free name is taken

        let result = Storage.move(from: local, to: icloud)
        XCTAssertEqual(result.failed, 0)
        let names = try fm.contentsOfDirectory(atPath: icloud.path).sorted()
        XCTAssertEqual(names, ["Trip (from iPhone 2).assets", "Trip (from iPhone 2).md", "Trip (from iPhone).assets",
                               "Trip.assets", "Trip.md"])
        XCTAssertEqual(try String(contentsOf: icloud.appendingPathComponent("Trip (from iPhone 2).md"), encoding: .utf8),
                       "![](<Trip (from iPhone 2).assets/image.jpg>) Trip.assets stays")
        XCTAssertEqual(Array(try Data(contentsOf: icloud.appendingPathComponent("Trip (from iPhone 2).assets/image.jpg"))), [0xAA])
        XCTAssertEqual(Array(try Data(contentsOf: icloud.appendingPathComponent("Trip.assets/image.jpg"))), [0xBB])
        XCTAssertEqual(Array(try Data(contentsOf: icloud.appendingPathComponent("Trip (from iPhone).assets/squatter.jpg"))), [0xCC])
        XCTAssertEqual(try String(contentsOf: icloud.appendingPathComponent("Trip.md"), encoding: .utf8),
                       "theirs ![](<Trip.assets/image.jpg>)")
        XCTAssertFalse(fm.fileExists(atPath: local.appendingPathComponent("Trip.md").path))
    }
}
