@testable import Purnote
import XCTest

/// A tap on the rendered page opens the editor unless it lands on a link.
/// `LinkHit` decides that from the block's Markdown source. Offsets are
/// Characters, the unit `TextHitTest.characterOffset` returns -- not UTF-16.
final class LinkHitTests: XCTestCase {

    // MARK: - helpers

    /// Character offset of the first occurrence of `needle` in `text`, plus `plus`.
    private func offset(of needle: String, in text: String, plus: Int = 0) -> Int {
        guard let r = text.range(of: needle) else {
            XCTFail("\(needle) not in \(text)")
            return -1
        }
        return text.distance(from: text.startIndex, to: r.lowerBound) + plus
    }

    private func url(_ needle: String, in text: String, plus: Int = 0) -> URL? {
        LinkHit.url(at: offset(of: needle, in: text, plus: plus), in: text)
    }

    // MARK: - inline links

    func testHitOnTheLabelOfAnInlineLink() {
        let text = "See [the docs](https://example.com/docs) for more."
        XCTAssertEqual(url("docs]", in: text), URL(string: "https://example.com/docs"))
        XCTAssertEqual(url("the docs", in: text), URL(string: "https://example.com/docs"))
    }

    func testHitOnTheDestinationPartOfAnInlineLink() {
        let text = "See [the docs](https://example.com/docs) for more."
        XCTAssertEqual(url("https://example", in: text, plus: 3), URL(string: "https://example.com/docs"))
    }

    func testBracketsAndParenthesesOfTheLinkCountToo() {
        let text = "See [the docs](https://example.com/docs) for more."
        XCTAssertNotNil(url("[the", in: text))
        XCTAssertNotNil(url(")", in: text))
    }

    func testMissJustBeforeAndJustAfterTheLink() {
        let text = "See [the docs](https://example.com/docs) for more."
        let start = offset(of: "[the", in: text)
        let end = offset(of: ")", in: text) + 1
        XCTAssertNil(LinkHit.url(at: start - 1, in: text), "the space before the link")
        XCTAssertNotNil(LinkHit.url(at: start, in: text))
        XCTAssertNotNil(LinkHit.url(at: end - 1, in: text))
        XCTAssertNil(LinkHit.url(at: end, in: text), "the space after the link")
        XCTAssertNil(LinkHit.url(at: 0, in: text))
    }

    func testSecondOfTwoLinksInOneParagraph() {
        let text = "[one](https://one.example) and [two](https://two.example) done"
        XCTAssertEqual(url("one]", in: text), URL(string: "https://one.example"))
        XCTAssertEqual(url("two]", in: text), URL(string: "https://two.example"))
        XCTAssertNil(url(" and ", in: text, plus: 2))
    }

    func testDestinationWithBalancedParentheses() {
        let text = "Read [Swift](https://en.wikipedia.org/wiki/Swift_(programming_language)) now"
        let expected = URL(string: "https://en.wikipedia.org/wiki/Swift_(programming_language)")
        XCTAssertEqual(url("Swift]", in: text), expected)
        XCTAssertEqual(url("language", in: text), expected)
        XCTAssertNil(url(" now", in: text, plus: 1))
    }

    func testDestinationWithATitle() {
        let text = #"A [link](https://x.example/a "the title") here"#
        XCTAssertEqual(url("link", in: text), URL(string: "https://x.example/a"))
        XCTAssertEqual(url("the title", in: text), URL(string: "https://x.example/a"))
        XCTAssertNil(url(" here", in: text, plus: 1))
    }

    func testSingleQuotedTitle() {
        let text = "A [link](https://x.example/a 'title') here"
        XCTAssertEqual(url("link", in: text), URL(string: "https://x.example/a"))
    }

    func testLabelThatWrapsAcrossLines() {
        let text = "Go to [a rather long\nlabel that wraps](https://x.example/w) please"
        XCTAssertEqual(url("rather", in: text), URL(string: "https://x.example/w"))
        XCTAssertEqual(url("wraps", in: text), URL(string: "https://x.example/w"))
    }

    func testMailtoAndTel() {
        let text = "Write [me](mailto:hi@example.com) or [call](tel:+41000000)"
        XCTAssertEqual(url("me]", in: text), URL(string: "mailto:hi@example.com"))
        XCTAssertEqual(url("call", in: text), URL(string: "tel:+41000000"))
    }

    func testRelativeLinkIsNotHandled() {
        let text = "See [other note](Other%20note.md) or [here](./x/y)"
        XCTAssertNil(url("other note", in: text))
        XCTAssertNil(url("here", in: text))
    }

    func testOtherSchemesAreNotHandled() {
        let text = "[files](ftp://example.com/x) and [js](javascript:alert(1)) and [app](myapp://open)"
        XCTAssertNil(url("files", in: text))
        XCTAssertNil(url("js]", in: text))
        XCTAssertNil(url("app", in: text))
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertEqual(url("x]", in: "[x](HTTPS://Example.com)")?.scheme?.lowercased(), "https")
    }

    // MARK: - autolinks and bare URLs

    func testAutolink() {
        let text = "Visit <https://example.com/a?b=1> today"
        XCTAssertEqual(url("example", in: text), URL(string: "https://example.com/a?b=1"))
        XCTAssertEqual(url("<https", in: text), URL(string: "https://example.com/a?b=1"))
        XCTAssertNil(url("today", in: text))
    }

