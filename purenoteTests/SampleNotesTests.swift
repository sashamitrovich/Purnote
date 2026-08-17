@testable import Purnote
import XCTest

/// The first-run sample library. It ships in the App Store screenshots, so it
/// must stay well-formed: unique paths, real content, a visible title on every
/// note, and the "how to delete everything" guide present.
final class SampleNotesTests: XCTestCase {

    func testLibraryIsNotEmpty() {
        XCTAssertGreaterThan(SampleNotes.all.count, 5)
    }

    func testAllPathsAreUniqueRelativeMarkdownFiles() {
        let paths = SampleNotes.all.map(\.path)
        XCTAssertEqual(Set(paths).count, paths.count, "no duplicate paths")
        for p in paths {
            XCTAssertTrue(p.hasSuffix(".md"), "\(p) is a .md file")
            XCTAssertFalse(p.hasPrefix("/"), "\(p) is relative, not absolute")
            XCTAssertFalse(p.contains(".."), "\(p) does not escape the root")
        }
    }

    func testEveryNoteHasContentAndAVisibleTitle() {
        for (path, content) in SampleNotes.all {
            XCTAssertFalse(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(path) has content")
            XCTAssertFalse(NoteRowText.title(of: content).isEmpty, "\(path) renders a non-empty title in the list")
        }
    }

    func testIncludesTheDeleteEverythingGuide() {
        XCTAssertTrue(SampleNotes.all.contains { $0.path == "Managing your notes.md" })
    }

    func testFolderedNotesLiveUnderRealFolders() {
        let folders = Set(SampleNotes.all.map(\.path)
            .filter { $0.contains("/") }
            .map { String($0.split(separator: "/").first!) })
        // just a sanity bound: a handful of top-level folders, none empty-named
        XCTAssertFalse(folders.contains(""))
        XCTAssertLessThanOrEqual(folders.count, 8)
    }
}
