//
//  RecentlyDeletedModelTests.swift
//  purenoteTests
//
//  The Recently Deleted screen's view-model: loading, restoring, deleting for
//  good, and the rule that Delete All acts on exactly the items that were
//  listed when the question was asked.
//

@testable import Purnote
import XCTest

@MainActor
final class RecentlyDeletedModelTests: TrashFixtureCase {

    private typealias Row = RecentlyDeletedModel.Row

    private func item(_ id: String, path: String? = nil, kind: TrashKind = .note,
                      state: TrashSyncState = .ready, known: Bool = true) -> TrashedItem {
        let p = path ?? "\(id).md"
        return TrashedItem(id: id, kind: kind, originalPath: p, originKnown: known, deletedAt: Date(timeIntervalSince1970: 1_700_000_000),
                           payloadName: (p as NSString).lastPathComponent, assetsName: nil, state: state)
    }

    /// A backend over an in-memory list that records what it was asked to do.
    final class Fake {
        var items: [TrashedItem]
        var restored: [String] = []
        var deleted: [[String]] = []
        var restoreError: Error?
        var deleteFailures: Set<String> = []
        init(_ items: [TrashedItem]) { self.items = items }

        var backend: RecentlyDeletedModel.Backend {
            RecentlyDeletedModel.Backend(
                list: { [unowned self] in self.items.map { Row.make($0, firstLine: nil) } },
                restore: { [unowned self] chosen in
                    if let restoreError { throw restoreError }
                    self.restored.append(chosen.id)
                    self.items.removeAll { $0.id == chosen.id }
                },
                deleteForever: { [unowned self] chosen in
                    self.deleted.append(chosen.map(\.id))
                    var failures: [TrashFailure] = []
                    for c in chosen {
                        if self.deleteFailures.contains(c.id) {
                            failures.append(TrashFailure(url: URL(fileURLWithPath: "/x/\(c.id)"), error: TrashError.invalidItem(c.id)))
                        } else { self.items.removeAll { $0.id == c.id } }
                    }
                    return failures
                })
        }
    }

    private func loaded(_ fake: Fake) async -> RecentlyDeletedModel {
        let model = RecentlyDeletedModel(backend: fake.backend)
        await model.load()
        return model
    }

    // MARK: rows

    func testANoteRowShowsItsFirstLineItsFolderAndHasANoteIcon() {
        let row = Row.make(item("1", path: "Trips/Rome.md"), firstLine: "Rome in spring")
        XCTAssertEqual(row.title, "Rome in spring")
        XCTAssertEqual(row.detail, "Trips")
        XCTAssertEqual(row.icon, "doc.text")
    }

    func testANoteRowFallsBackToTheFileStemWithoutAFirstLine() {
        XCTAssertEqual(Row.make(item("1", path: "Rome.md"), firstLine: nil).title, "Rome")
        XCTAssertEqual(Row.make(item("1", path: "Rome.md"), firstLine: "").title, "Rome")
        XCTAssertEqual(Row.make(item("1", path: "Rome.md"), firstLine: "   ").title, "Rome")
    }

    func testARootNoteIsFromThePurnoteFolderAndANestedOneShowsItsWholePath() {
        XCTAssertEqual(Row.make(item("1", path: "Rome.md"), firstLine: nil).detail, "Purnote")
        XCTAssertEqual(Row.make(item("1", path: "A/B/Rome.md"), firstLine: nil).detail, "A/B")
    }

    func testAFolderRowIsTheFolderNameWithAFolderIcon() {
        let row = Row.make(item("1", path: "Work/Trip", kind: .folder), firstLine: "ignored")
        XCTAssertEqual(row.title, "Trip")
        XCTAssertEqual(row.detail, "Work")
        XCTAssertEqual(row.icon, "folder")
    }

