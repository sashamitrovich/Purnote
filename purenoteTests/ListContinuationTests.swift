@testable import Purnote
import XCTest

/// Return inside a list. The behaviour people expect without being able to
/// name it: another bullet, the next number, an unticked box -- and an escape
/// from the list when the item is left empty.
final class ListContinuationTests: XCTestCase {

    /// Presses Return at `caret` and returns the text with a "|" where the
    /// caret ended up, so the expectations below read like the screen does.
    private func returnPressed(_ text: String, at caret: Int) -> String? {
        guard let r = ListContinuation.onReturn(text, at: caret) else { return nil }
        var out = r.text
        out.insert("|", at: out.index(out.startIndex, offsetBy: r.caret))
        return out
    }

    // MARK: - continuing

    func testBulletContinues() {
        XCTAssertEqual(returnPressed("- milk", at: 6), "- milk\n- |")
    }

    func testStarBulletKeepsItsCharacter() {
        XCTAssertEqual(returnPressed("* milk", at: 6), "* milk\n* |")
    }

    func testNumberedListAdvances() {
        XCTAssertEqual(returnPressed("1. first", at: 8), "1. first\n2. |")
    }

    func testNumberedListAdvancesPastNine() {
        XCTAssertEqual(returnPressed("9. ninth", at: 8), "9. ninth\n10. |")
    }

    func testParenthesisedNumberKeepsItsSeparator() {
        XCTAssertEqual(returnPressed("1) first", at: 8), "1) first\n2) |")
    }

    func testCheckboxContinuesUnticked() {
        XCTAssertEqual(returnPressed("- [ ] milk", at: 10), "- [ ] milk\n- [ ] |")
    }

    func testTickedCheckboxStillContinuesUnticked() {
        // the next thing you write has not been done yet
        XCTAssertEqual(returnPressed("- [x] milk", at: 10), "- [x] milk\n- [ ] |")
    }

    func testQuoteContinues() {
        XCTAssertEqual(returnPressed("> quoted", at: 8), "> quoted\n> |")
    }

    func testIndentationIsCarriedToTheNextItem() {
        XCTAssertEqual(returnPressed("  - milk", at: 8), "  - milk\n  - |")
    }

    func testContinuingInTheMiddleOfAnItemSplitsIt() {
        // Return after "mi" pushes "lk" onto a new item, as in Notes
        XCTAssertEqual(returnPressed("- milk", at: 4), "- mi\n- |lk")
    }

    func testContinuesFromALineInTheMiddleOfADocument() {
        let source = "# Shopping\n\n- milk\n- bread"
        XCTAssertEqual(returnPressed(source, at: 18), "# Shopping\n\n- milk\n- |\n- bread")
    }

    // MARK: - leaving the list

    func testReturnOnAnEmptyItemEndsTheList() {
        XCTAssertEqual(returnPressed("- milk\n- ", at: 9), "- milk\n|")
    }

    func testReturnOnAnEmptyCheckboxEndsTheList() {
        XCTAssertEqual(returnPressed("- [ ] milk\n- [ ] ", at: 17), "- [ ] milk\n|")
    }

    func testReturnOnAnEmptyNestedItemStepsOutOneLevel() {
        // still a list, just one level shallower
        XCTAssertEqual(returnPressed("- a\n  - ", at: 8), "- a\n- |")
    }

    func testReturnOnAnEmptyQuoteEndsTheQuote() {
        XCTAssertEqual(returnPressed("> quoted\n> ", at: 11), "> quoted\n|")
    }

    // MARK: - leaving well alone

    func testPlainTextIsNotAList() {
        XCTAssertNil(ListContinuation.onReturn("just a sentence", at: 15))
    }

    func testHeadingIsNotAList() {
        XCTAssertNil(ListContinuation.onReturn("# Title", at: 7))
    }

    func testADashWithoutASpaceIsNotAList() {
        XCTAssertNil(ListContinuation.onReturn("-milk", at: 5))
    }

    func testInsideACodeFenceReturnIsJustANewline() {
        let source = "```\n- not a list, it is code"
        XCTAssertNil(ListContinuation.onReturn(source, at: source.count))
    }

    func testAfterAClosedFenceListsWorkAgain() {
        let source = "```\ncode\n```\n\n- milk"
        XCTAssertEqual(returnPressed(source, at: source.count), "```\ncode\n```\n\n- milk\n- |")
    }

    func testEmptyTextIsNotAList() {
        XCTAssertNil(ListContinuation.onReturn("", at: 0))
    }

    // MARK: - marker parsing

    func testMarkerReadsIndentAndNext() {
        let m = ListContinuation.marker(of: "   - [x] done")
        XCTAssertEqual(m?.indent, "   ")
        XCTAssertEqual(m?.text, "- [x] ")
        XCTAssertEqual(m?.next, "- [ ] ")
    }

    func testMarkerRejectsProse() {
        XCTAssertNil(ListContinuation.marker(of: "milk and bread"))
    }
}
