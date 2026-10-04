//
//  ShareContentTests.swift
//  purenoteTests
//
//  Tests for the logic that turns a shared item into a note: how text and a
//  URL combine, and how the note gets its name.
//

@testable import Purnote
import XCTest

final class ShareContentTests: XCTestCase {

    // MARK: - combining text and URL

    func testTextOnlyBecomesTheBody() {
        XCTAssertEqual(ShareContent.note(text: "hello", url: nil), "hello")
    }

    func testURLOnlyBecomesTheBody() {
        XCTAssertEqual(
            ShareContent.note(text: nil, url: "https://example.com/p/1"),
            "https://example.com/p/1")
    }

    func testTextAndURLAreSeparatedByABlankLine() {
        XCTAssertEqual(
            ShareContent.note(text: "A post", url: "https://example.com/p/1"),
            "A post\n\nhttps://example.com/p/1")
    }

    func testNothingSharedIsEmpty() {
        XCTAssertEqual(ShareContent.note(text: nil, url: nil), "")
        XCTAssertEqual(ShareContent.note(text: "", url: ""), "")
    }

    func testWhitespaceOnlyTextCountsAsEmpty() {
        // a URL survives even when the "text" is just spaces
        XCTAssertEqual(
            ShareContent.note(text: "   \n  ", url: "https://example.com"),
            "https://example.com")
    }

    func testURLIsTrimmed() {
        XCTAssertEqual(
            ShareContent.note(text: nil, url: "  https://example.com  "),
            "https://example.com")
    }

    // MARK: - naming

    func testTitleComesFromTheFirstLine() {
        XCTAssertEqual(ShareContent.title(from: "My shared post"), "My shared post")
        XCTAssertEqual(
            ShareContent.title(from: "# A heading\nwith more text"),
            "A heading")
    }

    func testEmptyContentFallsBackToAGeneratedName() {
        let title = ShareContent.title(from: "")
        XCTAssertFalse(title.isEmpty)
        // the fallback is a timestamp: safe to use as a filename stem
        XCTAssertFalse(title.contains("/"))
        XCTAssertFalse(title.contains(":"))
    }
}