    func testAnOrphanAttachmentsFolderIsCalledPicturesAndNamesItsFolder() {
        let row = Row.make(item("1", path: "Work/Trip.assets", kind: .folder), firstLine: nil)
        XCTAssertEqual(row.title, "Pictures")
        XCTAssertEqual(row.detail, "Work")
        XCTAssertEqual(row.icon, "photo.on.rectangle")
        XCTAssertEqual(Row.make(item("2", path: "Trip.assets", kind: .folder), firstLine: nil).detail, "Purnote")
    }

    func testAFolderThatIsLiterallyNamedDotAssetsIsStillAFolder() {
        XCTAssertEqual(Row.make(item("1", path: ".assets", kind: .folder), firstLine: nil).title, ".assets")
    }

    func testAnUnknownOriginSaysSo() {
        let row = Row.make(item("1", path: "Rome.md", known: false), firstLine: nil)
        XCTAssertEqual(row.detail, "Original folder unknown")
    }

    func testADownloadingRowIsNotRestorable() {
        XCTAssertFalse(Row.make(item("1", state: .downloading), firstLine: nil).isRestorable)
        XCTAssertTrue(Row.make(item("1"), firstLine: nil).isRestorable)
    }

    func testAnItemWithNoNameAtAllStillGetsATitle() {
        let nameless = TrashedItem(id: "1", kind: .note, originalPath: "", originKnown: false, deletedAt: Date(),
                                   payloadName: "", assetsName: nil, state: .downloading)
        XCTAssertEqual(Row.make(nameless, firstLine: nil).title, "Deleted item")
    }

    // MARK: loading

    func testLoadShowsTheListedItemsInOrder() async {
        let model = await loaded(Fake([item("b"), item("a")]))
        XCTAssertEqual(model.rows.map(\.id), ["b", "a"])
        XCTAssertTrue(model.hasLoaded)
    }

    func testNothingIsLoadedYetBeforeTheFirstLoad() {
        let model = RecentlyDeletedModel(backend: Fake([]).backend)
        XCTAssertFalse(model.hasLoaded, "so the screen does not flash \"Nothing deleted.\" while it is still reading")
    }

    func testAnEmptyTrashLoadsAsEmpty() async {
        let model = await loaded(Fake([]))
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertTrue(model.hasLoaded)
    }

    // MARK: restore

    func testRestoreMovesTheItemOutOfTheList() async throws {
        let fake = Fake([item("a"), item("b")])
        let model = await loaded(fake)
        await model.restore(try XCTUnwrap(model.rows.first { $0.id == "a" }))
        XCTAssertEqual(fake.restored, ["a"])
        XCTAssertEqual(model.rows.map(\.id), ["b"])
        XCTAssertNil(model.alert)
    }

    func testAFailedRestoreAlertsKeepsTheRowOnlyIfItIsStillThere() async throws {
        let fake = Fake([item("a")])
        let model = await loaded(fake)
        fake.restoreError = TrashError.stillDownloading("a")
        await model.restore(try XCTUnwrap(model.rows.first))
        XCTAssertEqual(model.alert?.title, "Could not restore")
        XCTAssertTrue(model.alert?.message.contains("still downloading") == true, model.alert?.message ?? "")
        XCTAssertEqual(model.rows.map(\.id), ["a"], "it is still in the trash, so it is still listed")
    }

    func testAFailedRestoreOfAnItemThatIsGoneRefreshesTheList() async throws {
        let fake = Fake([item("a"), item("b")])
        let model = await loaded(fake)
        let row = try XCTUnwrap(model.rows.first { $0.id == "a" })
        fake.items.removeAll { $0.id == "a" }                  // restored on another device meanwhile
        fake.restoreError = TrashError.itemGone("a")
        await model.restore(row)
        XCTAssertNotNil(model.alert)
        XCTAssertEqual(model.rows.map(\.id), ["b"])
    }

    func testADownloadingItemIsNeverRestored() async throws {
        let fake = Fake([item("a", state: .downloading)])
        let model = await loaded(fake)
        await model.restore(try XCTUnwrap(model.rows.first))
        XCTAssertEqual(fake.restored, [])
        XCTAssertEqual(model.rows.count, 1)
    }

