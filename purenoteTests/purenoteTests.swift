//
//  purenoteTests.swift
//  purenoteTests
//
//  Created by Saša Mitrović on 20.10.20.
//
@testable import Purnote
import XCTest

/// Search must reach notes nested in subfolders. The matching rules (prefix,
/// empty queries, AND of words) are covered in SearchCoreTests.
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

    private func write(_ content: String, to relativePath: String) throws {
        let url = tempRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Indexing reaches into subfolders

    func testSearchIsRecursiveAcrossSubfolders() throws {
        try write("# Lisbon\nTram 28 early", to: "root.md")
        try write("# Packing\nPassport and charger", to: "Travel/packing.md")

        let index = SearchIndex(rootUrl: tempRoot) // indexes on init, off the calling thread
        index.waitUntilIdle()

        XCTAssertEqual(index.search(phrase: "passport").count, 1)
        XCTAssertEqual(index.search(phrase: "tram").count, 1)
        // a prefix into a note that lives one folder deep
        XCTAssertEqual(index.search(phrase: "pack").count, 1)
    }
}
