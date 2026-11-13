//
//  SearchIndexIncrementalTests.swift
//  purenoteTests
//
//  The file-backed index: off-main rebuild, incremental update/remove/rename,
//  what is skipped, concurrency, and a timing line (not asserted).
//
@testable import Purnote
import XCTest

final class SearchIndexIncrementalTests: XCTestCase {

    private var root: URL!
    private var fm: FileManager { .default }

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("purnote-inc-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? fm.removeItem(at: root) }

    private func url(_ rel: String) -> URL { root.appendingPathComponent(rel) }
    private func write(_ content: String, _ rel: String) throws {
        let u = url(rel)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: u, atomically: true, encoding: .utf8)
    }
    private func ready(_ index: SearchIndex) -> SearchIndex { index.waitUntilIdle(); return index }
    private func paths(_ index: SearchIndex, _ q: String, scope: SearchScope = .all) -> [String] {
        index.snapshot.search(query: q, scope: scope).map(\.path)
    }

    // MARK: rebuild

    func testRebuildSkipsHiddenFoldersAndAssetsFolders() throws {
        try write("Visible\nlemon", "Visible.md")
        try write("Trashed\nlemon", ".Trash/Trashed.md")
        try write("Internal\nlemon", ".purnote/pins.md")
        try write("Attached\nlemon", "Visible.assets/readme.md")
        try write("Nested\nlemon", "Travel/Nested.md")
        try write("Hidden\nlemon", ".Hidden.md")
        let index = ready(SearchIndex(rootUrl: root))
        let found = Set(paths(index, "lemon").map { ($0 as NSString).lastPathComponent })
        XCTAssertEqual(found, ["Visible.md", "Nested.md"])
        XCTAssertEqual(index.snapshot.entries.count, 2)
    }

    func testInitIndexesOffTheCallingThread() throws {
        try write("A\nlemon", "A.md")
        let index = SearchIndex(rootUrl: root)
        index.waitUntilIdle()
        XCTAssertEqual(paths(index, "lemon").count, 1)
    }

    func testRebuildDropsNotesThatNoLongerExist() throws {
        try write("A\nlemon", "A.md")
        try write("B\nlemon", "B.md")
        let index = ready(SearchIndex(rootUrl: root))
        try fm.removeItem(at: url("B.md"))
        index.rebuild(); index.waitUntilIdle()
        XCTAssertEqual(paths(index, "lemon").map { ($0 as NSString).lastPathComponent }, ["A.md"])
    }

    // MARK: update / remove / rename

    func testUpdateAddsEditsAndRemovesFromDisk() throws {
        try write("A\nold-word", "A.md")
        let index = ready(SearchIndex(rootUrl: root))
        XCTAssertEqual(paths(index, "old").count, 1)

        try write("A\nnew-word", "A.md")
        index.update(path: url("A.md").path); index.waitUntilIdle()
        XCTAssertTrue(paths(index, "old").isEmpty)
        XCTAssertEqual(paths(index, "new").count, 1)

        try write("B\nbrand-new", "Sub/B.md")
        index.update(path: url("Sub/B.md").path); index.waitUntilIdle()
        XCTAssertEqual(paths(index, "brand").count, 1)

        try fm.removeItem(at: url("Sub/B.md"))
        index.update(path: url("Sub/B.md").path); index.waitUntilIdle()
        XCTAssertTrue(paths(index, "brand").isEmpty, "update of a file that is gone removes it")
    }

    func testUpdateIgnoresPathsThatAreNotIndexable() throws {
        let index = ready(SearchIndex(rootUrl: root))
        try write("Secret\nlemon", ".purnote/x.md")
        try write("Pic\nlemon", "A.assets/x.md")
        try write("Text\nlemon", "x.txt")
        for rel in [".purnote/x.md", "A.assets/x.md", "x.txt"] { index.update(path: url(rel).path) }
        index.waitUntilIdle()
        XCTAssertTrue(index.snapshot.entries.isEmpty)
    }

