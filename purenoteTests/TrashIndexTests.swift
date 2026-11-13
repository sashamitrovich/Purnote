//
//  TrashIndexTests.swift
//  purenoteTests
//
//  The folder-aware index calls the trash needs, and the DataManager helpers
//  that tie TrashStore, pins, the index and the visible lists together. The
//  index tests look at its CONTENTS (terms, tags, entries), not only at what a
//  search happens to return.
//

@testable import Purnote
import XCTest

final class TrashIndexTests: TrashFixtureCase {

    // MARK: helpers

    private func isolatedPreferences() -> SortPreferences {
        let suite = "purnote-trashidx-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SortPreferences(defaults: defaults)
    }

    private func makeData(_ rel: String = "", libraryRoot: URL? = nil) -> DataManager {
        DataManager(url: rel.isEmpty ? root : url(rel), sortPreferences: isolatedPreferences(), libraryRoot: libraryRoot)
    }

    private func ready(_ index: SearchIndex) -> SearchIndex { index.waitUntilIdle(); return index }

    private func key(_ rel: String) -> String { SearchIndexPath.normalise(url(rel).path) }

    private func pins() -> [String] { PinStore.load(from: root).paths }

    /// A library with a Travel folder (two notes, one nested, tags, an attachment) and a note outside it.
    private func makeLibrary() throws {
        try write("Keep.md", "Keep\nlemon #keep")
        try write("Travel/Rome.md", "Rome\nlemon #italy")
        try write("Travel/Sub/Paris.md", "Paris\nlemon #france")
        try write("Travelogue/Other.md", "Other\nlemon #other")
    }

    // MARK: SearchData.removeAll(under:)

    func testRemoveAllUnderAFolderPrefixRemovesTermsTagsAndEntries() {
        var data = SearchData()
        data.upsert(path: "/r/Travel/A.md", content: "A\nlemon #italy", date: Date())
        data.upsert(path: "/r/Travel/Sub/B.md", content: "B\nlemon #italy #france", date: Date())
        data.upsert(path: "/r/Travelogue/C.md", content: "C\nlemon #italy", date: Date())
        data.upsert(path: "/r/Travel.md", content: "Travel\nlemon", date: Date())
        data.removeAll(under: "/r/Travel")
        XCTAssertEqual(Set(data.entries.keys), ["/r/Travelogue/C.md", "/r/Travel.md"], "whole path components only")
        XCTAssertEqual(data.terms["lemon"], ["/r/Travelogue/C.md", "/r/Travel.md"])
        XCTAssertEqual(data.tags["italy"], ["/r/Travelogue/C.md"])
        XCTAssertNil(data.tags["france"], "a tag only the removed notes had is gone")
        XCTAssertNil(data.terms["a"]); XCTAssertNil(data.terms["b"])
    }

    func testRemoveAllUnderToleratesATrailingSlashAndAnUnknownFolder() {
        var data = SearchData()
        data.upsert(path: "/r/T/A.md", content: "A", date: Date())
        data.removeAll(under: "/r/Nothing")
        XCTAssertEqual(data.entries.count, 1)
        data.removeAll(under: "/r/T/")
        XCTAssertEqual(data.entries.count, 0)
    }

    // MARK: SearchIndex.remove(folder:) / reindex(folder:)

    func testIndexRemoveFolderForgetsEveryNoteUnderItAndNothingElse() throws {
        try makeLibrary()
        let index = ready(SearchIndex(rootUrl: root))
        XCTAssertEqual(index.snapshot.entries.count, 4)

        index.remove(folder: url("Travel").path); index.waitUntilIdle()

        let snap = index.snapshot
        XCTAssertEqual(Set(snap.entries.keys), [key("Keep.md"), key("Travelogue/Other.md")])
        XCTAssertEqual(snap.terms["lemon"], [key("Keep.md"), key("Travelogue/Other.md")])
        XCTAssertNil(snap.terms["rome"]); XCTAssertNil(snap.terms["paris"])
        XCTAssertEqual(snap.tags, ["keep": [key("Keep.md")], "other": [key("Travelogue/Other.md")]])
        XCTAssertEqual(index.allTags(), ["keep", "other"])
    }

