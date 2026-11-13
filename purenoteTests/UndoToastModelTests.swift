//
//  UndoToastModelTests.swift
//  purenoteTests
//
//  The Undo toast: one toast at a time, holds exactly the items it covers,
//  expires through an injected scheduler (no sleeping), and the delete helpers
//  that decide between "toast" and "alert".
//

@testable import Purnote
import XCTest

/// A scheduler the test fires by hand.
final class ManualScheduler {
    struct Job { let delay: TimeInterval; let action: () -> Void; var cancelled = false }
    private(set) var jobs: [Job] = []

    // The closures hold the scheduler (a cycle that lives as long as the test), so a
    // model built with a throwaway scheduler can still schedule.
    lazy var schedule: UndoToastModel.Scheduler = { delay, action in
        let index = self.jobs.count
        self.jobs.append(Job(delay: delay, action: action))
        return { self.jobs[index].cancelled = true }
    }

    /// Runs job `index` the way a timer that was not cancelled would.
    func fire(_ index: Int) { jobs[index].action() }
}

@MainActor
final class UndoToastModelTests: TrashFixtureCase {

    private func item(_ id: String) -> TrashedItem {
        TrashedItem(id: id, kind: .note, originalPath: "\(id).md", originKnown: true,
                    deletedAt: Date(), payloadName: "\(id).md", assetsName: nil, state: .ready)
    }

    private func makeModel(_ scheduler: ManualScheduler = ManualScheduler(), duration: TimeInterval = 6) -> UndoToastModel {
        UndoToastModel(duration: duration, schedule: scheduler.schedule)
    }

    // MARK: the toast itself

    func testShowPublishesTheMessageAndItems() {
        let model = makeModel()
        model.show([item("a"), item("b")]) { _ in }
        XCTAssertEqual(model.current?.message, "Moved to Recently Deleted")
        XCTAssertEqual(model.current?.items.map(\.id), ["a", "b"])
    }

    func testShowWithoutItemsShowsNothing() {
        let model = makeModel()
        model.show([]) { _ in }
        XCTAssertNil(model.current)
    }

    func testExpiryIsScheduledForTheDuration() {
        let scheduler = ManualScheduler()
        let model = makeModel(scheduler, duration: 6)
        model.show([item("a")]) { _ in }
        XCTAssertEqual(scheduler.jobs.map(\.delay), [6])
    }

    func testToastGoesAwayWhenTheTimerFires() {
        let scheduler = ManualScheduler()
        let model = makeModel(scheduler)
        model.show([item("a")]) { _ in }
        scheduler.fire(0)
        XCTAssertNil(model.current)
    }

    func testANewToastReplacesTheOldOneAndCancelsItsTimer() {
        let scheduler = ManualScheduler()
        let model = makeModel(scheduler)
        model.show([item("a")]) { _ in }
        model.show([item("b")]) { _ in }
        XCTAssertEqual(model.current?.items.map(\.id), ["b"], "replaced, not stacked")
        XCTAssertTrue(scheduler.jobs[0].cancelled)
        XCTAssertFalse(scheduler.jobs[1].cancelled)
    }

    func testTheOldTimerCannotDismissTheNewToast() {
        let scheduler = ManualScheduler()
        let model = makeModel(scheduler)
        model.show([item("a")]) { _ in }
        model.show([item("b")]) { _ in }
        scheduler.fire(0)           // a timer that was already on its way when the toast was replaced
        XCTAssertEqual(model.current?.items.map(\.id), ["b"])
        scheduler.fire(1)
        XCTAssertNil(model.current)
    }

    func testDismissClearsTheToastAndItsTimer() {
        let scheduler = ManualScheduler()
        let model = makeModel(scheduler)
        model.show([item("a")]) { _ in }
        model.dismiss()
        XCTAssertNil(model.current)
        XCTAssertTrue(scheduler.jobs[0].cancelled)
    }

    // MARK: Undo

