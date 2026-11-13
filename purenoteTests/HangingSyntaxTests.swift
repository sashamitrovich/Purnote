@testable import Purnote
import XCTest
import UIKit
import SwiftUI

/// Hanging syntax, the pure half: what HangingSyntax says about a document.
/// Written before the UIKit side; the UIKit tests are in HangingStylerTests below.
final class HangingSyntaxTests: XCTestCase {

    /// Large content size: SF Mono 13 advances ~8.04 pt, so a 6-cell "- [ ] " is
    /// ~48.2 pt; the text column is at 20 + 36 - 6 = 50 pt. (Round 8.0 here.)
    private let large = HangingSyntax.Metrics(cell: 8.0)
    private let cell: CGFloat = 8.0
    private let column: CGFloat = 50

    private func style(_ text: String, _ metrics: HangingSyntax.Metrics? = nil,
                       _ direction: HangingSyntax.Direction = .ltr) -> HangingSyntax.Result {
        HangingSyntax.style(text, metrics: metrics ?? large, direction: direction)
    }

    private func substring(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    private func runs(_ p: HangingSyntax.Paragraph, _ kind: HangingSyntax.RunKind) -> [NSRange] {
        p.runs.filter { $0.kind == kind }.map(\.range)
    }

    // MARK: - Mode

    func testHangsAtLargeAndFallsBackInlineWhenTheMarkerOutgrowsTheMargin() {
        XCTAssertEqual(HangingSyntax.mode(for: large), .hanging)
        // a 6-cell marker wider than the 50 pt column
        XCTAssertEqual(HangingSyntax.mode(for: HangingSyntax.Metrics(cell: 8.5)), .inline)
    }

    func testAccessibilitySizesAlwaysFallBackInline() {
        var m = large
        m.isAccessibilitySize = true
        XCTAssertEqual(HangingSyntax.mode(for: m), .inline)
        // the real thing, from the real traits: no accessibility size may hang
        for category in [UIContentSizeCategory.accessibilityMedium, .accessibilityLarge,
                         .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge] {
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            XCTAssertEqual(HangingSyntax.mode(for: HangingStyler.metrics(for: traits)), .inline,
                           "\(category.rawValue) hung")
        }
        // and the default size does
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        XCTAssertEqual(HangingSyntax.mode(for: HangingStyler.metrics(for: traits)), .hanging)
    }

    func testInlineModeHasNoIndentOnBodyAndTheGutterAsInset() {
        var m = large
        m.isAccessibilitySize = true
        let r = style("plain\n- item\n# Head", m)
        XCTAssertEqual(r.mode, .inline)
        XCTAssertEqual(r.containerInsetLeft, 20)
        for p in r.paragraphs.prefix(3) { XCTAssertEqual(p.firstLineHeadIndent, 0, "\(p.kind)") }
        XCTAssertEqual(r.paragraphs[0].layout, .plain)
        XCTAssertEqual(r.paragraphs[0].headIndent, 0)
        XCTAssertEqual(r.paragraphs[1].layout, .inline)
        // wrapped lines still line up under the item's text
        XCTAssertEqual(r.paragraphs[1].headIndent, 2 * cell, accuracy: 0.001)
        XCTAssertNotNil(r.paragraphs[1].markerRange, "the marker is still dimmed inline")
    }

    func testHangingModeInsetsTheContainerByTheEdge() {
        XCTAssertEqual(style("x").containerInsetLeft, 6)
        XCTAssertEqual(style("x").mode, .hanging)
    }

    // MARK: - Block kinds

    func testHeadingsOneToThree() {
        let text = "# One\n## Two\n### Three\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs.map(\.kind), [.heading(1), .heading(2), .heading(3), .body])
        for (i, cells) in [2, 3, 4].enumerated() {
            let p = r.paragraphs[i]
            XCTAssertEqual(p.layout, .hung)
            XCTAssertEqual(substring(text, p.markerRange!), String(repeating: "#", count: cells - 1) + " ")
            XCTAssertEqual(p.headIndent, column, accuracy: 0.001)
            XCTAssertEqual(p.firstLineHeadIndent, column - CGFloat(cells) * cell, accuracy: 0.001,
                           "the marker's right edge meets the text column")
        }
    }

    func testHashWithoutSpaceAndSevenHashesAreBody() {
        let r = style("#hashtag\n####### seven\n#\n")
        XCTAssertEqual(r.paragraphs.prefix(3).map(\.kind), [.body, .body, .body])
        XCTAssertTrue(r.paragraphs.prefix(3).allSatisfy { $0.markerRange == nil })
    }

    func testFourToSixHashesAreHeadings() {
        let r = style("#### four\n")
        XCTAssertEqual(r.paragraphs[0].kind, .heading(4))
        XCTAssertEqual(r.paragraphs[0].layout, .hung)
    }

    func testBulletsWithEachMarker() {
        let text = "- a\n* b\n+ c\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs.prefix(3).map(\.kind), [.bullet, .bullet, .bullet])
        for p in r.paragraphs.prefix(3) {
            XCTAssertEqual(p.layout, .hung)
            XCTAssertEqual(p.markerRange?.length, 2)
            XCTAssertEqual(p.firstLineHeadIndent, column - 2 * cell, accuracy: 0.001)
            XCTAssertEqual(p.headIndent, column, accuracy: 0.001)
        }
    }

    func testNumberedOneAndTwelveHangByTheirOwnWidth() {
        let text = "1. one\n12. twelve\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs[0].kind, .numbered)
        XCTAssertEqual(r.paragraphs[1].kind, .numbered)
        XCTAssertEqual(substring(text, r.paragraphs[0].markerRange!), "1. ")
        XCTAssertEqual(substring(text, r.paragraphs[1].markerRange!), "12. ")
        XCTAssertEqual(r.paragraphs[0].firstLineHeadIndent, column - 3 * cell, accuracy: 0.001)
        XCTAssertEqual(r.paragraphs[1].firstLineHeadIndent, column - 4 * cell, accuracy: 0.001)
        // the words start at the same x either way
        XCTAssertEqual(r.paragraphs[0].headIndent, r.paragraphs[1].headIndent)
    }

    func testChecklistOpenAndClosed() {
        let text = "- [ ] todo\n- [x] done\n- [X] Done\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs.prefix(3).map(\.kind),
                       [.checklist(checked: false), .checklist(checked: true), .checklist(checked: true)])
        for p in r.paragraphs.prefix(3) {
            XCTAssertEqual(p.layout, .hung, "the widest marker still hangs at Large")
            XCTAssertEqual(p.markerRange?.length, 6)
            XCTAssertEqual(p.firstLineHeadIndent, column - 6 * cell, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(p.firstLineHeadIndent, 0, "an indent may never go negative")
        }
    }

    func testQuote() {
        let r = style("> said\n")
        XCTAssertEqual(r.paragraphs[0].kind, .quote)
        XCTAssertEqual(r.paragraphs[0].layout, .hung)
        XCTAssertEqual(r.paragraphs[0].markerRange?.length, 2)
    }

    func testParagraphWithoutMarkerSitsInTheTextColumn() {
        let r = style("Just a sentence - with a dash.\n")
        let p = r.paragraphs[0]
        XCTAssertEqual(p.kind, .body)
        XCTAssertEqual(p.layout, .plain)
        XCTAssertNil(p.markerRange)
        XCTAssertEqual(p.firstLineHeadIndent, column, accuracy: 0.001)
        XCTAssertEqual(p.headIndent, column, accuracy: 0.001)
    }

    func testTableLinesAreTableKind() {
        let r = style("| a | b |\n|---|---|\n")
        XCTAssertEqual(r.paragraphs.prefix(2).map(\.kind), [.table, .table])
    }

    // MARK: - Nesting

    func testNestedBulletsKeepTheirMarkerLeftOfTheirOwnTextAndWrapUnderIt() {
        let text = "- a\n  - b\n    - c\n"
        let r = style(text)
        let (a, b, c) = (r.paragraphs[0], r.paragraphs[1], r.paragraphs[2])
        XCTAssertEqual([a.kind, b.kind, c.kind], [.bullet, .bullet, .bullet])
        // the leading spaces are part of the hung prefix (mono, one cell each)
        XCTAssertEqual(substring(text, b.markerRange!), "  - ")
        XCTAssertEqual(substring(text, c.markerRange!), "    - ")
        // every level starts its line at the same x ...
        XCTAssertEqual(a.firstLineHeadIndent, b.firstLineHeadIndent, accuracy: 0.001)
        XCTAssertEqual(a.firstLineHeadIndent, c.firstLineHeadIndent, accuracy: 0.001)
        // ... and the text of a deeper level indents by the spaces it was typed with
        XCTAssertEqual(a.headIndent, column, accuracy: 0.001)
        XCTAssertEqual(b.headIndent, column + 2 * cell, accuracy: 0.001)
        XCTAssertEqual(c.headIndent, column + 4 * cell, accuracy: 0.001)
        // where the text begins on line 1 = where wrapped lines begin (line 1
        // starts at `first` and holds indent + marker cells)
        for p in [a, b, c] {
            let cells = CGFloat(p.markerRange!.length)
            XCTAssertEqual(p.firstLineHeadIndent + cells * cell, p.headIndent, accuracy: 0.001)
        }
    }

    func testTabIndentIsSetInlineBecauseATabHasNoFixedWidth() {
        let r = style("- a\n\t- b\n")
        XCTAssertEqual(r.paragraphs[0].layout, .hung)
        XCTAssertEqual(r.paragraphs[1].layout, .inline)
        XCTAssertGreaterThanOrEqual(r.paragraphs[1].firstLineHeadIndent, 0)
    }

    func testMarkerWiderThanTheMarginFallsBackInlineForThatParagraphOnly() {
        // 11 cells = 88 pt > the 50 pt column
        let r = style("123456789. wide\n- ok\n")
        XCTAssertEqual(r.paragraphs[0].kind, .numbered)
        XCTAssertEqual(r.paragraphs[0].layout, .inline)
        XCTAssertEqual(r.paragraphs[0].firstLineHeadIndent, 14, "aligned to the gutter")
        XCTAssertEqual(r.paragraphs[1].layout, .hung)
    }

    // MARK: - Code

    func testNoHangingInsideAFencedBlock() {
        let text = "```\n- not a list\n# not a heading\n1. nor this\n```\nafter\n- real\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs.map(\.kind),
                       [.codeFence, .code, .code, .code, .codeFence, .body, .bullet, .body])
        XCTAssertEqual(r.fenceLines, 2)
        for p in r.paragraphs[0...4] {
            XCTAssertNil(p.markerRange, "\(p.kind) has a marker")
            XCTAssertEqual(p.layout, .plain)
            XCTAssertTrue(p.runs.isEmpty, "no inline styling in code")
        }
        XCTAssertEqual(r.paragraphs[6].layout, .hung)
    }

