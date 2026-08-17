@testable import Purnote
import XCTest

/// The formatting bar (added in 1.1). The buffer must stay raw Markdown at all
/// times and the selection must land where a typist expects, so these pin the
/// fiddly offset math behind Bold / Heading / Link / list toggles.
final class MarkdownFormatterTests: XCTestCase {

    // MARK: - wrap

    func testBoldWrapsSelection() {
        let r = MarkdownFormatter.wrap("hello world", 0, 5, with: "**")
        XCTAssertEqual(r.text, "**hello** world")
        XCTAssertEqual([r.lower, r.upper], [2, 7])   // selection still around "hello"
    }

    func testBoldUnwrapsAnAlreadyBoldSelection() {
        let r = MarkdownFormatter.wrap("**hello** world", 0, 9, with: "**")
        XCTAssertEqual(r.text, "hello world")
        XCTAssertEqual([r.lower, r.upper], [0, 5])
    }

    func testWrapWithEmptySelectionInsertsPairAndPutsCursorBetween() {
        let r = MarkdownFormatter.wrap("ab", 1, 1, with: "**")
        XCTAssertEqual(r.text, "a****b")
        XCTAssertEqual([r.lower, r.upper], [3, 3])   // cursor between the markers
    }

    func testItalicUsesSingleAsterisk() {
        let r = MarkdownFormatter.wrap("word", 0, 4, with: "*")
        XCTAssertEqual(r.text, "*word*")
        XCTAssertEqual([r.lower, r.upper], [1, 5])
    }

    // MARK: - toggleLinePrefix

    func testAddsHeadingPrefixToLine() {
        let r = MarkdownFormatter.toggleLinePrefix("title", 0, 0, prefix: "# ")
        XCTAssertEqual(r.text, "# title")
    }

    func testRemovesPrefixWhenAlreadyPresent() {
        let r = MarkdownFormatter.toggleLinePrefix("# title", 2, 2, prefix: "# ")
        XCTAssertEqual(r.text, "title")
    }

    func testReplacesCompetingBlockPrefix() {
        // a bulleted line toggled to a checklist swaps the marker, not stacks it
        let r = MarkdownFormatter.toggleLinePrefix("- item", 0, 0, prefix: "- [ ] ")
        XCTAssertEqual(r.text, "- [ ] item")
    }

    func testTogglesPrefixOnTheCurrentLineOnly() {
        let text = "first\nsecond"
        let cursor = text.distance(from: text.startIndex, to: text.range(of: "second")!.lowerBound)
        let r = MarkdownFormatter.toggleLinePrefix(text, cursor, cursor, prefix: "> ")
        XCTAssertEqual(r.text, "first\n> second")
    }

    // MARK: - insertLink

    func testInsertLinkWrapsSelectionAndSelectsUrlPlaceholder() {
        let r = MarkdownFormatter.insertLink("see docs here", 4, 8)   // "docs"
        XCTAssertEqual(r.text, "see [docs](url) here")
        XCTAssertEqual(r.text[range(r.text, r.lower, r.upper)], "url")
    }

    // MARK: - lineStartOffset

    func testLineStartOffset() {
        let text = "abc\ndef\nghi"
        XCTAssertEqual(MarkdownFormatter.lineStartOffset(text, at: 1), 0)
        XCTAssertEqual(MarkdownFormatter.lineStartOffset(text, at: 5), 4)   // within "def"
        XCTAssertEqual(MarkdownFormatter.lineStartOffset(text, at: 9), 8)   // within "ghi"
    }

    // helper: substring for offset range
    private func range(_ s: String, _ lo: Int, _ hi: Int) -> Range<String.Index> {
        s.index(s.startIndex, offsetBy: lo)..<s.index(s.startIndex, offsetBy: hi)
    }
}