    func testUndoRestoresExactlyTheItemsOfThatToast() {
        let model = makeModel()
        var restored: [String] = []
        model.show([item("old")]) { restored.append($0.id) }
        model.show([item("a"), item("b"), item("c")]) { restored.append($0.id) }
        model.undo()
        XCTAssertEqual(restored, ["a", "b", "c"], "one Undo covers everything in the toast, and nothing from a replaced one")
        XCTAssertNil(model.current)
        XCTAssertNil(model.alert)
    }

    func testUndoCancelsTheTimer() {
        let scheduler = ManualScheduler()
        let model = makeModel(scheduler)
        model.show([item("a")]) { _ in }
        model.undo()
        XCTAssertTrue(scheduler.jobs[0].cancelled)
    }

    func testUndoWithNoToastDoesNothing() {
        let model = makeModel()
        model.undo()
        XCTAssertNil(model.current)
        XCTAssertNil(model.alert)
    }

    func testUndoTwiceRestoresOnce() {
        let model = makeModel()
        var count = 0
        model.show([item("a")]) { _ in count += 1 }
        model.undo(); model.undo()
        XCTAssertEqual(count, 1)
    }

    func testAFailedRestoreDoesNotStopTheOthersAndSaysSo() {
        let model = makeModel()
        var restored: [String] = []
        model.show([item("a"), item("b"), item("c")]) {
            if $0.id == "b" { throw TrashError.itemGone("b") }
            restored.append($0.id)
        }
        model.undo()
        XCTAssertEqual(restored, ["a", "c"])
        let alert = try? XCTUnwrap(model.alert)
        XCTAssertEqual(alert?.title, "Could not put back everything")
        XCTAssertTrue(alert?.message.contains("1 of 3") == true, alert?.message ?? "")
        XCTAssertTrue(alert?.message.contains("Recently Deleted") == true, "says where the rest is")
        XCTAssertTrue(alert?.message.contains("no longer in Recently Deleted") == true, "gives the reason: \(alert?.message ?? "")")
    }

    func testASingleFailedRestoreAlertsWithTheReason() {
        let model = makeModel()
        model.show([item("a")]) { _ in throw TrashError.itemGone("a") }
        model.undo()
        XCTAssertEqual(model.alert?.title, "Could not put it back")
        XCTAssertNil(model.current)
    }

    // MARK: delete helpers (real files)

    private func isolatedPreferences() -> SortPreferences {
        let suite = "purnote-toast-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return SortPreferences(defaults: defaults)
    }

    private func makeData() -> DataManager {
        DataManager(url: root, sortPreferences: isolatedPreferences())
    }

    func testDeletingANoteShowsTheToastAndTakesTheRowOut() throws {
        try write("A.md", "A"); try write("B.md", "B")
        let data = makeData()
        let model = makeModel()
        let note = try XCTUnwrap(data.notes.first { $0.id == "A.md" })
        model.delete(note: note, from: data, index: nil)
        XCTAssertEqual(data.notes.map(\.id), ["B.md"])
        XCTAssertFalse(exists("A.md"))
        XCTAssertEqual(model.current?.items.count, 1)
        XCTAssertEqual(model.current?.items.first?.displayName, "A.md")
        XCTAssertNil(model.alert)
    }

    func testUndoAfterDeletingBringsTheNoteBackIntoTheList() throws {
        try write("A.md", "A text")
        let data = makeData()
        let model = makeModel()
        model.delete(note: try XCTUnwrap(data.notes.first), from: data, index: nil)
        XCTAssertTrue(data.notes.isEmpty)
        model.undo()
        XCTAssertEqual(read("A.md"), "A text")
        XCTAssertEqual(data.notes.map(\.id), ["A.md"], "the list refreshed")
        XCTAssertNil(model.current)
        XCTAssertNil(model.alert)
    }

    func testAFailedDeleteKeepsTheRowAndAlertsWithoutAToast() throws {
        try write("A.md", "A")
        let data = makeData()
        let model = makeModel()
        let note = try XCTUnwrap(data.notes.first)
        try fm.removeItem(at: url("A.md"))              // gone behind our back: the move throws
        model.delete(note: note, from: data, index: nil)
        XCTAssertEqual(data.notes.count, 1, "the row stays")
        XCTAssertNil(model.current, "no toast for something that did not happen")
        XCTAssertEqual(model.alert?.title, "Could not delete \u{201C}A\u{201D}")
        XCTAssertFalse(model.alert?.message.isEmpty ?? true)
    }

