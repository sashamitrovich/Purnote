@testable import Purnote
import UIKit
import XCTest

/// A tap is matched against what the reader sees, not against the Markdown
/// source: the source carries a long hidden destination after every link label,
/// so a position in the source is not a position on the page.
final class LinkRenderTests: XCTestCase {

    private func plain(_ text: String) -> String { LinkHit.rendered(from: text).plain }

    /// The text each link covers in `plain`.
    private func labels(_ text: String) -> [(String, URL)] {
        let r = LinkHit.rendered(from: text)
        let chars = Array(r.plain)
        return r.links.map { (String(chars[$0.range]), $0.url) }
    }

    // MARK: - rendering

    func testInlineLinkShowsOnlyItsLabel() {
        let text = "See [the docs](https://example.com) now"
        let r = LinkHit.rendered(from: text)
        XCTAssertEqual(r.plain, "See the docs now")
        XCTAssertEqual(r.links.count, 1)
        XCTAssertEqual(r.links[0].range, 4..<12)
        XCTAssertEqual(r.links[0].url, URL(string: "https://example.com"))
    }

    func testEmphasisAndCodeInsideALabelAreDropped() {
        let text = "[**bold** and `code` and *it*](https://x.example)"
        let r = LinkHit.rendered(from: text)
        XCTAssertEqual(r.plain, "bold and code and it")
        XCTAssertEqual(r.links.map(\.range), [0..<20])
    }

    func testEmphasisAndCodeMarkersAreDroppedEverywhere() {
        XCTAssertEqual(plain("**a** *b* _c_ ~~d~~ `e` __f__"), "a b c d e f")
    }

    func testLiteralAsterisksAndUnderscoresStay() {
        XCTAssertEqual(plain("2 * 3 and snake_case_name"), "2 * 3 and snake_case_name")
    }

    func testAutolinkShowsTheURLText() {
        let r = LinkHit.rendered(from: "Go <https://x.example/a> now")
        XCTAssertEqual(r.plain, "Go https://x.example/a now")
        XCTAssertEqual(r.links.map(\.range), [3..<22])
        XCTAssertEqual(r.links.first?.url, URL(string: "https://x.example/a"))
    }

    func testBareURLShowsItselfWithoutTrailingPunctuation() {
        let r = LinkHit.rendered(from: "Go to https://x.example/a, then.")
        XCTAssertEqual(r.plain, "Go to https://x.example/a, then.")
        XCTAssertEqual(r.links.map(\.range), [6..<25])
    }

    func testHeadingHashesAreDropped() {
        let r = LinkHit.rendered(from: "## Title with [l](https://x.example)")
        XCTAssertEqual(r.plain, "Title with l")
        XCTAssertEqual(r.links.map(\.range), [11..<12])
    }

    func testBlockquoteMarkersAreDroppedAndLinesJoinWithASpace() {
        let r = LinkHit.rendered(from: "> quoted [l](https://x.example)\n> more")
        XCTAssertEqual(r.plain, "quoted l more")
        XCTAssertEqual(r.links.map(\.range), [7..<8])
    }

    func testListMarkersAreDroppedAndItemsStayOnTheirOwnLines() {
        let r = LinkHit.rendered(from: "- one\n* [two](https://x.example)\n1. three\n2) four")
        XCTAssertEqual(r.plain, "one\ntwo\nthree\nfour")
        XCTAssertEqual(r.links.map(\.range), [4..<7])
    }

    func testSoftBreakReadsAsASpaceAndHardBreakKeepsTheLine() {
        XCTAssertEqual(plain("one\ntwo"), "one two")
        XCTAssertEqual(plain("one  \ntwo"), "one\ntwo")
        XCTAssertEqual(plain("one\\\ntwo"), "one\ntwo")
    }

    func testImagesAreDroppedEntirely() {
        let r = LinkHit.rendered(from: "a ![alt text](https://x.example/y.png) b")
        XCTAssertEqual(r.plain, "a  b")
        XCTAssertTrue(r.links.isEmpty)
    }

