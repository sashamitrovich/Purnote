//
//  PinListTests.swift
//  purenoteTests
//

@testable import Purnote
import XCTest

/// The pin list is a pure value: an ordered set of note paths relative to the
/// library root. Everything the app does to it (pin, rename, move, delete,
/// prune, merge) is checked here without touching a disk.
final class PinListTests: XCTestCase {

    // MARK: - add / remove / toggle

    func testAddKeepsPinOrder() {
        var list = PinList()
        list.add("b.md"); list.add("a.md"); list.add("Folder/c.md")
        XCTAssertEqual(list.paths, ["b.md", "a.md", "Folder/c.md"])
    }

    func testAddingTwiceDoesNotDuplicate() {
        var list = PinList(["a.md"])
        list.add("a.md")
        XCTAssertEqual(list.paths, ["a.md"])
    }

    func testInitDropsDuplicatesKeepingFirst() {
        XCTAssertEqual(PinList(["a.md", "b.md", "a.md"]).paths, ["a.md", "b.md"])
    }

    func testRemove() {
        var list = PinList(["a.md", "b.md"])
        list.remove("a.md")
        XCTAssertEqual(list.paths, ["b.md"])
        list.remove("missing.md")
        XCTAssertEqual(list.paths, ["b.md"])
    }

    func testToggleAddsThenRemovesAndReportsState() {
        var list = PinList()
        XCTAssertTrue(list.toggle("a.md"), "first toggle pins")
        XCTAssertTrue(list.contains("a.md"))
        XCTAssertFalse(list.toggle("a.md"), "second toggle unpins")
        XCTAssertFalse(list.contains("a.md"))
    }

    func testUnusablePathsAreIgnored() {
        var list = PinList(["", "/abs.md", "../escape.md", "a/../b.md", "ok.md"])
        list.add("")
        list.add("../x.md")
        XCTAssertEqual(list.paths, ["ok.md"])
    }

    // MARK: - rename / move

    func testRenamingANoteRewritesItsPath() {
        let list = PinList(["a.md", "Folder/b.md", "c.md"])
        XCTAssertEqual(list.renamed(from: "Folder/b.md", to: "Folder/B2.md").paths,
                       ["a.md", "Folder/B2.md", "c.md"], "position is kept")
    }

    func testMovingANoteToAnotherFolderRewritesItsPath() {
        let list = PinList(["Inbox/a.md", "b.md"])
        XCTAssertEqual(list.renamed(from: "Inbox/a.md", to: "Archive/a.md").paths,
                       ["Archive/a.md", "b.md"])
        XCTAssertEqual(list.renamed(from: "Inbox/a.md", to: "a.md").paths, ["a.md", "b.md"],
                       "dropped to the top level")
    }

    func testRenamingAFolderRewritesEveryPathUnderIt() {
        let list = PinList(["Notes/a.md", "Notes/Deep/Deeper/b.md", "other.md"])
        XCTAssertEqual(list.renamed(from: "Notes", to: "Journal").paths,
                       ["Journal/a.md", "Journal/Deep/Deeper/b.md", "other.md"])
    }

    func testFolderRenameMatchesWholeComponentsOnly() {
        // "Notes" must not match "Notes 2" or "Notes.md"-style prefixes
        let list = PinList(["Notes/a.md", "Notes 2/b.md", "Notes.md", "NotesX/c.md"])
        XCTAssertEqual(list.renamed(from: "Notes", to: "Journal").paths,
                       ["Journal/a.md", "Notes 2/b.md", "Notes.md", "NotesX/c.md"])
    }

    func testMovingAFolderIntoAnotherRewritesNestedPaths() {
        let list = PinList(["Recipes/Soup.md", "Recipes 2/x.md"])
        XCTAssertEqual(list.renamed(from: "Recipes", to: "Kitchen/Recipes").paths,
                       ["Kitchen/Recipes/Soup.md", "Recipes 2/x.md"])
    }

    func testRenameOfAnUnpinnedPathChangesNothing() {
        let list = PinList(["a.md"])
        XCTAssertEqual(list.renamed(from: "zzz.md", to: "yyy.md"), list)
    }