    func testAnUnclosedFenceRunsToTheEnd() {
        let r = style("```\n- a\n- b")
        XCTAssertEqual(r.paragraphs.map(\.kind), [.codeFence, .code, .code])
    }

    func testTildeFences() {
        let r = style("~~~\n# x\n~~~\n# y")
        XCTAssertEqual(r.paragraphs.map(\.kind), [.codeFence, .code, .codeFence, .heading(1)])
    }

    // MARK: - Line endings, empty, edges

    func testCRLF() {
        let text = "# a\r\n- b\r\ntext\r\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs.map(\.range), [NSRange(location: 0, length: 5),
                                                    NSRange(location: 5, length: 5),
                                                    NSRange(location: 10, length: 6),
                                                    NSRange(location: 16, length: 0)])
        XCTAssertEqual(r.paragraphs.map(\.kind), [.heading(1), .bullet, .body, .body])
        XCTAssertEqual(r.paragraphs[0].markerRange, NSRange(location: 0, length: 2))
        XCTAssertEqual(r.paragraphs[1].markerRange, NSRange(location: 5, length: 2))
    }

    func testEmptyDocumentHasOneBodyParagraphToType() {
        let r = style("")
        XCTAssertEqual(r.paragraphs.count, 1)
        XCTAssertEqual(r.paragraphs[0].range, NSRange(location: 0, length: 0))
        XCTAssertEqual(r.paragraphs[0].kind, .body)
        XCTAssertEqual(r.paragraphs[0].headIndent, column)
        XCTAssertEqual(r.paragraph(at: 0)?.kind, .body)
    }

    func testTextEndingInANewlineHasAnEmptyLastParagraph() {
        let r = style("# T\n")
        XCTAssertEqual(r.paragraphs.count, 2)
        XCTAssertEqual(r.paragraphs[1].range, NSRange(location: 4, length: 0))
        XCTAssertEqual(r.paragraphs[1].kind, .body, "the line after a heading is body")
        XCTAssertEqual(r.paragraph(at: 4)?.kind, .body)
        XCTAssertEqual(r.paragraph(at: 3)?.kind, .heading(1), "the caret at the end of a line is in that line")
    }

    func testAnEmptyListItemStillHasItsMarkerAndTheCaretAfterItIsInThatParagraph() {
        let r = style("- ")
        XCTAssertEqual(r.paragraphs[0].kind, .bullet)
        XCTAssertEqual(r.paragraphs[0].markerRange, NSRange(location: 0, length: 2))
        XCTAssertEqual(r.paragraph(at: 2)?.kind, .bullet)
    }

    func testParagraphsTileTheWholeText() {
        for text in sampleDocuments {
            let ns = text as NSString
            let r = style(text)
            var cursor = 0
            for p in r.paragraphs {
                XCTAssertEqual(p.range.location, cursor, "gap before \(p.kind) in \(text.debugDescription)")
                XCTAssertLessThanOrEqual(NSMaxRange(p.range), ns.length)
                for run in p.runs {
                    XCTAssertGreaterThanOrEqual(run.range.location, p.range.location)
                    XCTAssertLessThanOrEqual(NSMaxRange(run.range), NSMaxRange(p.range),
                                             "\(run.kind) escapes its paragraph in \(text.debugDescription)")
                }
                cursor = NSMaxRange(p.range)
            }
            XCTAssertEqual(cursor, ns.length)
        }
    }

    // MARK: - Wide characters

    func testRangesAreUTF16() {
        // 日本語 = 3 units, 😀 = 2 units
        let text = "- 日本語\n- 😀 **bold** x\n"
        let r = style(text)
        XCTAssertEqual(r.paragraphs[0].range, NSRange(location: 0, length: 6))
        let second = r.paragraphs[1]
        XCTAssertEqual(second.range.location, 6)
        XCTAssertEqual(second.markerRange, NSRange(location: 6, length: 2))
        let strong = runs(second, .strong)
        XCTAssertEqual(strong.map { substring(text, $0) }, ["**bold**"])
        XCTAssertEqual(strong[0].location, 6 + 2 + 2 + 1, "after '- ', the emoji (2 units) and a space")
    }

    func testCJKAndEmojiBodyIsPlainAndNotRTL() {
        let r = style("日本語のメモ 😀\n")
        XCTAssertEqual(r.paragraphs[0].kind, .body)
        XCTAssertFalse(r.paragraphs[0].isRTL)
    }

    // MARK: - Direction

    func testRTLParagraphsAreNeverHung() {
        let text = "- שלום עולם\n- hello\n1. مرحبا\n"
        let r = style(text)
        XCTAssertTrue(r.paragraphs[0].isRTL)
        XCTAssertEqual(r.paragraphs[0].layout, .inline)
        XCTAssertEqual(r.paragraphs[0].firstLineHeadIndent, 0)
        XCTAssertEqual(r.paragraphs[0].headIndent, 0)
        XCTAssertNotNil(r.paragraphs[0].markerRange, "the marker is still dimmed, in the line")
        // a left-to-right paragraph in the same note still hangs
        XCTAssertFalse(r.paragraphs[1].isRTL)
        XCTAssertEqual(r.paragraphs[1].layout, .hung)
        XCTAssertTrue(r.paragraphs[2].isRTL)
        XCTAssertEqual(r.paragraphs[2].firstLineHeadIndent, 0)
    }

    func testRTLPlainParagraphHasNoIndents() {
        let r = style("שלום\n")
        XCTAssertTrue(r.paragraphs[0].isRTL)
        XCTAssertEqual(r.paragraphs[0].firstLineHeadIndent, 0)
        XCTAssertEqual(r.paragraphs[0].headIndent, 0)
    }

    func testRTLLayoutDirectionDecidesWhenThereIsNoStrongCharacter() {
        XCTAssertFalse(style("- 123\n", nil, .ltr).paragraphs[0].isRTL)
        XCTAssertTrue(style("- 123\n", nil, .rtl).paragraphs[0].isRTL)
        XCTAssertEqual(style("- 123\n", nil, .rtl).paragraphs[0].layout, .inline)
        // a strong LTR letter wins over the layout direction
        XCTAssertFalse(style("- abc\n", nil, .rtl).paragraphs[0].isRTL)
    }

    // MARK: - Inline delimiters

    func testInlineDelimitersAreDimmedAndSpansStyled() {
        let text = "a **bold** and _it_ and `c` and ~~s~~ and *star*"
        let p = style(text).paragraphs[0]
        XCTAssertEqual(runs(p, .strong).map { substring(text, $0) }, ["**bold**"])
        XCTAssertEqual(Set(runs(p, .emphasis).map { substring(text, $0) }), ["_it_", "*star*"])
        XCTAssertEqual(runs(p, .code).map { substring(text, $0) }, ["`c`"])
        XCTAssertEqual(runs(p, .strike).map { substring(text, $0) }, ["~~s~~"])
        let delimiters = runs(p, .delimiter).map { substring(text, $0) }
        XCTAssertEqual(delimiters.filter { $0 == "**" }.count, 2)
        XCTAssertEqual(delimiters.filter { $0 == "_" }.count, 2)
        XCTAssertEqual(delimiters.filter { $0 == "`" }.count, 2)
        XCTAssertEqual(delimiters.filter { $0 == "~~" }.count, 2)
    }

    func testNothingInsideACodeSpanIsStyled() {
        let text = "`**x** _y_`"
        let p = style(text).paragraphs[0]
        XCTAssertEqual(runs(p, .code).map { substring(text, $0) }, [text])
        XCTAssertTrue(runs(p, .strong).isEmpty)
        XCTAssertTrue(runs(p, .emphasis).isEmpty)
    }

    func testSnakeCaseAndArithmeticAreNotEmphasis() {
        for text in ["snake_case_name", "2 * 3 * 4", "a_b and c_d", "a * b"] {
            let p = style(text).paragraphs[0]
            XCTAssertTrue(runs(p, .emphasis).isEmpty, text)
        }
    }

    func testInlineSpansInsideAListItemAreFoundAfterTheMarker() {
        let text = "- **b** x\n"
        let p = style(text).paragraphs[0]
        XCTAssertEqual(runs(p, .strong).map { substring(text, $0) }, ["**b**"])
        XCTAssertEqual(p.markerRange, NSRange(location: 0, length: 2))
    }

    func testAListStarIsTheMarkerNotEmphasis() {
        let text = "* one *two* three\n"
        let p = style(text).paragraphs[0]
        XCTAssertEqual(p.kind, .bullet)
        XCTAssertEqual(runs(p, .emphasis).map { substring(text, $0) }, ["*two*"])
    }

    // MARK: - Speed

    func testStylingALongNoteIsFast() {
        let line = "- item with **bold** and a `code` span and some more words to wrap around\n"
        let text = String(repeating: line, count: 3000)    // ~220 KB
        measure { _ = style(text) }
    }

    // MARK: - Fixtures

    private var sampleDocuments: [String] {
        ["", "\n", "plain", "# T", "# T\n", "- a\n  - b\n", "1. x\n12. y\r\n", "```\n- x\n",
         "- [ ] a\n- [x] b\n> q\n", "日本語 😀\n- 😀 **b**\n", "- שלום\n", "a\r\n\r\nb", "\n\n\n",
         "| a | b |\n", "**x** `y` _z_ ~~w~~"]
    }
}