    func testRelativeAndOtherSchemeLinksKeepTheirLabelButAreNotLinks() {
        let r = LinkHit.rendered(from: "[a](note.md) [b](ftp://x.example) [c](javascript:alert(1))")
        XCTAssertEqual(r.plain, "a b c")
        XCTAssertTrue(r.links.isEmpty)
    }

    func testMailtoAndTelAreLinks() {
        XCTAssertEqual(labels("[me](mailto:a@b.example) [ring](tel:+41000)").map(\.0), ["me", "ring"])
    }

    func testCodeSpanShowsItsContentAndIsNeverALink() {
        let r = LinkHit.rendered(from: "`[a](https://x.example)` and ``x ` y``")
        XCTAssertEqual(r.plain, "[a](https://x.example) and x ` y")
        XCTAssertTrue(r.links.isEmpty)
    }

    func testFencedCodeIsShownVerbatimAndNeverALink() {
        let text = "```swift\n[a](https://x.example)\n```\nafter [b](https://y.example)"
        let r = LinkHit.rendered(from: text)
        XCTAssertEqual(r.plain, "[a](https://x.example)\nafter b")
        XCTAssertEqual(r.links.map(\.range), [29..<30])
        XCTAssertEqual(r.links.first?.url, URL(string: "https://y.example"))
    }