    // MARK: delete forever

    func testDeleteForeverActsOnThatItemOnly() async throws {
        let fake = Fake([item("a"), item("b")])
        let model = await loaded(fake)
        await model.deleteForever(try XCTUnwrap(model.rows.first { $0.id == "a" }))
        XCTAssertEqual(fake.deleted, [["a"]])
        XCTAssertEqual(model.rows.map(\.id), ["b"])
    }

    func testAFailedDeleteForeverAlertsAndKeepsTheRow() async throws {
        let fake = Fake([item("a")])
        fake.deleteFailures = ["a"]
        let model = await loaded(fake)
        await model.deleteForever(try XCTUnwrap(model.rows.first))
        XCTAssertEqual(model.alert?.title, "Could not delete")
        XCTAssertEqual(model.rows.map(\.id), ["a"])
    }

    // MARK: delete all

    func testDeleteAllActsOnExactlyTheItemsListedWhenAsked() async {
        let fake = Fake([item("a"), item("b")])
        let model = await loaded(fake)
        model.requestDeleteAll()
        XCTAssertEqual(model.deleteAllCandidates?.map(\.id), ["a", "b"], "the confirmation can state this count")
        // something else is deleted meanwhile and the list is read again
        fake.items.append(item("new"))
        await model.load()
        XCTAssertEqual(model.rows.map(\.id), ["a", "b", "new"])
        await model.confirmDeleteAll()
        XCTAssertEqual(fake.deleted, [["a", "b"]], "only what the question was about")
        XCTAssertEqual(model.rows.map(\.id), ["new"], "the newcomer is untouched and still listed")
        XCTAssertNil(model.deleteAllCandidates)
    }

    func testDeleteAllWithoutAskingDoesNothing() async {
        let fake = Fake([item("a")])
        let model = await loaded(fake)
        await model.confirmDeleteAll()
        XCTAssertEqual(fake.deleted.count, 0)
        XCTAssertEqual(model.rows.count, 1)
    }

    func testCancellingDeleteAllForgetsTheQuestion() async {
        let fake = Fake([item("a")])
        let model = await loaded(fake)
        model.requestDeleteAll()
        model.cancelDeleteAll()
        XCTAssertNil(model.deleteAllCandidates)
        await model.confirmDeleteAll()
        XCTAssertEqual(fake.deleted.count, 0)
    }

    func testDeleteAllOnAnEmptyListAsksNothing() async {
        let model = await loaded(Fake([]))
        model.requestDeleteAll()
        XCTAssertNil(model.deleteAllCandidates)
    }

    func testDeleteAllWithAFailureAlertsAndKeepsThatItemListed() async {
        let fake = Fake([item("a"), item("b")])
        fake.deleteFailures = ["b"]
        let model = await loaded(fake)
        model.requestDeleteAll()
        await model.confirmDeleteAll()
        XCTAssertEqual(model.alert?.title, "Could not delete everything")
        XCTAssertTrue(model.alert?.message.contains("1 of 2") == true, model.alert?.message ?? "")
        XCTAssertEqual(model.rows.map(\.id), ["b"])
    }

    // MARK: a slow list read must not undo what happened meanwhile

    func testALoadThatFinishesAfterARestoreDoesNotBringTheRowBack() async throws {
        let fake = Fake([item("a"), item("b")])
        var resume: CheckedContinuation<[Row], Never>?
        var slow = false
        var backend = fake.backend
        let fastList = backend.list
        backend.list = {
            if slow { return await withCheckedContinuation { resume = $0 } }
            return await fastList()
        }
        let model = RecentlyDeletedModel(backend: backend)
        await model.load()
        let a = try XCTUnwrap(model.rows.first { $0.id == "a" })

        slow = true
        let stale = Task { await model.load() }
        while resume == nil { await Task.yield() }
        let oldList = [Row.make(item("a"), firstLine: nil), Row.make(item("b"), firstLine: nil)]

        slow = false
        await model.restore(a)
        resume?.resume(returning: oldList)        // the read that started before the restore ends now
        await stale.value
        XCTAssertEqual(model.rows.map(\.id), ["b"])
    }

