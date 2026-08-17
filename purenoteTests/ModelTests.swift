@testable import Purnote
import XCTest

/// Small invariants: the non-blocking launch connection, the search tokenizer's
/// punctuation handling, coordinated file round-trips, and the monitor's manual
/// refresh nudge used after seeding.
final class ModelTests: XCTestCase {

    /// The 1.2 crash fix: the app starts with an empty, *unavailable* connection
    /// so nothing blocks the main thread at launch. If this default ever flips
    /// to `true`, the app would try to run on an empty iCloud path.
    func testConnectionDefaultsToUnavailableAndNonLocal() {
        let c = Connection()
        XCTAssertFalse(c.connectionAvailable)   // the crash-fix invariant
        XCTAssertFalse(c.isLocal)
    }

    func testRemovePunctuationReplacesWithSpaces() {
        XCTAssertEqual("a.b,c:d;e?f!g-h".removePuncuation(), "a b c d e f g h")
        XCTAssertEqual("don't".removePuncuation(), "don t")
    }

    func testCoordinatedFileWriteThenReadRoundTrips() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-cf-\(UUID().uuidString)")
        try CoordinatedFile.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("note.md")
        let body = "# Title\n\n- [x] done\n"
        try CoordinatedFile.write(body, to: url)
        XCTAssertEqual(try CoordinatedFile.read(url), body)
    }

    func testMonitorBumpIncrementsChangeCount() {
        let m = iCloudMonitor()
        let before = m.changeCount
        m.bump()
        XCTAssertEqual(m.changeCount, before + 1)
    }
}