// MARK: - The UIKit half, against a real UITextView

/// Hanging syntax applied to a real text view in a window: the four S4 checks
/// that need a live view (text unchanged, no leaking attributes, one undo step,
/// wrapped lines aligned) plus marked text, Dynamic Type and RTL.
@MainActor
final class HangingStylerTests: XCTestCase {

    /// A text view built the way the app builds it, in a window so it lays out,
    /// becomes first responder and has an undo manager.
    private final class Harness {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let view: HangingTextView
        let coordinator: MarkdownTextView.Coordinator
        /// Every value the view wrote to the `text` binding.
        var writes: [String] = []
        var text: String

        init(_ text: String, category: UIContentSizeCategory? = nil) {
            self.text = text
            var box: Harness?
            let parent = MarkdownTextView(
                text: Binding(get: { box?.text ?? "" }, set: { box?.text = $0; box?.writes.append($0) }),
                selection: .constant(0..<0), caretRequest: .constant(nil), initialCaret: nil)
            coordinator = parent.makeCoordinator()
            view = MarkdownTextView.makeTextView(text: text, initialCaret: 0, coordinator: coordinator)
            box = self
            let controller = UIViewController()
            window.rootViewController = controller
            controller.view.addSubview(view)
            view.frame = window.bounds
            if let category { view.traitOverrides.preferredContentSizeCategory = category }
            window.makeKeyAndVisible()
            _ = view.becomeFirstResponder()
            coordinator.restyle(view, dirty: nil)
            view.layoutIfNeeded()
        }

