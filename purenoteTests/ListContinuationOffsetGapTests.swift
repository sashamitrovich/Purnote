//
//  ListContinuationOffsetGapTests.swift
//  purenoteTests
//
//  Gap 4 from the test-suite audit: ListContinuation splits lines on "\n" but
//  counts offsets in Swift Characters, where "\r\n" is ONE Character. Failing
//  tests are CONFIRMED BUGS and stay failing on purpose.
//

@testable import Purnote
import XCTest

final class ListContinuationOffsetGapTests: XCTestCase {

    /// Return at the end of a non-empty item in a CRLF document. The caret is
    /// in Character offsets (as MarkdownTextView converts it).
    func testReturnAtEndOfAnItemInACRLFDocumentContinuesTheList() {
        let text = "Intro\r\n\r\n- a\r\n- b\r\n- c\r\n"
        // caret right after "b" (before the CRLF that ends the line)
        let caret = text.distance(from: text.startIndex, to: text.range(of: "- b")!.upperBound)
        let result = ListContinuation.onReturn(text, at: caret)
        XCTAssertEqual(result?.text, "Intro\r\n\r\n- a\r\n- b\r\n- \r\n- c\r\n")
    }

    /// Return on an EMPTY item in the middle of a CRLF document must end the
    /// list: the marker is removed and the line is left empty.
    func testReturnOnAnEmptyItemInTheMiddleOfACRLFDocumentEndsTheList() {
        let text = "Intro\r\n\r\n- a\r\n- \r\n- c\r\n"
        let caret = text.distance(from: text.startIndex, to: text.range(of: "- \r\n- c")!.lowerBound) + 2
        let result = ListContinuation.onReturn(text, at: caret)
        // GAP 4 (fixed): the trailing "\r" used to make the item look non-empty, so a new bullet was added instead
        XCTAssertEqual(result?.text, "Intro\r\n\r\n- a\r\n\r\n- c\r\n")
    }

    /// Same, with the empty item on the last line (no trailing CR), after
    /// several CRLF lines: this is where the line start drifts by one per CRLF.
    func testReturnOnAnEmptyLastItemAfterCRLFLinesEndsTheList() {
        let text = "Intro\r\nmore\r\n- a\r\n- "
        let result = ListContinuation.onReturn(text, at: text.count)
        let edit = ListContinuation.edit(text, at: text.count)
        // GAP 4 (fixed): the edit's range used to start after the real line start (drift of 1 per CRLF)
        XCTAssertEqual(result?.text, "Intro\r\nmore\r\n- a\r\n")
        XCTAssertEqual(edit.map { $0.range.upperBound <= text.count }, true,
                       "edit range must lie inside the text (\(text.count) characters)")
    }

    /// LF baseline for the same shape: must pass (guards the test itself).
    func testLFBaselineEmptyLastItemEndsTheList() {
        let text = "Intro\nmore\n- a\n- "
        XCTAssertEqual(ListContinuation.onReturn(text, at: text.count)?.text, "Intro\nmore\n- a\n")
    }

    /// Emoji / ZWJ / flag / combining sequences before the list: both sides
    /// count Characters, so these are expected to be fine (regression guard).
    func testEmojiAndCombiningBeforeTheListDoNotShiftTheEdit() {
        let before = "🇨🇭 👨‍👩‍👧 caf\u{65}\u{301} 🧑🏽‍💻\n"
        let text = before + "- a\n- "
        XCTAssertEqual(ListContinuation.onReturn(text, at: text.count)?.text, before + "- a\n")
        let mid = before + "- a\n- \n- c\n"
        let caret = mid.distance(from: mid.startIndex, to: mid.range(of: "- \n- c")!.lowerBound) + 2
        XCTAssertEqual(ListContinuation.onReturn(mid, at: caret)?.text, before + "- a\n\n- c\n")
        let cont = before + "- a\n"
        XCTAssertEqual(ListContinuation.onReturn(cont, at: cont.count - 1)?.text, before + "- a\n- \n")
    }
}