    func testIndexReindexFolderReadsEveryNoteUnderIt() throws {
        try makeLibrary()
        let index = ready(SearchIndex(rootUrl: root))
        index.remove(folder: url("Travel").path); index.waitUntilIdle()
        XCTAssertEqual(index.snapshot.entries.count, 2)

        index.reindex(folder: url("Travel").path); index.waitUntilIdle()

        let snap = index.snapshot
        XCTAssertEqual(Set(snap.entries.keys), [key("Keep.md"), key("Travel/Rome.md"), key("Travel/Sub/Paris.md"), key("Travelogue/Other.md")])
        XCTAssertEqual(snap.tags["italy"], [key("Travel/Rome.md")])
        XCTAssertEqual(snap.tags["france"], [key("Travel/Sub/Paris.md")])
        XCTAssertEqual(snap.terms["paris"], [key("Travel/Sub/Paris.md")])
        XCTAssertEqual(snap.entries[key("Travel/Rome.md")]?.titleTokens, ["rome"])
    }

    func testIndexReindexFolderReplacesStaleEntriesUnderTheFolder() throws {
        try makeLibrary()
        let index = ready(SearchIndex(rootUrl: root))
        try fm.removeItem(at: url("Travel/Sub/Paris.md"))            // gone on disk, still in the index
        try write("Travel/Rome.md", "Rome\nlime #spain")              // changed on disk
        index.reindex(folder: url("Travel").path); index.waitUntilIdle()
        let snap = index.snapshot
        XCTAssertNil(snap.entries[key("Travel/Sub/Paris.md")])
        XCTAssertNil(snap.tags["france"]); XCTAssertNil(snap.tags["italy"])
        XCTAssertEqual(snap.tags["spain"], [key("Travel/Rome.md")])
        XCTAssertEqual(snap.terms["lime"], [key("Travel/Rome.md")])
        XCTAssertEqual(snap.entries[key("Keep.md")]?.terms.contains("keep"), true, "other notes untouched")
    }

    func testIndexReindexFolderSkipsHiddenAndAssetsFolders() throws {
        try write("Travel/Rome.md", "Rome\nlemon")
        try write("Travel/Rome.assets/readme.md", "Readme\nlemon")
        try write("Travel/.hidden/Secret.md", "Secret\nlemon")
        try write("Travel/.Dot.md", "Dot\nlemon")
        let index = ready(SearchIndex(rootUrl: root))
        index.remove(folder: url("Travel").path); index.waitUntilIdle()
        index.reindex(folder: url("Travel").path); index.waitUntilIdle()
        XCTAssertEqual(Set(index.snapshot.entries.keys), [key("Travel/Rome.md")])
    }

    func testIndexReindexOfAFolderInsideTheTrashIndexesNothing() throws {
        try write(".purnote/trash/20260101120000-X/Travel/Rome.md", "Rome\nlemon")
        let index = ready(SearchIndex(rootUrl: root))
        index.reindex(folder: url(".purnote/trash/20260101120000-X/Travel").path); index.waitUntilIdle()
        XCTAssertEqual(index.snapshot.entries.count, 0, "a hidden folder is never indexed")
        index.reindex(folder: root.deletingLastPathComponent().path); index.waitUntilIdle()
        XCTAssertEqual(index.snapshot.entries.count, 0, "nor is a folder outside the library")
    }

    func testRebuildNeverIndexesTrashedNotes() throws {
        try write("Keep.md", "Keep\nlemon #keep")
        let item = try TrashStore.moveToTrash(try write("Gone.md", "Gone\nlemon #gone"), libraryRoot: root)
        let index = ready(SearchIndex(rootUrl: root))
        XCTAssertEqual(Set(index.snapshot.entries.keys), [key("Keep.md")])
        XCTAssertEqual(index.allTags(), ["keep"])
        XCTAssertEqual(index.searchByTags(["gone"]).count, 0)
        XCTAssertNotNil(item)
    }

    // MARK: DataManager.trash(note:) / restore

