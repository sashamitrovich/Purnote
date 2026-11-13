//
//  PinStoreTests.swift
//  purenoteTests
//

@testable import Purnote
import XCTest

/// Pins on disk (`.purnote/pins.json`), the merge when the library moves to
/// iCloud, and the DataManager hooks that keep pins right when notes change.
final class PinStoreTests: XCTestCase {

    private var root: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory
            .appendingPathComponent("purnote-pins-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    // MARK: helpers

    private var pinsFile: URL { PinStore.fileURL(in: root) }

    @discardableResult
    private func write(_ path: String, _ body: String = "x", in base: URL? = nil) throws -> URL {
        let url = (base ?? root).appendingPathComponent(path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func rawPins(at base: URL? = nil) throws -> String {
        try String(contentsOf: PinStore.fileURL(in: base ?? root), encoding: .utf8)
    }

    private func isolatedPreferences() -> SortPreferences {
        let suite = "purnote-pins-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SortPreferences(defaults: defaults)
    }

    private func makeData(_ url: URL? = nil, libraryRoot: URL? = nil) -> DataManager {
        DataManager(url: url ?? root, sortPreferences: isolatedPreferences(), libraryRoot: libraryRoot)
    }

    // MARK: - file shape

    func testFileLivesNextToSmartFolders() {
        XCTAssertEqual(pinsFile.path, root.appendingPathComponent(".purnote/pins.json").path)
        XCTAssertEqual(pinsFile.deletingLastPathComponent(),
                       SmartFolderStore.fileURL(in: root).deletingLastPathComponent())
    }

    func testSavedFileIsVersionOneReadableJSON() throws {
        try PinStore.save(PinList(["Folder/Note.md", "b.md"]), to: root)
        let text = try rawPins()
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, 1)
        XCTAssertEqual(object?["pins"] as? [String], ["Folder/Note.md", "b.md"])
        XCTAssertTrue(text.contains("Folder/Note.md"), "slashes are not escaped, so the file reads like a list: \(text)")
        XCTAssertTrue(text.contains("\n"), "pretty-printed: \(text)")
    }

    func testRoundTripThroughACoordinatedWrite() throws {
        let list = PinList(["z.md", "Folder/Note.md", "a.md"])
        try PinStore.save(list, to: root)
        XCTAssertEqual(PinStore.load(from: root), list, "order survives the round trip")
    }

    /// Another writer (the sync daemon, in real life) holds the file; a save
    /// that goes through NSFileCoordinator waits its turn, a plain write does not.
    func testSaveWaitsForAnotherCoordinatedWriter() throws {
        try PinStore.save(PinList(["a.md"]), to: root)

        let holding = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var released = false

        DispatchQueue.global().async { [pinsFile] in
            var error: NSError?
            NSFileCoordinator().coordinate(writingItemAt: pinsFile, options: [], error: &error) { _ in
                holding.signal()
                Thread.sleep(forTimeInterval: 0.8)
                lock.lock(); released = true; lock.unlock()
            }
            finished.signal()
        }
        XCTAssertEqual(holding.wait(timeout: .now() + 5), .success)

        try PinStore.save(PinList(["a.md", "b.md"]), to: root)
        lock.lock(); let waited = released; lock.unlock()
        XCTAssertTrue(waited, "save returned while another writer still held the file")
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(PinStore.load(from: root).paths, ["a.md", "b.md"])
    }

    func testLoadWaitsForAnotherCoordinatedWriter() throws {
        try PinStore.save(PinList(["a.md"]), to: root)

        let holding = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var released = false

        DispatchQueue.global().async { [pinsFile] in
            var error: NSError?
            NSFileCoordinator().coordinate(writingItemAt: pinsFile, options: [], error: &error) { _ in
                holding.signal()
                Thread.sleep(forTimeInterval: 0.8)
                lock.lock(); released = true; lock.unlock()
            }
            finished.signal()
        }
        XCTAssertEqual(holding.wait(timeout: .now() + 5), .success)

        _ = PinStore.load(from: root)
        lock.lock(); let waited = released; lock.unlock()
        XCTAssertTrue(waited, "load read the file while another writer still held it")
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
    }

    func testLoadFromMissingFileIsEmpty() {
        XCTAssertEqual(PinStore.load(from: root), PinList())
        XCTAssertFalse(fm.fileExists(atPath: pinsFile.path), "loading creates nothing")
    }

    // MARK: - corrupt files

    private func writeRaw(_ text: String) throws {
        try fm.createDirectory(at: pinsFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: pinsFile, atomically: true, encoding: .utf8)
    }

    func testCorruptFileLoadsAsEmptyAndIsLeftAlone() throws {
        try writeRaw("{ this is not json")
        XCTAssertEqual(PinStore.load(from: root), PinList())
        XCTAssertEqual(try rawPins(), "{ this is not json", "a load never rewrites the file")
    }

    func testWrongShapeAndUnknownVersionAreUnreadable() throws {
        for text in ["[1, 2, 3]", "{\"pins\": [\"a.md\"]}", "{\"version\": 2, \"pins\": [\"a.md\"]}", ""] {
            try writeRaw(text)
            XCTAssertEqual(PinStore.load(from: root), PinList(), "unreadable: \(text)")
        }
    }

    func testSavingOverACorruptFileKeepsACopy() throws {
        try writeRaw("{ this is not json")
        try PinStore.save(PinList(["a.md"]), to: root)

        XCTAssertEqual(PinStore.load(from: root), PinList(["a.md"]))
        let copy = pinsFile.appendingPathExtension("corrupt")
        XCTAssertEqual(try? String(contentsOf: copy, encoding: .utf8), "{ this is not json",
                       "the unreadable file is kept as pins.json.corrupt")
    }

    func testASecondCorruptFileDoesNotReplaceTheFirstCopy() throws {
        try writeRaw("first bad")
        try PinStore.save(PinList(["a.md"]), to: root)
        try writeRaw("second bad")
        try PinStore.save(PinList(["b.md"]), to: root)

        let kept = try fm.contentsOfDirectory(atPath: pinsFile.deletingLastPathComponent().path)
            .filter { $0.hasPrefix("pins.json.corrupt") }
        XCTAssertEqual(kept.count, 2, "both bad files are kept: \(kept)")
        let bodies = try kept.map {
            try String(contentsOf: pinsFile.deletingLastPathComponent().appendingPathComponent($0), encoding: .utf8)
        }
        XCTAssertEqual(Set(bodies), ["first bad", "second bad"])
    }

    func testHookOnACorruptFileDoesNotTouchIt() throws {
        try writeRaw("{ this is not json")
        let note = try write("a.md")
        let dm = makeData()
        dm.pinsDrop(at: note)
        dm.pinsFollowMove(from: note, to: root.appendingPathComponent("b.md"))
        XCTAssertEqual(try rawPins(), "{ this is not json")
    }

    func testLoadDropsEntriesThatCouldNotBePaths() throws {
        try writeRaw("{\"version\":1,\"pins\":[\"ok.md\",\"../escape.md\",\"/abs.md\",\"\",\"ok.md\"]}")
        XCTAssertEqual(PinStore.load(from: root).paths, ["ok.md"])
    }

    // MARK: - drop missing on load

    func testLoadCanDropPinsWhoseFileIsGone() throws {
        try write("a.md"); try write("Folder/b.md")
        // a note still downloading from iCloud is a placeholder, and counts as there
        try write("Folder/.c.md.icloud")
        try PinStore.save(PinList(["a.md", "gone.md", "Folder/b.md", "Folder/c.md"]), to: root)

        XCTAssertEqual(PinStore.load(from: root, droppingMissing: true).paths,
                       ["a.md", "Folder/b.md", "Folder/c.md"])
        XCTAssertEqual(PinStore.load(from: root).paths.count, 4, "plain load keeps them")
    }

    // MARK: - merge (pure)

    func testMergedDataIsTheUnionKeepingOrder() throws {
        let existing = try PinStore.encode(PinList(["a.md", "b.md"]))
        let incoming = try PinStore.encode(PinList(["c.md", "a.md"]))
        let merged = try XCTUnwrap(PinStore.mergedData(existing: existing, incoming: incoming))
        XCTAssertEqual(PinStore.decode(merged)?.paths, ["a.md", "b.md", "c.md"])
    }

    func testMergedDataRefusesAnUnreadableSide() throws {
        let good = try PinStore.encode(PinList(["a.md"]))
        XCTAssertNil(PinStore.mergedData(existing: good, incoming: Data("garbage".utf8)))
        XCTAssertNil(PinStore.mergedData(existing: Data("garbage".utf8), incoming: good))
    }

    // MARK: - local to iCloud move

    func testMovingTheLibraryMergesPinsInsteadOfRenamingTheFile() throws {
        let local = root.appendingPathComponent("local", isDirectory: true)
        let icloud = root.appendingPathComponent("icloud", isDirectory: true)
        try write("Plane.md", in: local)
        try write("Boat.md", in: icloud)
        try PinStore.save(PinList(["Plane.md", "Shared.md"]), to: local)
        try PinStore.save(PinList(["Boat.md", "Shared.md"]), to: icloud)

        let result = Storage.move(from: local, to: icloud)
        XCTAssertEqual(result.failed, 0)

        XCTAssertEqual(PinStore.load(from: icloud).paths, ["Boat.md", "Shared.md", "Plane.md"],
                       "iCloud's list first, then the iPhone's new pins")
        let names = try fm.contentsOfDirectory(atPath: icloud.appendingPathComponent(".purnote").path)
        XCTAssertEqual(names, ["pins.json"], "no 'pins (from iPhone).json' left behind: \(names)")
        XCTAssertFalse(fm.fileExists(atPath: PinStore.fileURL(in: local).path), "the local file is consumed")
        XCTAssertTrue(fm.fileExists(atPath: icloud.appendingPathComponent("Plane.md").path))
    }

    func testMovingTheLibraryWithOnlyLocalPinsJustMovesTheFile() throws {
        let local = root.appendingPathComponent("local", isDirectory: true)
        let icloud = root.appendingPathComponent("icloud", isDirectory: true)
        try write("Plane.md", in: local)
        try fm.createDirectory(at: icloud, withIntermediateDirectories: true)
        try PinStore.save(PinList(["Plane.md"]), to: local)

        Storage.move(from: local, to: icloud)
        XCTAssertEqual(PinStore.load(from: icloud).paths, ["Plane.md"])
    }

    func testMovingTheLibraryKeepsAnUnreadableLocalPinsFileAsACopy() throws {
        let local = root.appendingPathComponent("local", isDirectory: true)
        let icloud = root.appendingPathComponent("icloud", isDirectory: true)
        try fm.createDirectory(at: icloud, withIntermediateDirectories: true)
        try PinStore.save(PinList(["Boat.md"]), to: icloud)
        try fm.createDirectory(at: PinStore.fileURL(in: local).deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try "garbage".write(to: PinStore.fileURL(in: local), atomically: true, encoding: .utf8)

        Storage.move(from: local, to: icloud)
        XCTAssertEqual(PinStore.load(from: icloud).paths, ["Boat.md"], "the good list is untouched")
        let names = try fm.contentsOfDirectory(atPath: icloud.appendingPathComponent(".purnote").path).sorted()
        XCTAssertEqual(names, ["pins (from iPhone).json", "pins.json"], "nothing is lost: \(names)")
    }

    // MARK: - DataManager: pin, unpin, resolve

    func testTogglePinPinsAndUnpinsAndPersists() throws {
        let url = try write("Folder/Note.md")
        let dm = makeData()
        let note = Note(content: "x", date: Date(), path: "Note.md", isLocal: true, url: url)

        XCTAssertFalse(dm.isPinned(note))
        dm.togglePin(note)
        XCTAssertTrue(dm.isPinned(note))
        XCTAssertEqual(PinStore.load(from: root).paths, ["Folder/Note.md"])

        dm.togglePin(note)
        XCTAssertFalse(dm.isPinned(note))
        XCTAssertEqual(PinStore.load(from: root).paths, [])
    }

    func testPinsSurviveANewDataManager() throws {
        let url = try write("a.md")
        let note = Note(content: "x", date: Date(), path: "a.md", isLocal: true, url: url)
        makeData().togglePin(note)
        XCTAssertTrue(makeData().isPinned(note), "a fresh launch sees the pin")
    }

    func testPinnedNotesResolvesExistingNotesInPinOrder() throws {
        try write("a.md", "alpha"); try write("Folder/b.md", "beta"); try write("c.md", "gamma")
        let dm = makeData()
        for path in ["c.md", "Folder/b.md", "a.md"] {
            let n = Note(content: "", date: Date(), path: "x", isLocal: true, url: root.appendingPathComponent(path))
            dm.togglePin(n)
        }
        try fm.removeItem(at: root.appendingPathComponent("a.md"))   // gone

        let pinned = makeData().pinnedNotes()
        XCTAssertEqual(pinned.map(\.url.lastPathComponent), ["c.md", "b.md"], "missing notes drop, order is kept")
        XCTAssertEqual(pinned.map(\.content), ["gamma", "beta"])
        XCTAssertEqual(pinned.map(\.id), ["c.md", "b.md"])
    }

    func testPinsAreRelativeToTheLibraryRootNotTheCurrentFolder() throws {
        let url = try write("Folder/Note.md")
        let folderData = makeData(root.appendingPathComponent("Folder"), libraryRoot: root)
        let note = try XCTUnwrap(folderData.notes.first)
        XCTAssertEqual(note.url.lastPathComponent, "Note.md")
        _ = url

        folderData.togglePin(note)
        XCTAssertEqual(PinStore.load(from: root).paths, ["Folder/Note.md"])
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent("Folder/.purnote").path))
        XCTAssertTrue(makeData().isPinned(note), "the root level sees what the folder pinned")
        XCTAssertEqual(makeData().pinnedNotes().map(\.id), ["Note.md"])
    }

    func testNoFileIsCreatedUntilSomethingIsPinned() throws {
        let note = try write("a.md")
        let dm = makeData()
        dm.pinsDrop(at: note)
        dm.pinsFollowMove(from: note, to: root.appendingPathComponent("b.md"))
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(".purnote").path))
    }

    func testPinsDoNotShowUpAsNotesOrFolders() throws {
        let note = try write("a.md")
        let dm = makeData()
        dm.togglePin(Note(content: "x", date: Date(), path: "a.md", isLocal: true, url: note))
        dm.refresh(url: root)
        XCTAssertEqual(dm.notes.count, 1)
        XCTAssertTrue(dm.folders.isEmpty, ".purnote stays hidden")
    }

    // MARK: - DataManager: pins follow changes made in the app

    func testANoteRenamedByEditingKeepsItsPin() throws {
        let url = try write("1603814400000.md")
        let dm = makeData()
        let note = Note(type: .Note)
        note.id = "1603814400000.md"; note.url = url; note.content = "Shopping\n- milk"
        dm.togglePin(note)

        dm.finishEditing(note, previousContent: "")
        XCTAssertEqual(note.url.lastPathComponent, "Shopping.md", "precondition: the file was renamed")

        XCTAssertTrue(dm.isPinned(note))
        XCTAssertEqual(PinStore.load(from: root).paths, ["Shopping.md"])
        XCTAssertEqual(makeData().pinnedNotes().map(\.id), ["Shopping.md"])
    }

    func testRenamingANoteInAFolderKeepsItsPinUnderTheFolder() throws {
        let url = try write("Journal/1603814400000.md")
        let dm = makeData(root.appendingPathComponent("Journal"), libraryRoot: root)
        let note = Note(type: .Note)
        note.id = "1603814400000.md"; note.url = url; note.content = "Trip\n- passport"
        dm.togglePin(note)

        dm.finishEditing(note, previousContent: "")
        XCTAssertEqual(PinStore.load(from: root).paths, ["Journal/Trip.md"])
    }

    func testMovingANoteWithDataManagerMoveKeepsItsPin() throws {
        let url = try write("a.md")
        try fm.createDirectory(at: root.appendingPathComponent("Archive"), withIntermediateDirectories: true)
        let dm = makeData()
        let note = try XCTUnwrap(dm.notes.first)
        XCTAssertEqual(note.url.lastPathComponent, "a.md")
        dm.togglePin(note)

        dm.move(note: note, to: root.appendingPathComponent("Archive"))
        _ = url
        XCTAssertEqual(PinStore.load(from: root).paths, ["Archive/a.md"])
        XCTAssertEqual(makeData().pinnedNotes().map(\.id), ["a.md"])
    }

    func testADeletedNoteLosesItsPin() throws {
        let keep = try write("keep.md"), gone = try write("Folder/gone.md")
        let dm = makeData()
        dm.togglePin(Note(content: "", date: Date(), path: "x", isLocal: true, url: keep))
        dm.togglePin(Note(content: "", date: Date(), path: "x", isLocal: true, url: gone))

        try fm.removeItem(at: gone)   // the simulator has no Trash to move it to
        dm.pinsDrop(at: gone)

        XCTAssertEqual(PinStore.load(from: root).paths, ["keep.md"])
        XCTAssertFalse(dm.isPinned(Note(content: "", date: Date(), path: "x", isLocal: true, url: gone)))
    }

    func testRenamingAFolderRewritesNestedPins() throws {
        let a = try write("Notes/a.md"), b = try write("Notes/Deep/b.md"), c = try write("Notes 2/c.md")
        let dm = makeData()
        for u in [a, b, c] {
            dm.togglePin(Note(content: "", date: Date(), path: "x", isLocal: true, url: u))
        }

        let old = root.appendingPathComponent("Notes"), new = root.appendingPathComponent("Journal")
        try CoordinatedFile.move(from: old, to: new)
        dm.pinsFollowMove(from: old, to: new)

        XCTAssertEqual(PinStore.load(from: root).paths, ["Journal/a.md", "Journal/Deep/b.md", "Notes 2/c.md"])
        XCTAssertEqual(makeData().pinnedNotes().map(\.id), ["a.md", "b.md", "c.md"], "all three still resolve")
    }

    func testDeletingAFolderDropsNestedPins() throws {
        let a = try write("Notes/a.md"), c = try write("Notes 2/c.md")
        let dm = makeData()
        for u in [a, c] {
            dm.togglePin(Note(content: "", date: Date(), path: "x", isLocal: true, url: u))
        }
        let folder = root.appendingPathComponent("Notes")
        try fm.removeItem(at: folder)   // the simulator has no Trash to move it to
        dm.pinsDrop(at: folder)
        XCTAssertEqual(PinStore.load(from: root).paths, ["Notes 2/c.md"])
    }

    func testAMovedNotePicksUpPinsEvenWhenTheOldFileIsAlreadyGone() throws {
        // the hooks run after the move, when the old url no longer exists
        let a = try write("a.md")
        let dm = makeData()
        dm.togglePin(Note(content: "", date: Date(), path: "x", isLocal: true, url: a))
        let target = root.appendingPathComponent("b.md")
        try fm.moveItem(at: a, to: target)
        dm.pinsFollowMove(from: a, to: target)
        XCTAssertEqual(PinStore.load(from: root).paths, ["b.md"])
    }

    func testDataManagerWithoutALibraryRootDoesNothing() {
        let dm = DataManager(searchNotes: [])
        let note = Note(content: "", date: Date(), path: "a.md", isLocal: true, url: root.appendingPathComponent("a.md"))
        dm.togglePin(note)
        XCTAssertFalse(dm.isPinned(note))
        XCTAssertTrue(dm.pinnedNotes().isEmpty)
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent(".purnote").path))
    }
}
