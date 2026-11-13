//
//  RecentSearchesTests.swift
//  purenoteTests
//
@testable import Purnote
import XCTest

final class RecentSearchesTests: XCTestCase {

    private var suite: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suite = "purnote-recent-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testMostRecentFirst() {
        var r = RecentSearches(defaults: defaults)
        r.add("one"); r.add("two"); r.add("three")
        XCTAssertEqual(r.items, ["three", "two", "one"])
    }

    func testKeepsAtMostEight() {
        var r = RecentSearches(defaults: defaults)
        for i in 1...12 { r.add("q\(i)") }
        XCTAssertEqual(r.items.count, 8)
        XCTAssertEqual(r.items.first, "q12")
        XCTAssertEqual(r.items.last, "q5")
    }

    func testCaseInsensitiveDedupeMovesToFrontWithNewSpelling() {
        var r = RecentSearches(defaults: defaults)
        r.add("Pasta"); r.add("lemon"); r.add("PASTA")
        XCTAssertEqual(r.items, ["PASTA", "lemon"])
    }

    func testEmptyAndWhitespaceAreIgnoredAndTrimmed() {
        var r = RecentSearches(defaults: defaults)
        r.add(""); r.add("   "); r.add("\n")
        XCTAssertTrue(r.items.isEmpty)
        r.add("  lemon  ")
        XCTAssertEqual(r.items, ["lemon"])
    }

    func testPersistsThroughTheInjectedDefaults() {
        var r = RecentSearches(defaults: defaults)
        r.add("a"); r.add("b")
        let again = RecentSearches(defaults: defaults)
        XCTAssertEqual(again.items, ["b", "a"])
        // a different store sees nothing
        let other = UserDefaults(suiteName: suite + "-other")!
        defer { other.removePersistentDomain(forName: suite + "-other") }
        XCTAssertTrue(RecentSearches(defaults: other).items.isEmpty)
    }

    func testRemoveAndClear() {
        var r = RecentSearches(defaults: defaults)
        r.add("a"); r.add("b"); r.add("c")
        r.remove("B")
        XCTAssertEqual(r.items, ["c", "a"])
        XCTAssertEqual(RecentSearches(defaults: defaults).items, ["c", "a"])
        r.clear()
        XCTAssertTrue(r.items.isEmpty)
        XCTAssertTrue(RecentSearches(defaults: defaults).items.isEmpty)
    }

    func testIgnoresACorruptStoredValue() {
        defaults.set("not an array", forKey: "recentSearches")
        XCTAssertTrue(RecentSearches(defaults: defaults).items.isEmpty)
        defaults.set([1, 2], forKey: "recentSearches")
        XCTAssertTrue(RecentSearches(defaults: defaults).items.isEmpty)
    }
}