        var storage: NSTextStorage { view.textStorage }

        func attrs(at i: Int) -> [NSAttributedString.Key: Any] {
            storage.attributes(at: i, effectiveRange: nil)
        }
        func font(at i: Int) -> UIFont { attrs(at: i)[.font] as! UIFont }
        func color(at i: Int) -> UIColor? { attrs(at: i)[.foregroundColor] as? UIColor }
        func paragraph(at i: Int) -> NSParagraphStyle { attrs(at: i)[.paragraphStyle] as! NSParagraphStyle }

        /// One keystroke, the way UIKit delivers it: the delegate is asked
        /// first and may take over (Return in a list), otherwise the character
        /// is inserted. (`insertText` alone does not consult the delegate when
        /// the view is not in an active scene, as in a unit-test host.)
        func type(_ string: String) {
            for ch in string {
                let s = String(ch)
                let range = view.selectedRange
                if coordinator.textView(view, shouldChangeTextIn: range, replacementText: s) {
                    view.insertText(s)
                }
            }
        }

        func caret(at offset: Int) {
            view.selectedRange = NSRange(location: offset, length: 0)
        }
        func spin() { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    }

    private func isMono(_ f: UIFont) -> Bool { f.fontName.localizedCaseInsensitiveContains("Mono") }
    private func isSerif(_ f: UIFont) -> Bool { f.fontName.contains("NewYork") }