    func testRemoveAndRename() throws {
        try write("A\nlemon", "A.md")
        try write("B\nlemon", "B.md")
        let index = ready(SearchIndex(rootUrl: root))
        index.remove(path: url("A.md").path)
        index.rename(from: url("B.md").path, to: url("C.md").path)
        index.waitUntilIdle()
        XCTAssertEqual(paths(index, "lemon"), [url("C.md").path])
    }

    func testPathsAreNormalisedSoUpdateReplacesTheSameNote() throws {
        try write("A\nold-word", "A.md")
        let index = ready(SearchIndex(rootUrl: root))
        try write("A\nnew-word", "A.md")
        // the same file spelled with a redundant component
        index.update(path: root.path + "/./A.md"); index.waitUntilIdle()
        XCTAssertEqual(index.snapshot.entries.count, 1)
        XCTAssertTrue(paths(index, "old").isEmpty)
    }

    func testSavingOneNoteChangesOnlyThatNotesEntries() throws {
        try write("Alpha\nalpha-body #one", "A.md")
        try write("Beta\nbeta-body #two", "B.md")
        try write("Gamma\ngamma-body #three", "C.md")
        let index = ready(SearchIndex(rootUrl: root))
        let before = index.snapshot
        let a = SearchIndexPath.normalise(url("A.md").path)
        let b = SearchIndexPath.normalise(url("B.md").path)
        let c = SearchIndexPath.normalise(url("C.md").path)

        try write("Beta edited\nbeta-changed #two #extra", "B.md")
        index.update(path: url("B.md").path); index.waitUntilIdle()
        let after = index.snapshot

        XCTAssertEqual(after.entries[a], before.entries[a], "note A's entry must be untouched")
        XCTAssertEqual(after.entries[c], before.entries[c], "note C's entry must be untouched")
        XCTAssertNotEqual(after.entries[b], before.entries[b])
        XCTAssertEqual(after.entries.count, 3)

        // every term of A and C still maps to them, exactly as before
        for p in [a, c] {
            for term in before.entries[p]!.terms {
                XCTAssertEqual(after.terms[term]?.contains(p), true, "term \(term) lost for \(p)")
            }
        }
        // B's old contribution to a shared term is gone, A's and C's remain
        XCTAssertEqual(before.terms["body"], [a, b, c])
        XCTAssertEqual(after.terms["body"], [a, c])
        XCTAssertEqual(paths(index, "changed"), [b])
        XCTAssertEqual(after.paths(taggedWithAll: ["extra"]), [b])
        XCTAssertEqual(after.paths(taggedWithAll: ["one"]), [a])
    }

    // MARK: concurrency

    func testHammeringUpdateFromManyThreadsEndsEqualToAFullRebuild() throws {
        let threads = 6, perThread = 12, rounds = 8
        for t in 0..<threads { for n in 0..<perThread { try write("Note \(t)-\(n)\nround-0 word\(t)", "T\(t)/n\(n).md") } }
        let index = ready(SearchIndex(rootUrl: root))

        let group = DispatchGroup()
        var failures: [String] = []
        let failLock = NSLock()
        for t in 0..<threads {
            DispatchQueue.global().async(group: group) {
                for r in 1...rounds {
                    for n in 0..<perThread {
                        let rel = "T\(t)/n\(n).md"
                        do {
                            // each thread owns its files; the last write of a file is followed by its update
                            try "Note \(t)-\(n)\nround-\(r) word\(t) extra\(r % 3)".write(to: self.url(rel), atomically: true, encoding: .utf8)
                        } catch { failLock.lock(); failures.append("\(error)"); failLock.unlock() }
                        index.update(path: self.url(rel).path)
                        if n % 5 == 0 { _ = index.snapshot.search(query: "round") } // readers run meanwhile
                    }
                }
                // and some removes / re-adds
                let rel = "T\(t)/n0.md"
                try? FileManager.default.removeItem(at: self.url(rel))
                index.update(path: self.url(rel).path)
                try? "Revived \(t)\nrevived".write(to: self.url(rel), atomically: true, encoding: .utf8)
                index.update(path: self.url(rel).path)
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 120), .success)
        XCTAssertEqual(failures, [])
        index.waitUntilIdle()

        let incremental = index.snapshot
        let fresh = ready(SearchIndex(rootUrl: root)).snapshot
        XCTAssertEqual(incremental.entries.count, threads * perThread)
        XCTAssertEqual(incremental, fresh, "the incrementally maintained snapshot must equal a full rebuild")
    }

