//
//  PersistenceGapTests.swift
//  purenoteTests
//
//  Coverage-gap probes from the test-suite audit (gaps 1a, 2, 5): does the
//  text the user typed reach the file, what happens when the rename's
//  follow-up write fails, and what is left behind when the assets half of a
//  move fails. Tests that fail here are CONFIRMED BUGS: they are left failing
//  on purpose, each with a comment naming the gap and the observed result.
//

@testable import Purnote
import XCTest

/// A Note that runs a closure the moment `content` is assigned, so a test can
/// break the file system at an exact point inside `finishEditing` (between the
/// rename and the write that follows it) without a seam in production code.
final class HookedNote: Note {
    var onContentSet: (() -> Void)?
    override var content: String {
        didSet { let hook = onContentSet; onContentSet = nil; hook?() }
    }
}

final class PersistenceGapTests: XCTestCase {

    private var root: URL!
    private var immutablePaths: [URL] = []
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory
            .appendingPathComponent("purnote-gap-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for url in immutablePaths {
            try? fm.setAttributes([.immutable: false], ofItemAtPath: url.path)
        }
        try? fm.removeItem(at: root)
    }

    private func isolatedPreferences() -> SortPreferences {
        let suite = "purnote-gap-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SortPreferences(defaults: defaults)
    }

    private func manager(_ url: URL? = nil) -> DataManager {
        DataManager(url: url ?? root, sortPreferences: isolatedPreferences())
    }

    private func text(_ rel: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
    }

    private func mdFiles(_ rel: String = "") -> [String] {
        let dir = rel.isEmpty ? root! : root.appendingPathComponent(rel)
        return ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".md") }.sorted()
    }

    // MARK: Gap 1a -- typed text reaches the disk

    /// What the autosave tick does for a brand new note: NoteEdit.save() calls
    /// data.persist(note). (The one-second debounce itself is a SwiftUI
    /// ViewModifier and is not reachable from a unit test; see the UI test.)
    func testPersistWritesTypedTextOfANewNoteToItsFile() throws {
        let dm = manager()
        let note = Note(type: .Note)
        note.content = "hello persists"
        dm.persist(note)

        XCTAssertEqual(note.url.deletingLastPathComponent().standardizedFileURL.path,
                       root.standardizedFileURL.path)
        XCTAssertEqual(try String(contentsOf: note.url, encoding: .utf8), "hello persists")
        XCTAssertTrue(dm.notes.contains { $0.id == note.id }, "the new note is in the list")

        // more typing, next debounce tick
        note.content = "hello persists, and more"
        dm.persist(note)
        XCTAssertEqual(try String(contentsOf: note.url, encoding: .utf8), "hello persists, and more")
    }

    /// Editing an existing file and saving overwrites it with the new text.
    func testPersistOverwritesAnExistingNoteWithTheEditedText() throws {
        try "old text".write(to: root.appendingPathComponent("Plan.md"), atomically: true, encoding: .utf8)
        let dm = manager()
        let note = try XCTUnwrap(dm.notes.first)
        note.content = "old text, plus edit"
        dm.persist(note)
        XCTAssertEqual(text("Plan.md"), "old text, plus edit")
        XCTAssertEqual(mdFiles(), ["Plan.md"])
    }

    /// Done / dismissal: NoteEdit.finish() -> finishEditing. The text must be
    /// on disk under the new name, and the old file must be gone.
    func testFinishEditingLeavesTheTypedTextOnDiskUnderTheNameFromItsFirstLine() throws {
        let dm = manager()
        let note = Note(type: .Note)
        note.content = "# Shopping list\n\nmilk"
        let generated = note.content
        dm.finishEditing(note, previousContent: generated)   // generated (timestamp) name -> may rename
        XCTAssertEqual(mdFiles(), ["Shopping list.md"])
        XCTAssertEqual(text("Shopping list.md"), "# Shopping list\n\nmilk")
        XCTAssertEqual(note.url.lastPathComponent, "Shopping list.md")
    }

    /// The editor keeps typing after a finish (autosave tick, then Done, then
    /// the onDisappear flush runs finish a second time): one file, latest text.
    func testSaveThenFinishTwiceLeavesOneFileWithTheLatestText() throws {
        let dm = manager()
        let note = Note(type: .Note)
        note.content = "# Idea"
        dm.persist(note)                                   // autosave tick
        note.content = "# Idea\n\nhello persists"
        dm.finishEditing(note, previousContent: "# Idea")  // Done
        dm.finishEditing(note, previousContent: "# Idea")  // onDisappear flush
        XCTAssertEqual(mdFiles(), ["Idea.md"])
        XCTAssertEqual(text("Idea.md"), "# Idea\n\nhello persists")
    }

    // MARK: Gap 2 -- rename succeeds, the follow-up write fails

    /// DataManager.finishEditing moves the note, renames the assets folder,
    /// rewrites the references and writes that text to the new file. If that
    /// write throws, it returns before `note.url = target`, so the Note still
    /// points at the OLD path, which no longer exists. The next persist (the
    /// onDisappear flush that runs right after Done) writes the Note's text to
    /// the old path again and the user has two notes.
    ///
    /// The write is made to fail without touching production code: a Note
    /// subclass flags the already-moved file immutable the moment finishEditing
    /// assigns the rewritten content (just before the write), so the atomic
    /// replace of that file fails.
    func testFailedWriteAfterRenameDoesNotLeaveTwoCopiesOfTheNote() throws {
        let stem = "1603814400000"
        let original = "# Trip\n\n![](<\(stem).assets/image.jpg>)\n"
        let oldURL = root.appendingPathComponent("\(stem).md")
        try original.write(to: oldURL, atomically: true, encoding: .utf8)
        let assets = root.appendingPathComponent("\(stem).assets", isDirectory: true)
        try fm.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: assets.appendingPathComponent("image.jpg"))

        let dm = manager()
        let note = HookedNote(content: original, date: Date(), path: "\(stem).md",
                              isLocal: true, url: oldURL, type: .Note)
        let renamedURL = root.appendingPathComponent("Trip.md")
        note.onContentSet = { [self] in
            // the move has happened; make the next write to the new file fail
            try? fm.setAttributes([.immutable: true], ofItemAtPath: renamedURL.path)
            immutablePaths.append(renamedURL)
        }

        dm.finishEditing(note, previousContent: original)   // Done
        let afterDone = mdFiles()
        let urlAfterDone = note.url.lastPathComponent
        dm.persist(note)                                     // onDisappear flush / next autosave
        let afterFlush = mdFiles()

        // Observed state, quoted in the audit report.

        XCTAssertNil(note.onContentSet, "test setup: the rename path with a rewritten reference was not reached")
        // GAP 2 (fixed; this test guards the fix): after a failed follow-up write the note exists twice,
        // e.g. ["1603814400000.md", "Trip.md"] -- old name with the new text, new name with the old text.
        let detail = afterFlush.map { "\($0) => \(text($0)?.debugDescription ?? "nil")" }.joined(separator: " | ")
        XCTAssertEqual(afterFlush.count, 1, "the note must still be ONE file after a failed write; got: \(detail); after Done: files=\(afterDone) note.url=\(urlAfterDone)")
    }

    // MARK: Gap 5 -- DataManager.move (MoveNoteSheet.moveNote has the same two steps)

    private func makeTrip(withImage bytes: [UInt8]) throws -> URL {
        let note = root.appendingPathComponent("Trip.md")
        try "# Trip\n\n![](<Trip.assets/image.jpg>)\n".write(to: note, atomically: true, encoding: .utf8)
        let assets = root.appendingPathComponent("Trip.assets", isDirectory: true)
        try fm.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data(bytes).write(to: assets.appendingPathComponent("image.jpg"))
        return note
    }

    func testMoveCarriesTheAssetsFolderAlongWithTheNote() throws {
        _ = try makeTrip(withImage: [1, 1, 1])
        try fm.createDirectory(at: root.appendingPathComponent("Work"), withIntermediateDirectories: true)
        let dm = manager()
        let note = try XCTUnwrap(dm.notes.first { $0.id == "Trip.md" })
        dm.move(note: note, to: root.appendingPathComponent("Work"))
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent("Work/Trip.md").path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("Work/Trip.assets/image.jpg")), Data([1, 1, 1]))
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent("Trip.assets").path))
    }

    /// The second step (assets) fails after the note already moved, because
    /// the destination already holds a folder with that name. The error is
    /// only printed. The note is now in Work/ and its relative reference
    /// "Trip.assets/image.jpg" resolves to the OTHER folder's picture, while its
    /// own pictures stay behind in the old folder.
    func testFailedAssetsMoveAfterTheNoteMovedLeavesARecoverableState() throws {
        _ = try makeTrip(withImage: [1, 1, 1])
        let work = root.appendingPathComponent("Work", isDirectory: true)
        try fm.createDirectory(at: work.appendingPathComponent("Trip.assets"), withIntermediateDirectories: true)
        try Data([9, 9, 9]).write(to: work.appendingPathComponent("Trip.assets/image.jpg"))   // someone else's picture
        let dm = manager()
        let note = try XCTUnwrap(dm.notes.first { $0.id == "Trip.md" })
        dm.move(note: note, to: work)

        let noteMoved = fm.fileExists(atPath: work.appendingPathComponent("Trip.md").path)
        let ownPicturesLeftBehind = fm.fileExists(atPath: root.appendingPathComponent("Trip.assets/image.jpg").path)
        let picturesTheNoteNowShows = try? Data(contentsOf: work.appendingPathComponent("Trip.assets/image.jpg"))

        // GAP 5 (fixed; this test guards the fix): the note moved but its pictures did not, and no error reaches the user.
        // Acceptable end states: the note rolled back with its pictures, or both moved.
        XCTAssertFalse(noteMoved && ownPicturesLeftBehind,
                       "note moved to Work/ but its pictures stayed in the old folder (failure only printed); Work/Trip.assets/image.jpg now holds \(String(describing: picturesTheNoteNowShows.map { Array($0) })) (the note's own picture was [1, 1, 1]); old Trip.assets/image.jpg still exists: \(ownPicturesLeftBehind)")
    }

    /// Gap 5: the assets step fails for another reason (injected) after the
    /// note moved. The note must be moved back, with its pictures, and the
    /// user told.
    func testAssetsMoveFailingAfterTheNoteMovedPutsTheNoteBackAndReportsIt() throws {
        _ = try makeTrip(withImage: [1, 1, 1])
        let work = root.appendingPathComponent("Work", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        struct Injected: Error {}
        let dm = manager()
        let note = try XCTUnwrap(dm.notes.first { $0.id == "Trip.md" })
        let failure = dm.move(note: note, to: work, moveAssets: { _, _ in throw Injected() })
        XCTAssertNotNil(failure, "the failure must reach the caller")
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent("Trip.md").path), "note is back where it was")
        XCTAssertEqual(Array(try Data(contentsOf: root.appendingPathComponent("Trip.assets/image.jpg"))), [1, 1, 1])
        XCTAssertFalse(fm.fileExists(atPath: work.appendingPathComponent("Trip.md").path))
    }

    /// Gap 5: an assets folder of that name in the target is somebody else's:
    /// nothing moves, nothing is overwritten.
    func testMoveNeverTouchesAnExistingAssetsFolderInTheTarget() throws {
        _ = try makeTrip(withImage: [1, 1, 1])
        let work = root.appendingPathComponent("Work", isDirectory: true)
        try fm.createDirectory(at: work.appendingPathComponent("Trip.assets"), withIntermediateDirectories: true)
        try Data([9, 9, 9]).write(to: work.appendingPathComponent("Trip.assets/image.jpg"))
        let dm = manager()
        let note = try XCTUnwrap(dm.notes.first { $0.id == "Trip.md" })
        XCTAssertNotNil(dm.move(note: note, to: work))
        XCTAssertEqual(Array(try Data(contentsOf: work.appendingPathComponent("Trip.assets/image.jpg"))), [9, 9, 9])
        XCTAssertTrue(fm.fileExists(atPath: root.appendingPathComponent("Trip.md").path))
    }
}