    func testBareURL() {
        let text = "Go to https://example.com/page now"
        XCTAssertEqual(url("example", in: text), URL(string: "https://example.com/page"))
        XCTAssertNil(url("Go", in: text))
        XCTAssertNil(url("now", in: text))
        XCTAssertNil(LinkHit.url(at: offset(of: "https", in: text) - 1, in: text))
    }

    func testBareURLDoesNotSwallowTrailingPunctuationOrParenthesis() {
        let text = "(see https://example.com/x), or https://example.org."
        XCTAssertEqual(url("example.com", in: text), URL(string: "https://example.com/x"))
        XCTAssertNil(url("), or", in: text))
        XCTAssertEqual(url("example.org", in: text), URL(string: "https://example.org"))
        XCTAssertNil(LinkHit.url(at: text.count - 1, in: text), "the full stop")
    }

    func testBareURLInsideAWordIsNotALink() {
        XCTAssertNil(url("example", in: "nothttps://example.com"))
    }

    // MARK: - things that look like links and are not

    func testImageSyntaxIsNotALink() {
        let text = "Look ![a cat](https://example.com/cat.png) there"
        XCTAssertNil(url("a cat", in: text))
        XCTAssertNil(url("example", in: text))
        XCTAssertNil(url("!", in: text))
    }

    func testImageInsideALinkStillOpensTheLink() {
        let text = "[![logo](https://example.com/l.png)](https://example.com/home)"
        XCTAssertEqual(url("logo", in: text), URL(string: "https://example.com/home"))
    }

    func testLinkInsideACodeSpanIsIgnored() {
        let text = "Type `[a](https://example.com)` or `https://example.org` to try"
        XCTAssertNil(url("[a]", in: text, plus: 1))
        XCTAssertNil(url("example.com", in: text))
        XCTAssertNil(url("example.org", in: text))
    }

    func testLinkAfterACodeSpanStillWorks() {
        let text = "Use `code` then [link](https://example.com)"
        XCTAssertEqual(url("link", in: text), URL(string: "https://example.com"))
    }

    func testLinkInsideAFencedCodeBlockIsIgnored() {
        let text = "```\n[a](https://example.com)\nhttps://example.org\n```\n[b](https://example.net)"
        XCTAssertNil(url("[a]", in: text, plus: 1))
        XCTAssertNil(url("example.org", in: text))
        XCTAssertEqual(url("b]", in: text), URL(string: "https://example.net"))
    }

    func testLinkInsideATildeFenceWithLanguageIsIgnored() {
        let text = "~~~md\n<https://example.com>\n~~~"
        XCTAssertNil(url("example", in: text))
    }

    func testEscapedBracketIsNotALink() {
        let text = #"\[a](https://example.com)"#
        XCTAssertNil(url("a]", in: text))
    }

    func testPlainBracketsAndPlainTextAreNotLinks() {
        XCTAssertNil(url("b", in: "a [b] c (d) e"))
        XCTAssertNil(url("b", in: "a [b](  ) c"))
        XCTAssertNil(url("b", in: "a <b>text</b>"))
    }

    // MARK: - offsets and bounds

    func testOffsetsAreCharactersNotUTF16() {
        // the flag and the combining accent are several UTF-16 units but one
        // Character each; a UTF-16 reading would be off by a few places
        let text = "Zu\u{308}rich 🇨🇭 👨‍👩‍👧 [x](https://example.com) end"
        XCTAssertEqual(url("x]", in: text), URL(string: "https://example.com"))
        XCTAssertNil(url("end", in: text))
        let before = offset(of: "[x]", in: text) - 1
        XCTAssertNil(LinkHit.url(at: before, in: text))
        // the last Character of the link, counted the way TextHitTest counts
        let end = offset(of: ")", in: text)
        XCTAssertNotNil(LinkHit.url(at: end, in: text))
        XCTAssertNil(LinkHit.url(at: end + 1, in: text))
    }

    func testNonASCIIInsideTheLabelAndURL() {
        let text = "[日本語 🙂](https://example.com/日本)"
        XCTAssertNotNil(LinkHit.url(at: 2, in: text))
        XCTAssertNotNil(LinkHit.url(at: text.count - 1, in: text))
    }

    func testEmptyTextAndOutOfRangeOffsetsReturnNil() {
        XCTAssertNil(LinkHit.url(at: 0, in: ""))
        XCTAssertNil(LinkHit.url(at: -1, in: "[a](https://example.com)"))
        XCTAssertNil(LinkHit.url(at: 1_000, in: "[a](https://example.com)"))
        let text = "[a](https://example.com)"
        XCTAssertNil(LinkHit.url(at: text.count, in: text), "one past the end")
        XCTAssertNil(LinkHit.url(at: Int.max, in: text))
        XCTAssertNil(LinkHit.url(at: Int.min, in: text))
    }

    func testUnterminatedConstructsDoNotCrash() {
        for text in ["[a](https://x.y", "[a](", "[a]", "[", "<https://x.y", "`", "```", "![", "[a](<https://x.y",
                     "[a](https://x.y \"title", "https://", "\\"] {
            for i in -1...text.count + 1 {
                _ = LinkHit.url(at: i, in: text)
            }
        }
    }
}