    // MARK: the real backend, on a real library

    func testTheLiveBackendListsRealTrashWithTitlesAndRestoresIt() async throws {
        try write("Trips/Rome.md", "# Rome in spring\nbody")
        try write("Trips/Rome.assets/p.png", "png")
        try write("Plain.md", "no heading here\nmore")
        let data = DataManager(url: root)
        let note = try XCTUnwrap(DataManager(url: url("Trips"), libraryRoot: root).notes.first { $0.id == "Rome.md" })
        _ = try data.trash(note: note)
        _ = try data.trash(note: try XCTUnwrap(data.notes.first { $0.id == "Plain.md" }))

        let model = RecentlyDeletedModel(backend: .live(root: root, data: data, index: nil))
        await model.load()
        XCTAssertEqual(Set(model.rows.map(\.title)), ["Rome in spring", "no heading here"])
        XCTAssertEqual(Set(model.rows.map(\.detail)), ["Trips", "Purnote"])

        await model.restore(try XCTUnwrap(model.rows.first { $0.title == "Rome in spring" }))
        XCTAssertNil(model.alert)
        XCTAssertEqual(read("Trips/Rome.md"), "# Rome in spring\nbody")
        XCTAssertEqual(read("Trips/Rome.assets/p.png"), "png")
        XCTAssertEqual(model.rows.map(\.title), ["no heading here"])

        model.requestDeleteAll()
        await model.confirmDeleteAll()
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertFalse(exists("Plain.md"))
        XCTAssertTrue(fm.fileExists(atPath: trashDir.path), "the trash folder itself stays")
        XCTAssertEqual(itemFolders(), [])
    }

    // MARK: peeking at a first line

    func testPeekReadsOnlyTheFirstLineOfAMarkdownNote() throws {
        let f = try write("p/Note.md", "# Title here\nsecond line")
        XCTAssertEqual(RecentlyDeletedModel.firstLine(ofFileAt: f), "Title here")
    }

    func testPeekSkipsLeadingBlankLinesAndStripsMarkdown() throws {
        let f = try write("p/Note.md", "\n\n- [ ] **buy** milk\nx")
        XCTAssertEqual(RecentlyDeletedModel.firstLine(ofFileAt: f), "buy milk")
    }

    func testPeekGivesUpOnAHugeFileWithoutReadingItAll() throws {
        let f = try write("p/Big.md", String(repeating: "x", count: 500_000))
        let title = RecentlyDeletedModel.firstLine(ofFileAt: f)
        XCTAssertNotNil(title)
        XCTAssertLessThanOrEqual(title?.count ?? 0, 200)
    }

    func testPeekIgnoresNonMarkdownAndMissingFiles() throws {
        let f = try write("p/Data.bin", "text")
        XCTAssertNil(RecentlyDeletedModel.firstLine(ofFileAt: f))
        XCTAssertNil(RecentlyDeletedModel.firstLine(ofFileAt: url("p/Nope.md")))
    }

    func testPeekDoesNotFollowASymbolicLink() throws {
        let target = try write("elsewhere/Secret.md", "secret first line")
        try mkdir("p")
        let link = url("p/Link.md")
        try fm.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertNil(RecentlyDeletedModel.firstLine(ofFileAt: link))
    }

    func testPeekSurvivesBytesThatAreNotUTF8() throws {
        try mkdir("p")
        let f = url("p/Odd.md")
        try Data([0xFF, 0xFE, 0x41, 0x0A, 0x42]).write(to: f)
        XCTAssertNoThrow(RecentlyDeletedModel.firstLine(ofFileAt: f))
    }
}