    func testRenameOntoAnAlreadyPinnedPathLeavesNoDuplicate() {
        let list = PinList(["a.md", "b.md"])
        XCTAssertEqual(list.renamed(from: "a.md", to: "b.md").paths, ["b.md"])
    }

    func testRenameTolerantOfTrailingSlash() {
        let list = PinList(["Notes/a.md"])
        XCTAssertEqual(list.renamed(from: "Notes/", to: "Journal/").paths, ["Journal/a.md"])
    }

    // MARK: - delete

    func testRemovingAPathDropsThatNote() {
        let list = PinList(["a.md", "Folder/b.md"])
        XCTAssertEqual(list.removing(prefix: "Folder/b.md").paths, ["a.md"])
    }

    func testRemovingAFolderDropsEverythingUnderItOnly() {
        let list = PinList(["Notes/a.md", "Notes/Deep/b.md", "Notes 2/c.md", "Notes.md", "keep.md"])
        XCTAssertEqual(list.removing(prefix: "Notes").paths,
                       ["Notes 2/c.md", "Notes.md", "keep.md"])
    }

    func testRemovingEmptyPrefixChangesNothing() {
        let list = PinList(["a.md"])
        XCTAssertEqual(list.removing(prefix: ""), list)
    }

    // MARK: - prune

    func testPrunedDropsPathsWhoseFileIsGone() {
        let list = PinList(["a.md", "gone.md", "Folder/b.md"])
        XCTAssertEqual(list.pruned(existingPaths: ["a.md", "Folder/b.md", "unpinned.md"]).paths,
                       ["a.md", "Folder/b.md"])
    }

    func testPrunedWithPredicate() {
        let list = PinList(["a.md", "gone.md"])
        XCTAssertEqual(list.pruned(where: { $0 == "a.md" }).paths, ["a.md"])
    }

    // MARK: - merge

    func testMergeIsUnionKeepingOrderWithoutDuplicates() {
        let icloud = PinList(["a.md", "b.md"])
        let iphone = PinList(["c.md", "a.md", "d.md"])
        XCTAssertEqual(icloud.merged(with: iphone).paths, ["a.md", "b.md", "c.md", "d.md"])
    }

    func testMergeWithEmptyIsIdentity() {
        let list = PinList(["a.md"])
        XCTAssertEqual(list.merged(with: PinList()), list)
        XCTAssertEqual(PinList().merged(with: list), list)
    }

    // MARK: - paths relative to the library root

    func testRelativePathOfANoteInsideTheRoot() {
        let root = URL(fileURLWithPath: "/lib/root", isDirectory: true)
        XCTAssertEqual(PinPath.relative(of: URL(fileURLWithPath: "/lib/root/Folder/a.md"), in: root),
                       "Folder/a.md")
        XCTAssertEqual(PinPath.relative(of: URL(fileURLWithPath: "/lib/root/a.md"), in: root), "a.md")
    }

    func testRelativePathOutsideTheRootIsNil() {
        let root = URL(fileURLWithPath: "/lib/root", isDirectory: true)
        XCTAssertNil(PinPath.relative(of: URL(fileURLWithPath: "/lib/root2/a.md"), in: root))
        XCTAssertNil(PinPath.relative(of: root, in: root), "the root itself is not a note")
    }

    func testRelativePathIgnoresPrivatePrefixAndTrailingSlash() {
        let root = URL(fileURLWithPath: "/private/var/x/lib/", isDirectory: true)
        XCTAssertEqual(PinPath.relative(of: URL(fileURLWithPath: "/var/x/lib/Folder/a.md"), in: root),
                       "Folder/a.md")
    }

    func testRelativePathOfAnICloudPlaceholderIsTheRealNote() {
        let root = URL(fileURLWithPath: "/lib", isDirectory: true)
        XCTAssertEqual(PinPath.relative(of: URL(fileURLWithPath: "/lib/Folder/.Note.md.icloud"), in: root),
                       "Folder/Note.md")
    }
}
