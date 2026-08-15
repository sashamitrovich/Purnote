//
//  purenoteTests.swift
//  purenoteTests
//
//  Created by Saša Mitrović on 20.10.20.
//
@testable import Purnote
import XCTest

/// Regression tests for the note search index.
///
/// These pin the bugs fixed during the 2026 UX pass so they can't come back:
///  - typing a partial word ("mark") must find notes containing the full word
///    ("markdown") — search is prefix, not exact match;
///  - an empty or punctuation-only query must match nothing, and must not let
///    an empty token wipe out a multi-word search;
///  - search must reach notes nested in subfolders.
final class SearchIndexTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    /// A search index over an empty temp directory, so tests can add terms by
    /// hand without depending on file I/O.
    private func emptyIndex() -> SearchIndex {
        SearchIndex(rootUrl: tempRoot)
    }

    private func write(_ content: String, to relativePath: String) throws {
        let url = tempRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Prefix matching (the reported bug)

    func testPrefixFindsWordInTheMiddleOfANote() {
        let index = emptyIndex()
        for word in ["This", "note", "uses", "Markdown", "everywhere"] {
            index.addTerm(term: word, path: "/note.md")
        }

        // typing "mark" has to find the note that contains "markdown"
        XCTAssertEqual(index.searchPhrase(phrase: "mark"), ["/note.md"])
        // and it is case-insensitive
        XCTAssertEqual(index.searchPhrase(phrase: "MARK"), ["/note.md"])
        // while the full word still matches
        XCTAssertEqual(index.searchPhrase(phrase: "markdown"), ["/note.md"])
    }

    func testPrefixDoesNotMatchUnrelatedWords() {
        let index = emptyIndex()
        index.addTerm(term: "banana", path: "/fruit.md")
        XCTAssertTrue(index.searchPhrase(phrase: "mark").isEmpty)
    }

    // MARK: - Empty and punctuation-only queries

    func testEmptyOrPunctuationQueryMatchesNothing() {
        let index = emptyIndex()
        index.addTerm(term: "something", path: "/a.md")

        XCTAssertTrue(index.searchPhrase(phrase: "").isEmpty)
        XCTAssertTrue(index.searchPhrase(phrase: "   ").isEmpty)
        XCTAssertTrue(index.searchPhrase(phrase: "!!!").isEmpty)
        XCTAssertEqual(index.getSearchResultsAsUrls(phrase: ""), [])
    }

    // MARK: - Multi-word search is an AND

    func testMultipleTokensIntersect() {
        let index = emptyIndex()
        index.addTerm(term: "weeknight", path: "/A.md")
        index.addTerm(term: "pasta", path: "/A.md")
        index.addTerm(term: "pasta", path: "/B.md")

        // only the note with both words (by prefix) survives the intersection
        XCTAssertEqual(index.searchPhrase(phrase: "week pasta"), ["/A.md"])
        // a single shared word returns both
        XCTAssertEqual(index.searchPhrase(phrase: "pasta"), ["/A.md", "/B.md"])
    }

    /// A trailing empty token — "pasta " with a stray space — must not wipe the
    /// result via an empty intersection.
    func testTrailingSpaceDoesNotEmptyResults() {
        let index = emptyIndex()
        index.addTerm(term: "pasta", path: "/A.md")
        XCTAssertEqual(index.searchPhrase(phrase: "pasta "), ["/A.md"])
    }

    // MARK: - Indexing reaches into subfolders

    func testSearchIsRecursiveAcrossSubfolders() throws {
        try write("# Lisbon\nTram 28 early", to: "root.md")
        try write("# Packing\nPassport and charger", to: "Travel/packing.md")

        let index = SearchIndex(rootUrl: tempRoot) // indexes on init

        XCTAssertEqual(index.search(phrase: "passport").count, 1)
        XCTAssertEqual(index.search(phrase: "tram").count, 1)
        // a prefix into a note that lives one folder deep
        XCTAssertEqual(index.search(phrase: "pack").count, 1)
    }
}