    func testEscapedBracketIsLiteral() {
        let r = LinkHit.rendered(from: #"\[a] and \*star\*"#)
        XCTAssertEqual(r.plain, "[a] and *star*")
    }

    func testTwoLinksAndAWrappedLabel() {
        let text = "[one](https://one.example) and [a long\nlabel](https://two.example)"
        let r = LinkHit.rendered(from: text)
        XCTAssertEqual(r.plain, "one and a long label")
        XCTAssertEqual(r.links.map(\.range), [0..<3, 8..<20])
        XCTAssertEqual(r.links.map(\.url), [URL(string: "https://one.example")!, URL(string: "https://two.example")!])
    }

    func testRangesCountCharactersNotUTF16() {
        let r = LinkHit.rendered(from: "Zu\u{308}rich 🇨🇭 👨‍👩‍👧 [x](https://x.example) end")
        XCTAssertEqual(r.plain, "Zu\u{308}rich 🇨🇭 👨‍👩‍👧 x end")
        XCTAssertEqual(r.links.map(\.range), [11..<12])
        XCTAssertEqual(Array(r.plain)[11], "x")
    }

    func testTableIsLeftAloneWithNoLinks() {
        let text = "| a | [b](https://x.example) |\n|---|---|"
        let r = LinkHit.rendered(from: text)
        XCTAssertEqual(r.plain, text)
        XCTAssertTrue(r.links.isEmpty)
    }

    func testEmptyAndMarkupOnlyText() {
        XCTAssertEqual(LinkHit.rendered(from: "").plain, "")
        XCTAssertTrue(LinkHit.rendered(from: "").links.isEmpty)
        XCTAssertEqual(plain("# "), "")
        for text in ["[a](https://x.y", "[", "![", "<", "`", "```", "**", "\\", "> ", "- "] {
            _ = LinkHit.rendered(from: text)
        }
    }

    // MARK: - layout: the point under the finger

    private let font = UIFont.systemFont(ofSize: 17)
    private let width: CGFloat = 280
    private var spacing: CGFloat { font.pointSize * 0.2 }

    /// The centre of the first occurrence of `word` in the *rendered* text.
    private func point(on word: String, in text: String, line: Int = 0) -> CGPoint {
        let plain = LinkHit.rendered(from: text).plain
        guard let range = plain.range(of: word) else {
            XCTFail("\(word) is not in the rendered text: \(plain)")
            return .zero
        }
        let start = plain.distance(from: plain.startIndex, to: range.lowerBound)
        let middle = start + word.count / 2
        guard let rect = TextHitTest.characterRect(ofCharacterAt: middle, in: plain, font: font,
                                                   width: width, lineSpacing: spacing)
        else {
            XCTFail("no rect")
            return .zero
        }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func hit(_ text: String, _ point: CGPoint) -> URL? {
        LinkHit.url(at: point, in: text, font: font, width: width, lineSpacing: spacing)
    }

    func testWordsAfterALongLinkAreNotTheLink() {
        let url = "https://example.com/a/very/long/path/that/keeps/going/and/going/for/a/while"
        let text = "See [Tile museum](\(url)) for details and a few more words so it wraps onto a second line."
        let plain = LinkHit.rendered(from: text).plain

        // the layout has to wrap, or this test proves less than it says
        let first = TextHitTest.characterRect(ofCharacterAt: 0, in: plain, font: font, width: width, lineSpacing: spacing)!
        let last = TextHitTest.characterRect(ofCharacterAt: plain.count - 2, in: plain, font: font, width: width, lineSpacing: spacing)!
        XCTAssertGreaterThan(last.minY, first.maxY - 1, "text should wrap onto a second line")

        XCTAssertEqual(hit(text, point(on: "Tile", in: text)), URL(string: url))
        XCTAssertEqual(hit(text, point(on: "museum", in: text)), URL(string: url))
        XCTAssertNil(hit(text, point(on: "details", in: text)), "words after the link")
        XCTAssertNil(hit(text, point(on: "few more", in: text)))
        XCTAssertNil(hit(text, point(on: "See", in: text)), "words before the link")
        XCTAssertNil(hit(text, point(on: "second line", in: text)))
    }

    func testRightHalfOfTheLastLinkCharacterIsStillTheLink() {
        let text = "Go to [site](https://x.example) now"
        let plain = LinkHit.rendered(from: text).plain
        let lastOfLabel = plain.distance(from: plain.startIndex, to: plain.range(of: "site")!.upperBound) - 1
        let rect = TextHitTest.characterRect(ofCharacterAt: lastOfLabel, in: plain, font: font,
                                             width: width, lineSpacing: spacing)!
        let nearRightEdge = CGPoint(x: rect.maxX - 0.5, y: rect.midY)
        XCTAssertEqual(hit(text, nearRightEdge), URL(string: "https://x.example"))
        let justPast = CGPoint(x: rect.maxX + 0.5, y: rect.midY)
        XCTAssertNil(hit(text, justPast), "the space after the link")
    }

    func testLinkInsideBoldText() {
        let text = "Some **bold [the link](https://x.example/b) text** and then a good number of ordinary words after it to wrap."
        XCTAssertEqual(hit(text, point(on: "the link", in: text)), URL(string: "https://x.example/b"))
        XCTAssertNil(hit(text, point(on: "bold", in: text)))
        XCTAssertNil(hit(text, point(on: "text", in: text)))
        XCTAssertNil(hit(text, point(on: "ordinary", in: text)))
    }

    func testLinkAfterAnEmoji() {
        let text = "Party 🎉🇨🇭 [here](https://x.example/p) and then a good number of ordinary words after it to wrap."
        XCTAssertEqual(hit(text, point(on: "here", in: text)), URL(string: "https://x.example/p"))
        XCTAssertNil(hit(text, point(on: "Party", in: text)))
        XCTAssertNil(hit(text, point(on: "ordinary", in: text)))
    }

    func testTapsOutsideTheTextAreNotLinks() {
        let text = "Only [a link](https://x.example) here"
        XCTAssertNil(hit(text, CGPoint(x: 5, y: 500)), "far below the text")
        XCTAssertNil(hit(text, CGPoint(x: 270, y: 8)), "right of the end of the line")
        XCTAssertNil(hit(text, CGPoint(x: -5, y: 8)))
        XCTAssertNil(hit("", CGPoint(x: 1, y: 1)))
        XCTAssertNil(hit("no links at all", CGPoint(x: 5, y: 5)))
    }

    func testBareURLAndAutolinkAreHitOnTheirVisibleText() {
        let text = "Visit https://x.example/page or <https://y.example/p> today with more words after."
        XCTAssertEqual(hit(text, point(on: "x.example", in: text)), URL(string: "https://x.example/page"))
        XCTAssertEqual(hit(text, point(on: "y.example", in: text)), URL(string: "https://y.example/p"))
        XCTAssertNil(hit(text, point(on: "today", in: text)))
    }
}