    private let documents = [
        "", "# Title\nbody\n", "- one\n- two\n  - nested\n", "1. a\n12. b\n", "- [ ] t\n- [x] d\n",
        "> quote\n", "```\n- code\n```\n", "日本語 😀 **太字**\n- 😀 _x_ `c`\n", "a\r\nb\r\n- c\r\n",
        "- שלום\nhello\n", "plain **bold** _it_ ~~s~~\n",
    ]

    // MARK: Rule 1: the stored text is the file's text

    func testStylingNeverChangesTheText() {
        for doc in documents {
            for category in [UIContentSizeCategory.large, .extraSmall, .accessibilityExtraExtraExtraLarge] {
                let h = Harness(doc, category: category)
                XCTAssertEqual(h.storage.string, doc, "storage changed for \(doc.debugDescription) at \(category.rawValue)")
                XCTAssertEqual(h.view.text, doc)
                h.coordinator.styler.needsFullRestyle = true
                h.coordinator.restyle(h.view, dirty: nil)
                h.coordinator.restyle(h.view, dirty: NSRange(location: 0, length: min(2, doc.utf16.count)))
                XCTAssertEqual(h.storage.string, doc)
                XCTAssertTrue(h.writes.isEmpty, "styling wrote to the text binding: \(h.writes)")
            }
        }
    }

    func testTheSavedStringCarriesNoAttributesAndStylingNeverWritesTheBinding() {
        let doc = "# Title\n- **bold** item\n"
        let h = Harness(doc)
        // what autosave and the file see is the view's `text`, a plain String
        XCTAssertEqual(h.view.text, doc)
        XCTAssertEqual(h.text, doc)
        XCTAssertTrue(h.writes.isEmpty)
        // typing after styling saves exactly the typed characters
        h.caret(at: h.view.text.utf16.count)
        h.type("x")
        XCTAssertEqual(h.view.text, doc + "x")
        XCTAssertEqual(h.text, doc + "x")
        XCTAssertEqual(h.writes, [doc + "x"], "one write per keystroke and none from styling")
    }

    // MARK: What styling looks like

    func testMarkerIsDimMonoAndTheWordsAreSerifInk() {
        let h = Harness("# Title\n- item\n")
        // "# " marker
        XCTAssertTrue(isMono(h.font(at: 0)))
        XCTAssertEqual(h.font(at: 0).pointSize, PurnoteType.mono(compatibleWith: h.view.traitCollection).pointSize)
        XCTAssertEqual(h.color(at: 0), PurnoteColor.ink3)
        // the heading word: New York at the type-scale size
        XCTAssertTrue(isSerif(h.font(at: 2)))
        XCTAssertEqual(h.font(at: 2).pointSize, PurnoteType.noteTitle(compatibleWith: h.view.traitCollection).pointSize)
        XCTAssertEqual(h.color(at: 2), PurnoteColor.ink)
        // "- item"
        let item = ("# Title\n" as NSString).length
        XCTAssertTrue(isMono(h.font(at: item)))
        XCTAssertTrue(isSerif(h.font(at: item + 2)))
        XCTAssertEqual(h.font(at: item + 2).pointSize,
                       PurnoteType.body(compatibleWith: h.view.traitCollection).pointSize)
    }