    // MARK: search through the index

    func testSearchReturnsNotesWithSnippetsRankedAndScoped() throws {
        try write("Lemon tart\nbutter", "Lemon tart.md")
        try write("Shopping\n- [ ] buy a **Lemon** today", "Travel/Shopping.md")
        try write("Other\nnothing", "Other.md")
        let index = ready(SearchIndex(rootUrl: root))

        let all = index.search(phrase: "lemon", scope: .all)
        XCTAssertEqual(all.map { $0.note.url.lastPathComponent }, ["Lemon tart.md", "Shopping.md"])
        XCTAssertNil(all[0].snippet)
        XCTAssertEqual(all[1].snippet?.text, "buy a Lemon today")

        let scoped = index.search(phrase: "lemon", scope: .folder(root.appendingPathComponent("Travel").path))
        XCTAssertEqual(scoped.map { $0.note.url.lastPathComponent }, ["Shopping.md"])

        // the old entry point still works and agrees
        XCTAssertEqual(index.search(phrase: "lemon").map { $0.url.lastPathComponent }, ["Lemon tart.md", "Shopping.md"])
        XCTAssertTrue(index.search(phrase: "").isEmpty)
    }

    func testTagSearchStillWorks() throws {
        try write("A\n#plan one", "A.md")
        try write("B\n#other", "B.md")
        let index = ready(SearchIndex(rootUrl: root))
        XCTAssertEqual(index.allTags(), ["other", "plan"])
        XCTAssertEqual(index.searchByTags(["plan"]).map { $0.url.lastPathComponent }, ["A.md"])
    }

    // MARK: timing (printed, not asserted)

    func testTimingOneUpdateVersusFullRebuildOn1000Notes() throws {
        for i in 0..<1000 {
            let body = (0..<40).map { "word\($0 % 17)x\(i) lorem ipsum dolor sit amet" }.joined(separator: "\n")
            try write("Generated note \(i)\n\(body)", "F\(i % 20)/n\(i).md")
        }
        let index = SearchIndex(rootUrl: root)
        let t0 = CFAbsoluteTimeGetCurrent()
        index.waitUntilIdle()
        let initial = CFAbsoluteTimeGetCurrent() - t0

        let target = url("F3/n3.md")
        try "Generated note 3 edited\nnew content here".write(to: target, atomically: true, encoding: .utf8)
        var updates: [Double] = []
        for _ in 0..<5 {
            let u0 = CFAbsoluteTimeGetCurrent()
            index.update(path: target.path); index.waitUntilIdle()
            updates.append(CFAbsoluteTimeGetCurrent() - u0)
        }
        var rebuilds: [Double] = []
        for _ in 0..<3 {
            let r0 = CFAbsoluteTimeGetCurrent()
            index.rebuild(); index.waitUntilIdle()
            rebuilds.append(CFAbsoluteTimeGetCurrent() - r0)
        }
        func ms(_ s: Double) -> String { String(format: "%.2f ms", s * 1000) }
        print("M2C-TIMING notes=1000 initial_build=\(ms(initial)) update_one=\(updates.map(ms)) (median \(ms(updates.sorted()[2]))) full_rebuild=\(rebuilds.map(ms)) (median \(ms(rebuilds.sorted()[1])))")
        XCTAssertEqual(index.snapshot.entries.count, 1000)
    }
}
