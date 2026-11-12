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

    // MARK: - firstRun (issue #55)

    private let rootTwo = ["Welcome to Purnote.md", "Managing your notes.md"]

    func testFirstRunHasOnlyTwoRootNotesAndTheRestUnderExamples() {
        let paths = SampleNotes.firstRun.map(\.path)
        let roots = paths.filter { !$0.contains("/") }
        XCTAssertEqual(Set(roots), Set(rootTwo))
        XCTAssertEqual(roots.count, 2)
        for p in paths where !rootTwo.contains(p) {
            XCTAssertTrue(p.hasPrefix("Examples/"), "\(p) lives under Examples/")
            XCTAssertEqual(p.split(separator: "/").count, 2, "\(p) is flat inside Examples")
        }
    }

    func testFirstRunKeepsEveryOtherNoteFromAll() {
        let examples = SampleNotes.firstRun.filter { $0.path.hasPrefix("Examples/") }.map(\.content)
        let others = SampleNotes.all.filter { !rootTwo.contains($0.path) }
        XCTAssertEqual(examples.count, others.count)
        for note in others {
            XCTAssertTrue(examples.contains(note.content), "\(note.path) is in Examples")
        }
    }

    func testFirstRunPathsAreUnique() {
        let paths = SampleNotes.firstRun.map(\.path)
        XCTAssertEqual(Set(paths).count, paths.count)
    }

    func testNoNoteMentionsSwipe() {
        for (path, content) in SampleNotes.all + SampleNotes.firstRun {
            XCTAssertFalse(content.lowercased().contains("swipe"), "\(path) must not mention swipe")
        }
    }

    func testWhyItMattersHasNoTaskMarkers() {
        let welcome = SampleNotes.all.first { $0.path == "Welcome to Purnote.md" }!.content
        let section = welcome.components(separatedBy: "## Why it matters")[1]
            .components(separatedBy: "\n## ")[0]
        XCTAssertFalse(section.contains("- [x]"))
        XCTAssertFalse(section.contains("- [ ]"))
        XCTAssertTrue(section.contains("- Your notes are just files"))
    }

    func testMarathonNoteUnchanged() {
        let m = SampleNotes.all.first { $0.path == "Marathon training.md" }!.content
        XCTAssertTrue(m.hasPrefix("# Marathon training\n\nSixteen weeks to Berlin. Keep it boring, keep it consistent, and trust the plan on the days you would rather not.\n\n## This week — build 3\n- [x] Mon — easy 8 km, nose-breathing only"))
    }

    func testUITestFixturePathsStillExistInAll() {
        let paths = Set(SampleNotes.all.map(\.path))
        for p in ["Marathon training.md", "Journal/Morning pages.md", "Recipes/Sourdough.md"] {
            XCTAssertTrue(paths.contains(p), "\(p)")
        }
    }

    func testManagingNoteExplainsDeletingAndExamples() {
        let m = SampleNotes.all.first { $0.path == "Managing your notes.md" }!.content
        XCTAssertTrue(m.contains("Touch and hold it in the list, then choose Delete"))
        XCTAssertTrue(m.contains("**Examples**"))
        XCTAssertTrue(m.contains("On My iPhone"))
    }
}