    func testASecondDeleteReplacesTheToastOfTheFirst() throws {
        try write("A.md", "A"); try write("B.md", "B")
        let data = makeData()
        let model = makeModel()
        model.delete(note: try XCTUnwrap(data.notes.first { $0.id == "A.md" }), from: data, index: nil)
        model.delete(note: try XCTUnwrap(data.notes.first { $0.id == "B.md" }), from: data, index: nil)
        XCTAssertEqual(model.current?.items.map(\.displayName), ["B.md"])
    }

    func testDeletingAFolderShowsTheToastAndUndoBringsItBack() throws {
        try write("Trip/Rome.md", "Rome")
        let data = makeData()
        let model = makeModel()
        model.delete(folder: try XCTUnwrap(data.folders.first), from: data, index: nil)
        XCTAssertTrue(data.folders.isEmpty)
        XCTAssertFalse(exists("Trip"))
        XCTAssertEqual(model.current?.items.first?.kind, .folder)
        model.undo()
        XCTAssertEqual(read("Trip/Rome.md"), "Rome")
        XCTAssertEqual(data.folders.map(\.id), ["Trip"])
    }

    func testAFailedFolderDeleteKeepsTheFolderAndAlerts() throws {
        try write("Trip/Rome.md", "Rome")
        let data = makeData()
        let model = makeModel()
        let folder = try XCTUnwrap(data.folders.first)
        try fm.removeItem(at: url("Trip"))
        model.delete(folder: folder, from: data, index: nil)
        XCTAssertEqual(data.folders.count, 1)
        XCTAssertNil(model.current)
        XCTAssertEqual(model.alert?.title, "Could not delete \u{201C}Trip\u{201D}")
    }

    // MARK: delete from search results

    func testASearchOnlyDataManagerWithoutARootStillRefusesToDelete() throws {
        try write("A.md", "A")
        let note = Note(content: "A", date: Date(), path: "A.md", isLocal: true, url: url("A.md"), type: .Note)
        let search = DataManager(searchNotes: [note])
        let model = makeModel()
        model.delete(note: note, from: search, index: nil)
        XCTAssertTrue(exists("A.md"), "nothing was moved")
        XCTAssertNil(model.current)
        XCTAssertNotNil(model.alert)
    }

    func testDeletingFromSearchResultsWorksThroughTheIndexRoot() throws {
        try write("Sub/A.md", "A\nlemon"); try write("B.md", "B\nlemon")
        try PinStore.save(PinList(["Sub/A.md"]), to: root)
        let index = SearchIndex(rootUrl: root)
        index.waitUntilIdle()
        let hit = try XCTUnwrap(index.search(phrase: "lemon", scope: .all).first { $0.note.id == "A.md" }).note
        let search = DataManager(searchNotes: [hit], libraryRoot: index.rootUrl)
        let model = makeModel()
        model.delete(note: hit, from: search, index: index)
        index.waitUntilIdle()
        XCTAssertNil(model.alert)
        XCTAssertEqual(model.current?.items.first?.originalPath, "Sub/A.md")
        XCTAssertFalse(exists("Sub/A.md"))
        XCTAssertTrue(search.notes.isEmpty, "gone from the search list")
        XCTAssertEqual(index.search(phrase: "lemon", scope: .all).map(\.note.id), ["B.md"], "gone from the index")
        XCTAssertEqual(PinStore.load(from: root).paths, [], "its pin went with it")
        model.undo()
        index.waitUntilIdle()
        XCTAssertEqual(read("Sub/A.md"), "A\nlemon")
        XCTAssertEqual(Set(index.search(phrase: "lemon", scope: .all).map(\.note.id)), ["A.md", "B.md"], "back in the index")
    }
}
