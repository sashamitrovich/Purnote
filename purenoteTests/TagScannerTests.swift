//
//  TagScannerTests.swift
//  purenoteTests
//

@testable import Purnote
import XCTest

final class TagScannerTests: XCTestCase {

    func testExtractsInlineTags() {
        XCTAssertEqual(TagScanner.tags(in: "hello #world"), ["world"])
        XCTAssertEqual(TagScanner.tags(in: "#first and #second"), ["first", "second"])
        XCTAssertEqual(TagScanner.tags(in: "(#paren) #tag2"), ["paren", "tag2"])
    }

    func testIgnoresHeadings() {
        XCTAssertEqual(TagScanner.tags(in: "# Heading"), [])
        XCTAssertEqual(TagScanner.tags(in: "## Sub"), [])
        XCTAssertEqual(TagScanner.tags(in: "### Deep"), [])
    }

    func testIgnoresMidWordAndUrlsAndEscapes() {
        XCTAssertEqual(TagScanner.tags(in: "C# and https://x.com/a#frag"), [])
        XCTAssertEqual(TagScanner.tags(in: "word#suffix"), [])
        XCTAssertEqual(TagScanner.tags(in: "\\#escaped"), [])
    }

    func testIgnoresCode() {
        XCTAssertEqual(TagScanner.tags(in: "`#incode` #out"), ["out"])
        XCTAssertEqual(TagScanner.tags(in: "```\n#fenced\n```\n#realtag"), ["realtag"])
        XCTAssertEqual(TagScanner.tags(in: "~~~\n#tildefenced\n~~~\n#after"), ["after"])
    }

    func testAllowsHyphenAndUnderscore() {
        XCTAssertEqual(TagScanner.tags(in: "#to-do and #snake_case"), ["to-do", "snake_case"])
    }

    func testDeduplicatesCaseInsensitivelyKeepingFirstCase() {
        XCTAssertEqual(TagScanner.tags(in: "#Tag and #tag"), ["Tag"])
    }

    func testNoTags() {
        XCTAssertEqual(TagScanner.tags(in: "plain text"), [])
        XCTAssertEqual(TagScanner.tags(in: ""), [])
    }
}