    func testTrashNoteRemovesItFromTheListPinsAndIndex() throws {
        try makeLibrary()
        try PinStore.save(PinList(["Keep.md", "Travel/Rome.md"]), to: root)
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let note = try XCTUnwrap(dm.notes.first { $0.id == "Keep.md" })

        let item = try dm.trash(note: note, index: index)
        index.waitUntilIdle()

        XCTAssertFalse(exists("Keep.md"))
        XCTAssertEqual(item.originalPath, "Keep.md")
        XCTAssertFalse(dm.notes.contains { $0.id == "Keep.md" })
        XCTAssertEqual(pins(), ["Travel/Rome.md"], "the pin is dropped")
        XCTAssertFalse(dm.isPinned(note))
        XCTAssertNil(index.snapshot.entries[key("Keep.md")])
        XCTAssertNil(index.snapshot.tags["keep"])
        XCTAssertEqual(index.snapshot.terms["lemon"]?.contains(key("Keep.md")), false)
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [item])
    }

    func testRestoreNoteBringsItBackToTheListAndIndexButNotThePin() throws {
        try makeLibrary()
        try PinStore.save(PinList(["Keep.md"]), to: root)
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let note = try XCTUnwrap(dm.notes.first { $0.id == "Keep.md" })
        let item = try dm.trash(note: note, index: index)

        let restored = try dm.restore(item, index: index)
        index.waitUntilIdle()

        XCTAssertTrue(same(restored, url("Keep.md")))
        XCTAssertTrue(dm.notes.contains { $0.id == "Keep.md" }, "back in the visible list")
        XCTAssertEqual(pins(), [], "restore does not re-pin")
        XCTAssertEqual(index.snapshot.entries[key("Keep.md")]?.tags, ["keep"])
        XCTAssertEqual(index.snapshot.tags["keep"], [key("Keep.md")])
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
    }

    func testRestoreNoteUnderANewNameIndexesTheNewPathOnly() throws {
        try write("Keep.md", "Keep\nlemon #keep")
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let item = try dm.trash(note: try XCTUnwrap(dm.notes.first), index: index)
        try write("Keep.md", "Other\nlemon #other")
        index.update(path: url("Keep.md").path)

        let restored = try dm.restore(item, index: index)
        index.waitUntilIdle()

        XCTAssertEqual(restored.lastPathComponent, "Keep 2.md")
        XCTAssertEqual(Set(index.snapshot.entries.keys), [key("Keep.md"), key("Keep 2.md")])
        XCTAssertEqual(index.snapshot.tags["keep"], [key("Keep 2.md")])
        XCTAssertEqual(index.snapshot.tags["other"], [key("Keep.md")])
        XCTAssertEqual(Set(dm.notes.map(\.id)), ["Keep.md", "Keep 2.md"])
    }

    func testTrashAndRestoreANoteInASubfolderUseTheLibraryRoot() throws {
        try write("Sub/N.md", "N\nlemon")
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData("Sub", libraryRoot: root)
        let note = try XCTUnwrap(dm.notes.first)
        let item = try dm.trash(note: note, index: index)
        XCTAssertEqual(item.originalPath, "Sub/N.md", "relative to the library root, not to Sub")
        let origin = try XCTUnwrap(TrashOrigin.decode(Data(contentsOf: folder(of: item).appendingPathComponent("origin.json"))))
        XCTAssertEqual(origin.path, "Sub/N.md")
        XCTAssertTrue(dm.notes.isEmpty)

        let restored = try dm.restore(item, index: index)
        XCTAssertTrue(same(restored, url("Sub/N.md")))
        XCTAssertEqual(dm.notes.map(\.id), ["N.md"], "the subfolder's list shows it again")
    }

    func testRestoreIntoAFolderThatIsNotOnScreenLeavesTheListAlone() throws {
        try write("Other/N.md", "N")
        try write("Here/H.md", "H")
        let dmOther = makeData("Other", libraryRoot: root)
        let item = try dmOther.trash(note: try XCTUnwrap(dmOther.notes.first), index: nil)
        let dmHere = makeData("Here", libraryRoot: root)
        let restored = try dmHere.restore(item, index: nil)
        XCTAssertTrue(same(restored, url("Other/N.md")))
        XCTAssertEqual(dmHere.notes.map(\.id), ["H.md"])
    }

    func testRestoreIntoAParentThatHadToBeRecreatedRefreshesTheVisibleList() throws {
        try write("Sub/Deep/N.md", "N")
        let dm = makeData()                                    // showing the library root
        let item = try dm.trash(note: try XCTUnwrap(makeData("Sub/Deep", libraryRoot: root).notes.first), index: nil)
        try fm.removeItem(at: url("Sub"))
        dm.refresh(url: root)
        XCTAssertEqual(dm.folders.map(\.id), [])

        let restored = try dm.restore(item, index: nil)
        XCTAssertTrue(same(restored, url("Sub/Deep/N.md")))
        XCTAssertEqual(dm.folders.map(\.id), ["Sub"], "the folder that was recreated under the folder on screen shows up")
        XCTAssertEqual(dm.notes.map(\.id), [], "the note itself is not in the root")
    }

    func testRestoreOfAFolderIntoARecreatedGrandparentRefreshesTheVisibleList() throws {
        try write("A/B/C/N.md", "N")
        let dm = makeData()
        let item = try dm.trash(folder: Folder(id: "C", url: url("A/B/C")), index: nil)
        try fm.removeItem(at: url("A"))
        dm.refresh(url: root)
        _ = try dm.restore(item, index: nil)
        XCTAssertEqual(dm.folders.map(\.id), ["A"])
    }

    func testTrashWithoutAnIndexStillWorks() throws {
        try write("A.md")
        let dm = makeData()
        XCTAssertNoThrow(try dm.trash(note: try XCTUnwrap(dm.notes.first)))
        XCTAssertTrue(dm.notes.isEmpty)
    }

    func testTrashOnADataManagerWithoutALibraryThrows() throws {
        let note = Note(content: "x", date: Date(), path: "A.md", isLocal: true, url: url("A.md"), type: .Note)
        let dm = DataManager(searchNotes: [note])
        XCTAssertThrowsError(try dm.trash(note: note)) { error in
            guard case TrashError.noLibrary = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(dm.notes.count, 1, "the list is untouched when the delete did not happen")
    }

    func testFailedTrashLeavesListPinsAndIndexAlone() throws {
        try write("A.md", "A\nlemon #tag")
        try PinStore.save(PinList(["A.md"]), to: root)
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let note = try XCTUnwrap(dm.notes.first)
        try fm.removeItem(at: url("A.md"))                 // gone behind our back
        XCTAssertThrowsError(try dm.trash(note: note, index: index)) { error in
            guard case TrashError.sourceMissing = error else { return XCTFail("\(error)") }
        }
        index.waitUntilIdle()
        XCTAssertEqual(dm.notes.count, 1, "the row stays when the delete failed")
        XCTAssertEqual(pins(), ["A.md"])
        XCTAssertNotNil(index.snapshot.entries[key("A.md")], "the index is only told about deletes that happened")
        XCTAssertEqual(itemFolders(), [])
    }

    func testTrashNotesBatchUpdatesEverything() throws {
        try write("A.md", "A\nlemon"); try write("B.md", "B\nlemon"); try write("C.md", "C\nlemon")
        try PinStore.save(PinList(["A.md", "C.md"]), to: root)
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let chosen = dm.notes.filter { $0.id != "B.md" }
        let batch = dm.trash(notes: chosen, index: index)
        index.waitUntilIdle()
        XCTAssertEqual(batch.items.count, 2)
        XCTAssertEqual(batch.failures.count, 0)
        XCTAssertEqual(dm.notes.map(\.id), ["B.md"])
        XCTAssertEqual(pins(), [])
        XCTAssertEqual(Set(index.snapshot.entries.keys), [key("B.md")])
        for item in batch.items { _ = try dm.restore(item, index: index) }
        index.waitUntilIdle()
        XCTAssertEqual(Set(dm.notes.map(\.id)), ["A.md", "B.md", "C.md"])
        XCTAssertEqual(Set(index.snapshot.entries.keys), [key("A.md"), key("B.md"), key("C.md")])
        XCTAssertEqual(pins(), [], "none of them is re-pinned")
    }

    // MARK: DataManager.trash(folder:) / restore

    func testTrashFolderRemovesEverythingUnderItFromIndexPinsAndList() throws {
        try makeLibrary()
        try PinStore.save(PinList(["Keep.md", "Travel/Rome.md", "Travel/Sub/Paris.md", "Travelogue/Other.md"]), to: root)
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let folder = try XCTUnwrap(dm.folders.first { $0.id == "Travel" })

        let item = try dm.trash(folder: folder, index: index)
        index.waitUntilIdle()

        XCTAssertEqual(item.kind, .folder)
        XCTAssertFalse(exists("Travel"))
        XCTAssertEqual(Set(dm.folders.map(\.id)), ["Travelogue"])
        XCTAssertEqual(pins(), ["Keep.md", "Travelogue/Other.md"], "pins under the folder go, a similarly named folder's stay")
        let snap = index.snapshot
        XCTAssertEqual(Set(snap.entries.keys), [key("Keep.md"), key("Travelogue/Other.md")])
        XCTAssertEqual(snap.terms["lemon"], [key("Keep.md"), key("Travelogue/Other.md")])
        XCTAssertEqual(snap.tags, ["keep": [key("Keep.md")], "other": [key("Travelogue/Other.md")]])
        XCTAssertNil(snap.terms["rome"]); XCTAssertNil(snap.terms["paris"])
    }

    func testRestoreFolderUnderItsOwnNameReindexesEveryNoteInIt() throws {
        try makeLibrary()
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let item = try dm.trash(folder: try XCTUnwrap(dm.folders.first { $0.id == "Travel" }), index: index)

        let restored = try dm.restore(item, index: index)
        index.waitUntilIdle()

        XCTAssertTrue(same(restored, url("Travel")))
        XCTAssertEqual(Set(index.snapshot.entries.keys),
                       [key("Keep.md"), key("Travel/Rome.md"), key("Travel/Sub/Paris.md"), key("Travelogue/Other.md")])
        XCTAssertEqual(index.snapshot.tags["italy"], [key("Travel/Rome.md")])
        XCTAssertEqual(index.snapshot.tags["france"], [key("Travel/Sub/Paris.md")])
        XCTAssertTrue(dm.folders.contains { $0.id == "Travel" })
    }

    func testRestoreFolderUnderANewNameIndexesTheNewPathsAndNotTheOldOnes() throws {
        try makeLibrary()
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let item = try dm.trash(folder: try XCTUnwrap(dm.folders.first { $0.id == "Travel" }), index: index)

        // the name is taken again by a different folder, with its own note and tag
        try write("Travel/New.md", "New\nlemon #fresh")
        index.update(path: url("Travel/New.md").path)
        index.waitUntilIdle()

        let restored = try dm.restore(item, index: index)
        index.waitUntilIdle()

        XCTAssertEqual(restored.lastPathComponent, "Travel 2")
        let snap = index.snapshot
        XCTAssertEqual(Set(snap.entries.keys),
                       [key("Keep.md"), key("Travel/New.md"), key("Travel 2/Rome.md"), key("Travel 2/Sub/Paris.md"), key("Travelogue/Other.md")])
        XCTAssertEqual(snap.tags["italy"], [key("Travel 2/Rome.md")], "the old path is not there")
        XCTAssertEqual(snap.tags["france"], [key("Travel 2/Sub/Paris.md")])
        XCTAssertEqual(snap.tags["fresh"], [key("Travel/New.md")], "the other folder's note is untouched")
        XCTAssertEqual(snap.terms["rome"], [key("Travel 2/Rome.md")])
        XCTAssertEqual(snap.terms["lemon"]?.count, 5)
        XCTAssertEqual(Set(dm.folders.map(\.id)), ["Travel", "Travel 2", "Travelogue"])
    }

    func testRestoreFolderDoesNotBringItsPinsBack() throws {
        try makeLibrary()
        try PinStore.save(PinList(["Travel/Rome.md"]), to: root)
        let index = ready(SearchIndex(rootUrl: root))
        let dm = makeData()
        let item = try dm.trash(folder: try XCTUnwrap(dm.folders.first { $0.id == "Travel" }), index: index)
        _ = try dm.restore(item, index: index)
        XCTAssertEqual(pins(), [])
        XCTAssertEqual(dm.pins.paths, [])
    }

    func testTrashedFolderIsAbsentFromAFreshRebuildOfTheIndexAndTheFolderList() throws {
        try makeLibrary()
        let dm = makeData()
        _ = try dm.trash(folder: try XCTUnwrap(dm.folders.first { $0.id == "Travel" }), index: nil)
        let index = ready(SearchIndex(rootUrl: root))
        XCTAssertEqual(Set(index.snapshot.entries.keys), [key("Keep.md"), key("Travelogue/Other.md")])
        dm.refresh(url: root)
        XCTAssertEqual(Set(dm.folders.map(\.id)), ["Travelogue"], ".purnote is hidden from the folder list")
    }
}