    func testInlineDelimitersAreDimInTheEditor() {
        let h = Harness("a **bold** b\n")
        XCTAssertEqual(h.color(at: 2), PurnoteColor.ink3, "the ** is dim")
        XCTAssertEqual(h.color(at: 4), PurnoteColor.ink, "the word is not")
        XCTAssertTrue(h.font(at: 4).fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testTextContainerInsetFollowsTheMode() {
        XCTAssertEqual(Harness("x").view.textContainerInset.left, 6)
        XCTAssertEqual(Harness("x", category: .accessibilityLarge).view.textContainerInset.left, 20)
    }

    // MARK: Rule 2: marker attributes do not leak into typed text

    func testTypingAfterAHungMarkerIsBodyText() {
        let h = Harness("- ")
        h.caret(at: 2)
        h.type("x")
        XCTAssertEqual(h.view.text, "- x")
        XCTAssertFalse(isMono(h.font(at: 2)), "typed text took the marker's mono face")
        XCTAssertEqual(h.color(at: 2), PurnoteColor.ink, "typed text took the marker's dim colour")
        XCTAssertTrue(isSerif(h.font(at: 2)))
        // and the marker itself is still a marker
        XCTAssertTrue(isMono(h.font(at: 0)))
    }

    func testTypingAfterAHeadingMarkerIsHeadingTextNotMarkerText() {
        let h = Harness("# ")
        h.caret(at: 2)
        h.type("T")
        XCTAssertFalse(isMono(h.font(at: 2)))
        XCTAssertEqual(h.font(at: 2).pointSize, PurnoteType.noteTitle(compatibleWith: h.view.traitCollection).pointSize)
        XCTAssertEqual(h.color(at: 2), PurnoteColor.ink)
    }

    func testTypingAfterAChecklistMarkerIsBodyText() {
        let h = Harness("- [ ] ")
        h.caret(at: 6)
        h.type("milk")
        XCTAssertFalse(isMono(h.font(at: 6)))
        XCTAssertEqual(h.color(at: 6), PurnoteColor.ink)
    }

    func testTypingAfterReturnOnAListItemIsBodyText() {
        let h = Harness("- milk")
        h.caret(at: 6)
        h.type("\n")          // ListContinuation adds "- "
        XCTAssertEqual(h.view.text, "- milk\n- ")
        h.type("b")
        XCTAssertEqual(h.view.text, "- milk\n- b")
        let b = 9
        XCTAssertFalse(isMono(h.font(at: b)), "text after the continued marker is mono")
        XCTAssertEqual(h.color(at: b), PurnoteColor.ink)
        XCTAssertTrue(isSerif(h.font(at: b)))
        // the new line's marker is styled as a marker (by the restyle)
        XCTAssertTrue(isMono(h.font(at: 7)))
        XCTAssertEqual(h.color(at: 7), PurnoteColor.ink3)
        // and the new item hangs like the first
        XCTAssertEqual(h.paragraph(at: 7).firstLineHeadIndent, h.paragraph(at: 0).firstLineHeadIndent)
        XCTAssertEqual(h.paragraph(at: 7).headIndent, h.paragraph(at: 0).headIndent)
    }

    func testTypingAtTheEndOfAHeadingStaysHeadingTextAndTheLineAfterIsBody() {
        let h = Harness("# Title")
        h.caret(at: 7)
        h.type("s")
        XCTAssertFalse(isMono(h.font(at: 7)), "typing at the end of a heading is not marker-styled")
        XCTAssertEqual(h.font(at: 7).pointSize, PurnoteType.noteTitle(compatibleWith: h.view.traitCollection).pointSize)
        h.type("\n")
        h.type("b")
        XCTAssertEqual(h.view.text, "# Titles\nb")
        let b = 9
        XCTAssertEqual(h.font(at: b).pointSize, PurnoteType.body(compatibleWith: h.view.traitCollection).pointSize,
                       "the line after a heading is body-sized")
        XCTAssertFalse(isMono(h.font(at: b)))
        XCTAssertEqual(h.paragraph(at: b).firstLineHeadIndent, HangingSyntax.Metrics(cell: 0).columnStart)
    }

    func testTypingAttributesAtEachPositionAreTheParagraphsBodyStyle() {
        let h = Harness("# H\n- item\nplain\n")
        let traits = h.view.traitCollection
        let body = PurnoteType.body(compatibleWith: traits)
        // after "- " (6 = "# H\n" is 4, marker at 4..<6), mid-word, end of text (the empty last line)
        for (location, expected) in [(6, body), (9, body), (15, body), (h.view.text.utf16.count, body)] {
            h.caret(at: location)
            let font = h.view.typingAttributes[.font] as? UIFont
            XCTAssertEqual(font?.fontName, expected.fontName, "caret \(location)")
            XCTAssertEqual(font?.pointSize, expected.pointSize, "caret \(location)")
            XCTAssertEqual(h.view.typingAttributes[.foregroundColor] as? UIColor, PurnoteColor.ink, "caret \(location)")
        }
    }

    // MARK: Rule 3: one undo step per edit

    func testABarEditIsOneUndoStepAndKeepsTheUndoStack() throws {
        let h = Harness("abc")
        let undo = try XCTUnwrap(h.view.undoManager)
        undo.groupsByEvent = false
        h.caret(at: 3)
        undo.beginUndoGrouping()
        h.type("d")                       // typed
        undo.endUndoGrouping()
        XCTAssertEqual(h.view.text, "abcd")

        // the formatting bar's Bold: the binding changes, the coordinator syncs
        undo.beginUndoGrouping()
        h.coordinator.syncFromBinding(h.view, to: "abcd****")
        undo.endUndoGrouping()
        XCTAssertEqual(h.view.text, "abcd****")
        XCTAssertEqual(h.storage.string, "abcd****")

        undo.undo()
        XCTAssertEqual(h.view.text, "abcd", "one undo must take back exactly the bar's edit")
        undo.undo()
        XCTAssertEqual(h.view.text, "abc", "the typing before it must still be on the undo stack")
        undo.redo()
        undo.redo()
        XCTAssertEqual(h.view.text, "abcd****")
    }

    /// The Heading button: a pure insertion at the start of the line, after
    /// typing, with UIKit's own event-based undo grouping left on.
    func testAnInsertionAtTheStartOfTheLineAfterTypingIsItsOwnUndoStep() throws {
        let h = Harness("")
        let undo = try XCTUnwrap(h.view.undoManager)
        h.type("title")
        h.spin()
        h.coordinator.syncFromBinding(h.view, to: "# title")
        h.spin()
        XCTAssertEqual(h.view.text, "# title")
        undo.undo()
        XCTAssertEqual(h.view.text, "title", "undo after a Heading insertion")
    }

    func testReapplyingStylesDoesNotAddOrClearUndo() throws {
        let h = Harness("- a")
        let undo = try XCTUnwrap(h.view.undoManager)
        undo.groupsByEvent = false
        h.caret(at: 3)
        undo.beginUndoGrouping()
        h.type("b")
        undo.endUndoGrouping()
        let countBefore = undo.canUndo
        h.coordinator.styler.needsFullRestyle = true
        h.coordinator.restyle(h.view, dirty: nil)
        h.coordinator.restyle(h.view, dirty: NSRange(location: 0, length: 1))
        XCTAssertEqual(undo.canUndo, countBefore)
        undo.undo()
        XCTAssertEqual(h.view.text, "- a", "styling in between must not have eaten or merged the typing's undo step")
        XCTAssertFalse(undo.canUndo, "styling registered an undo action of its own")
    }

    func testTheBindingDiffReplacesOnlyTheChangedSpan() {
        let h = Harness("hello world")
        // bold on "world": a wrap
        let range = MarkdownTextView.replaceMinimally(in: h.view, with: "hello **world**")
        XCTAssertEqual(h.view.text, "hello **world**")
        XCTAssertLessThanOrEqual(range.length, "**world**".utf16.count)
        // an emoji must not be split by the diff
        let h2 = Harness("a😀b")
        MarkdownTextView.replaceMinimally(in: h2.view, with: "a😀😀b")
        XCTAssertEqual(h2.view.text, "a😀😀b")
        let h3 = Harness("x😀")
        MarkdownTextView.replaceMinimally(in: h3.view, with: "x😁")
        XCTAssertEqual(h3.view.text, "x😁")
        let h4 = Harness("")
        MarkdownTextView.replaceMinimally(in: h4.view, with: "new")
        XCTAssertEqual(h4.view.text, "new")
        MarkdownTextView.replaceMinimally(in: h4.view, with: "")
        XCTAssertEqual(h4.view.text, "")
    }

    // MARK: Rule 4: wrapping, nesting, headings, sizes, composition, RTL

    /// x (in text view coordinates) of the glyph for UTF-16 offset `i`.
    private func x(_ h: Harness, _ i: Int) -> CGFloat {
        let lm = h.view.layoutManager
        let glyph = lm.glyphIndexForCharacter(at: i)
        let fragment = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        return h.view.textContainerInset.left + fragment.minX + lm.location(forGlyphAt: glyph).x
    }

    private func line(_ h: Harness, _ i: Int) -> CGFloat {
        let lm = h.view.layoutManager
        return lm.lineFragmentRect(forGlyphAt: lm.glyphIndexForCharacter(at: i), effectiveRange: nil).minY
    }

    func testAWrappedListItemAlignsItsWordsAndHangsItsMarker() {
        let words = String(repeating: "wrapping words ", count: 12)
        let doc = "- " + words + "\n"
        let h = Harness(doc)
        let first = 2                      // first word, line 1
        // find a character that is on line 2
        var second = first
        while second < doc.utf16.count && line(h, second) == line(h, first) { second += 1 }
        XCTAssertLessThan(second, doc.utf16.count, "the item did not wrap")
        // the first word starts at screen x = 20 + 36 = 56 ...
        XCTAssertEqual(x(h, first), 56, accuracy: 0.6, "words sit at the reading view's text column")
        // ... and so does the start of the next line
        var start2 = second
        while start2 > first && line(h, start2 - 1) == line(h, second) { start2 -= 1 }
        XCTAssertEqual(x(h, start2), 56, accuracy: 0.6, "the wrapped line is not under the text")
        // the marker hangs left of the column, inside the screen
        XCTAssertLessThan(x(h, 0), 56 - 10)
        XCTAssertGreaterThanOrEqual(x(h, 0), 6 - 0.6)
    }

    func testNestedItemsWrapUnderTheirOwnText() {
        let words = String(repeating: "nested words ", count: 14)
        let doc = "- parent\n    - " + words + "\n"
        let h = Harness(doc)
        let childStart = ("- parent\n    - " as NSString).length
        let cell = HangingStyler.metrics(for: h.view.traitCollection).cell
        let expected = 56 + 4 * cell
        XCTAssertEqual(x(h, childStart), expected, accuracy: 0.6, "nested text indents with its spaces")
        var second = childStart
        while second < doc.utf16.count && line(h, second) == line(h, childStart) { second += 1 }
        XCTAssertLessThan(second, doc.utf16.count, "the nested item did not wrap")
        var start2 = second
        while start2 > childStart && line(h, start2 - 1) == line(h, second) { start2 -= 1 }
        XCTAssertEqual(x(h, start2), expected, accuracy: 0.6)
    }

    func testALongHeadingWrapsInTheTextColumn() {
        let doc = "# " + String(repeating: "Long heading ", count: 8) + "\n"
        let h = Harness(doc)
        XCTAssertEqual(x(h, 2), 56, accuracy: 0.6)
        var second = 2
        while second < doc.utf16.count && line(h, second) == line(h, 2) { second += 1 }
        XCTAssertLessThan(second, doc.utf16.count, "the heading did not wrap")
        var start2 = second
        while start2 > 2 && line(h, start2 - 1) == line(h, second) { start2 -= 1 }
        XCTAssertEqual(x(h, start2), 56, accuracy: 0.6)
    }

    func testBodyTextSitsAtTheSameColumnAsListText() {
        let h = Harness("plain\n- item\n# Head\n")
        XCTAssertEqual(x(h, 0), 56, accuracy: 0.6)
        XCTAssertEqual(x(h, 8), 56, accuracy: 0.6)      // "item"
        XCTAssertEqual(x(h, 15), 56, accuracy: 0.6)     // "Head"
    }

    func testAccessibilitySizeSetsTheSyntaxInlineAtTheGutter() {
        let doc = "# Head\n- item that is long enough to wrap onto a second line at this size ok\nplain\n"
        let h = Harness(doc, category: .accessibilityExtraExtraLarge)
        XCTAssertEqual(h.view.textContainerInset.left, 20)
        XCTAssertEqual(h.paragraph(at: 0).firstLineHeadIndent, 0)
        let item = 7
        XCTAssertEqual(h.paragraph(at: item).firstLineHeadIndent, 0, "inline: the marker starts the line")
        XCTAssertTrue(isMono(h.font(at: item)), "the inline marker is still dim mono")
        XCTAssertEqual(h.color(at: item), PurnoteColor.ink3)
        XCTAssertEqual(x(h, item), 20, accuracy: 0.6)
        // body text starts at the gutter too
        let plain = (doc as NSString).range(of: "plain").location
        XCTAssertEqual(x(h, plain), 20, accuracy: 0.6)
        // fonts really are bigger than at Large
        XCTAssertGreaterThan(h.font(at: plain).pointSize, PurnoteType.bodyPoints * 1.5)
    }

    func testChangingTheTextSizeRestylesInPlace() {
        let h = Harness("# T\n- item\n")
        XCTAssertEqual(h.view.textContainerInset.left, 6)
        h.view.traitOverrides.preferredContentSizeCategory = .accessibilityExtraLarge
        h.spin(); h.view.layoutIfNeeded(); h.spin()
        XCTAssertEqual(h.view.textContainerInset.left, 20, "the trait change did not reach the styler")
        XCTAssertEqual(h.paragraph(at: 4).firstLineHeadIndent, 0)
        XCTAssertEqual(h.view.text, "# T\n- item\n")
        h.view.traitOverrides.preferredContentSizeCategory = .large
        h.spin(); h.view.layoutIfNeeded(); h.spin()
        XCTAssertEqual(h.view.textContainerInset.left, 6)
    }

    func testMarkedTextIsNotRestyled() {
        let h = Harness("- a\nb")
        h.caret(at: 5)
        h.view.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertNotNil(h.view.markedTextRange)
        h.coordinator.restyle(h.view, dirty: nil)
        h.coordinator.textViewDidChange(h.view)
        XCTAssertNotNil(h.view.markedTextRange, "styling cancelled the composition")
        XCTAssertTrue(h.coordinator.styler.needsFullRestyle, "the restyle was not deferred")
        // once committed the whole note is restyled
        h.view.unmarkText()
        h.coordinator.textViewDidChange(h.view)
        XCTAssertFalse(h.coordinator.styler.needsFullRestyle)
        XCTAssertEqual(h.view.text, "- a\nbに")
    }

    func testRTLParagraphsGetNoHangingIndentsButLeftToRightOnesStillDo() {
        let h = Harness("- שלום עולם\n- hello\n")
        XCTAssertEqual(h.paragraph(at: 0).firstLineHeadIndent, 0)
        XCTAssertEqual(h.paragraph(at: 0).headIndent, 0)
        XCTAssertTrue(isMono(h.font(at: 0)), "the marker is dim mono inline")
        let second = ("- שלום עולם\n" as NSString).length
        XCTAssertGreaterThan(h.paragraph(at: second).firstLineHeadIndent, 0)
        XCTAssertEqual(h.paragraph(at: second).headIndent,
                       HangingSyntax.Metrics(cell: 0).columnStart)
    }

    func testRestylingTheEditedParagraphLeavesTheOthersAlone() {
        let h = Harness("# a\n- b\nc\n")
        // hand-mark paragraph 3 so we can see whether it was touched
        let marker = NSRange(location: 8, length: 1)
        h.storage.addAttribute(.foregroundColor, value: UIColor.red, range: marker)
        h.coordinator.restyle(h.view, dirty: NSRange(location: 0, length: 1))
        XCTAssertEqual(h.color(at: 8), .red, "an edit in the first paragraph restyled the last one")
        h.coordinator.restyle(h.view, dirty: nil)
        XCTAssertEqual(h.color(at: 8), PurnoteColor.ink, "a full restyle repairs it")
    }

    func testOpeningAFenceRestylesTheFollowingLines() {
        // typing a fence line above a list turns the list into code: the
        // paragraphs after the edit change kind, so they are restyled too
        let h = Harness("- b\n")
        XCTAssertLessThan(h.paragraph(at: 0).firstLineHeadIndent, HangingSyntax.Metrics(cell: 0).columnStart)
        h.caret(at: 0)
        h.type("```\n")
        XCTAssertEqual(h.view.text, "```\n- b\n")
        let column = HangingSyntax.Metrics(cell: 0).columnStart
        XCTAssertEqual(h.paragraph(at: 4).firstLineHeadIndent, column, "the list line is code now: not hung")
        XCTAssertEqual(h.paragraph(at: 4).headIndent, column)
    }
}
