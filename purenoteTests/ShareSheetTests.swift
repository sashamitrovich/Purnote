//
//  ShareSheetTests.swift
//  purenoteTests
//
//  The pure logic behind the share sheet's "saves as" line and its folder list.
//

@testable import Purnote
import XCTest

final class ShareSheetTests: XCTestCase {

    // MARK: - the "saves as" line

    func testLineNamesTheFolderAndTheRealFileName() {
        let target = ShareContent.saveTarget(folder: "Travel", content: "Tile museum\n\nhttps://example.com")
        XCTAssertEqual(target.folderName, "Travel")
        XCTAssertEqual(target.fileName, "Tile museum.md")
        XCTAssertEqual(target.line, "Travel \u{00B7} saves as Tile museum.md")
    }

    func testFileNameIsTheOneSaveWillUse() throws {
        // the line must not promise a name the save would not give
        let content = ShareContent.note(text: "## A *bold* post: part 1/2", url: "https://example.com/p")
        let shown = try XCTUnwrap(ShareContent.saveTarget(folder: "", content: content).fileName)

        let inbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSheetTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: inbox) }

        let saved = try SharedInbox.save(content, to: inbox)
        XCTAssertEqual(saved.lastPathComponent, shown)
    }

    func testTopLevelIsCalledNotes() {
        XCTAssertEqual(ShareContent.saveTarget(folder: "", content: "Hello").folderName, "Notes")
    }

    func testNestedFolderShowsItsOwnName() {
        XCTAssertEqual(ShareContent.saveTarget(folder: "Work/Ideas", content: "Hello").folderName, "Ideas")
    }

    func testUnnameableContentShowsOnlyTheFolder() {
        // the fallback name is a timestamp taken at save time, so it is not shown
        let target = ShareContent.saveTarget(folder: "Travel", content: "---")
        XCTAssertNil(target.fileName)
        XCTAssertEqual(target.line, "Travel \u{00B7} named when saved")
        XCTAssertNil(ShareContent.saveTarget(folder: "", content: "").fileName)
    }

    // MARK: - folder list order

    func testTreeOrderPutsSubfoldersUnderTheirParent() {
        // plain string order would give Work, Work 2, Work/Ideas
        let folders = ["Work", "Work 2", "Work/Ideas", "Travel"]
        XCTAssertEqual(SharedInbox.treeOrder(folders), ["Travel", "Work", "Work/Ideas", "Work 2"])
    }

    func testTreeOrderGoesDepthFirst() {
        let folders = ["A", "A/B", "A/B/C", "A/D", "E"]
        XCTAssertEqual(SharedInbox.treeOrder(folders), ["A", "A/B", "A/B/C", "A/D", "E"])
    }

    func testTreeOrderKeepsFoldersWhoseParentIsMissing() {
        XCTAssertEqual(SharedInbox.treeOrder(["Lost/Child", "Zed"]), ["Zed", "Lost/Child"])
    }

    func testTreeOrderOfNothingIsNothing() {
        XCTAssertEqual(SharedInbox.treeOrder([]), [])
    }
}
