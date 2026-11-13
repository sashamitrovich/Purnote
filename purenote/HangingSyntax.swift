//
//  HangingSyntax.swift
//  purenote
//
//  The pure half of the editor's "hanging syntax" (direction B, screen 13).
//
//  The Markdown markers at the start of a paragraph (`#`, `- `, `1. `, `- [ ] `,
//  `> `) are drawn in the margin to the left of the text column, so the words sit
//  where they sit in the reading view. Nothing in the buffer changes: this file
//  only *describes* the styling -- which paragraph is what, where its marker is,
//  what its indents are, which inline delimiters to dim -- and the UIKit side
//  (HangingStyler) turns the description into attributes. No text is ever
//  inserted, removed or replaced here, and nothing here touches a view, so it can
//  be tested with plain strings.
//
//  Layout, in points, measured from the text container's left edge:
//
//    hanging mode   container inset = `edge` (6), text column at gutter + margin
//                   - edge (20 + 36 - 6 = 50 at Large). A marker of n mono cells
//                   starts at columnStart - n * cell, so its right edge meets the
//                   column. Needs columnStart >= the widest marker, otherwise the
//                   indent would go negative; `layout(for:)` checks that.
//    inline mode    container inset = gutter (20), every indent 0, markers stay in
//                   the line, dimmed. Used at accessibility sizes (the marker is
//                   wider than the margin there) and as the fallback.
//
//  Nested lists: the leading spaces are part of the hung prefix and are set in the
//  same mono face, so a nested item's marker stays `indent` cells to the right of
//  its parent's and its text indents by the same amount (headIndent = columnStart
//  + indent cells). Wrapped lines therefore line up under the text at every level.
//  A tab in the indent has no fixed width, so such a paragraph is set inline.
//

import Foundation
import CoreGraphics

enum HangingSyntax {

    // MARK: - Inputs

    enum Direction: Equatable { case ltr, rtl }

    /// Widths in points, already scaled for the current Dynamic Type size.
    struct Metrics: Equatable {
        /// Space between the screen edge and the margin column (fixed).
        var gutter: CGFloat = 20
        /// The margin column the markers hang in (scaled with the body style).
        var margin: CGFloat = 36
        /// The smallest distance a hung marker may come to the screen edge.
        var edge: CGFloat = 6
        /// The advance of one cell of the marker font (SF Mono, scaled).
        var cell: CGFloat
        /// True at the accessibility content sizes.
        var isAccessibilitySize: Bool = false

        /// Where the text column starts, from the container's left edge, in hanging mode.
        var columnStart: CGFloat { gutter + margin - edge }

        /// "- [ ] ", the widest marker people write most.
        static let referenceMarkerCells = 6
    }

    enum Mode: Equatable { case hanging, inline }

    /// Whether this size has room to hang markers at all. A pure function of the
    /// metrics, so the accessibility fallback is a decision a test can read.
    static func mode(for metrics: Metrics) -> Mode {
        guard !metrics.isAccessibilitySize else { return .inline }
        let widest = CGFloat(Metrics.referenceMarkerCells) * metrics.cell
        return widest <= metrics.columnStart ? .hanging : .inline
    }

    /// Left inset the text container should have for a mode.
    static func containerInsetLeft(_ mode: Mode, metrics: Metrics) -> CGFloat {
        mode == .hanging ? metrics.edge : metrics.gutter
    }

    // MARK: - Outputs

    enum Kind: Equatable {
        case body
        case heading(Int)            // 1...6; 4-6 are set at the h3 size
        case bullet
        case numbered
        case checklist(checked: Bool)
        case quote
        case code                    // inside a fenced block
        case codeFence               // the ``` line itself
        case table                   // a line of a pipe table
    }

    enum Layout: Equatable {
        /// The paragraph has no marker.
        case plain
        /// The marker hangs in the margin.
        case hung
        /// The marker stays in the line, dimmed.
        case inline
    }

    enum RunKind: Equatable {
        /// Indent plus marker at the start of a paragraph: mono, ink3.
        case marker
        case strong, emphasis, strike, code
        /// A `**`, `_`, backtick or `~~` delimiter: ink3.
        case delimiter
    }

    struct Run: Equatable {
        var range: NSRange
        var kind: RunKind
    }

    struct Paragraph: Equatable {
        /// UTF-16 range including the line terminator.
        var range: NSRange
        var kind: Kind
        var layout: Layout
        var isRTL: Bool
        var firstLineHeadIndent: CGFloat
        var headIndent: CGFloat
        /// Indent plus marker, nil when there is none.
        var markerRange: NSRange? { runs.first { $0.kind == .marker }?.range }
        var runs: [Run]
    }

    struct Result: Equatable {
        var mode: Mode
        var containerInsetLeft: CGFloat
        var paragraphs: [Paragraph]
        /// Number of ``` / ~~~ lines. When an edit changes it, every paragraph
        /// after the edit may have changed kind, so the caller restyles it all.
        var fenceLines: Int

        /// The paragraph a caret at `location` types into. A paragraph owns the
        /// locations from its start up to (not including) its end, so the caret
        /// at the end of a line is still in that line, and the caret after a
        /// final newline is in the trailing empty paragraph.
        func paragraph(at location: Int) -> Paragraph? {
            paragraphs.first { location >= $0.range.location && location < NSMaxRange($0.range) }
                ?? paragraphs.last
        }
    }

    // MARK: - Styling

    static func style(_ text: String, metrics: Metrics, direction: Direction = .ltr) -> Result {
        let mode = mode(for: metrics)
        let ns = text as NSString
        var paragraphs: [Paragraph] = []
        var insideFence = false
        var fenceLines = 0

        var location = 0
        repeat {
            var start = 0, end = 0, contentsEnd = 0
            ns.getParagraphStart(&start, end: &end, contentsEnd: &contentsEnd,
                                 for: NSRange(location: location, length: 0))
            let range = NSRange(location: start, length: end - start)
            let content = NSRange(location: start, length: contentsEnd - start)
            let line = ns.substring(with: content)

            var kind: Kind
            var prefixCells = 0     // marker characters (no indent)
            var indentCells = 0     // leading spaces
            var hasTab = false
            var prefixLength = 0    // UTF-16 length of indent + marker

            if isFence(line) {
                insideFence.toggle()
                fenceLines += 1
                kind = .codeFence
            } else if insideFence {
                kind = .code
            } else if let heading = headingMarker(line) {
                kind = .heading(heading)
                prefixCells = heading + 1
                prefixLength = prefixCells
            } else if let marker = ListContinuation.marker(of: line), isASCII(marker.text) {
                kind = Self.kind(forMarker: marker.text)
                prefixCells = marker.text.utf16.count
                indentCells = marker.indent.utf16.count
                hasTab = marker.indent.contains("\t")
                prefixLength = indentCells + prefixCells
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                kind = .table
            } else {
                kind = .body
            }

            let hasMarker = prefixLength > 0
            let afterPrefix = NSRange(location: start + prefixLength,
                                      length: content.length - prefixLength)
            let rtl = isRTL(ns, in: afterPrefix, fallback: direction)

            // indents and layout
            let layout: Layout
            let first: CGFloat
            let head: CGFloat
            let columnStart = metrics.columnStart
            let cell = metrics.cell
            let markerWidth = CGFloat(prefixCells) * cell
            let prefixWidth = CGFloat(prefixCells + indentCells) * cell

            if rtl {
                // The marker's side flips and indents are measured from the
                // other edge. Do not guess: no indents, inline dimmed syntax.
                layout = hasMarker ? .inline : .plain
                first = 0; head = 0
            } else if mode == .inline {
                layout = hasMarker ? .inline : .plain
                first = 0
                head = hasMarker && !hasTab ? prefixWidth : 0
            } else if !hasMarker {
                layout = .plain
                first = columnStart; head = columnStart
            } else if hasTab || markerWidth > columnStart {
                // can't be placed exactly, or doesn't fit the margin: inline,
                // aligned to the gutter the way the text column would be
                let inset = metrics.gutter - metrics.edge
                layout = .inline
                first = inset
                head = hasTab ? inset : inset + prefixWidth
            } else {
                layout = .hung
                first = columnStart - markerWidth
                head = columnStart + CGFloat(indentCells) * cell
            }

            var runs: [Run] = []
            if hasMarker {
                runs.append(Run(range: NSRange(location: start, length: prefixLength), kind: .marker))
            }
            switch kind {
            case .code, .codeFence, .table:
                break
            default:
                runs.append(contentsOf: inlineRuns(ns, in: afterPrefix))
            }

            paragraphs.append(Paragraph(range: range, kind: kind, layout: layout, isRTL: rtl,
                                        firstLineHeadIndent: first, headIndent: head, runs: runs))
            location = end
        } while location < ns.length

        // text that ends in a line terminator has a last, empty paragraph
        if ns.length > 0, let last = paragraphs.last, last.range.length > 0,
           isTerminator(ns.character(at: ns.length - 1)) {
            let indent = mode == .hanging ? metrics.columnStart : 0
            paragraphs.append(Paragraph(range: NSRange(location: ns.length, length: 0),
                                        kind: insideFence ? .code : .body, layout: .plain,
                                        isRTL: direction == .rtl,
                                        firstLineHeadIndent: direction == .rtl ? 0 : indent,
                                        headIndent: direction == .rtl ? 0 : indent, runs: []))
        }

        return Result(mode: mode,
                      containerInsetLeft: containerInsetLeft(mode, metrics: metrics),
                      paragraphs: paragraphs, fenceLines: fenceLines)
    }

    // MARK: - Block recognition

    private static func kind(forMarker marker: String) -> Kind {
        if marker.hasPrefix(">") { return .quote }
        if marker.contains("[x] ") || marker.contains("[X] ") { return .checklist(checked: true) }
        if marker.contains("[ ] ") { return .checklist(checked: false) }
        if let first = marker.first, first.isNumber { return .numbered }
        return .bullet
    }

    private static func headingMarker(_ line: String) -> Int? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        return rest.hasPrefix(" ") ? hashes : nil
    }

    private static func isFence(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("```") || t.hasPrefix("~~~")
    }

    private static func isASCII(_ s: String) -> Bool { s.utf8.allSatisfy { $0 < 0x80 } }

    private static func isTerminator(_ unit: unichar) -> Bool {
        unit == 0x0A || unit == 0x0D || unit == 0x2028 || unit == 0x2029 || unit == 0x85
    }

    // MARK: - Direction

    /// First strong character wins, the way a natural-direction paragraph is
    /// resolved. No strong character: the layout direction.
    static func isRTL(_ ns: NSString, in range: NSRange, fallback: Direction) -> Bool {
        guard range.length > 0 else { return fallback == .rtl }
        let s = ns.substring(with: range)
        for scalar in s.unicodeScalars {
            if scalar.value == 0x200F || scalar.value == 0x061C { return true }
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
                return isRTLScript(scalar.value)
            default:
                continue
            }
        }
        return fallback == .rtl
    }

    private static func isRTLScript(_ v: UInt32) -> Bool {
        (0x0590...0x08FF).contains(v) || (0xFB1D...0xFDFF).contains(v) ||
        (0xFE70...0xFEFF).contains(v) || (0x10800...0x10FFF).contains(v) ||
        (0x1E800...0x1EFFF).contains(v)
    }

    // MARK: - Inline delimiters

    private static let patterns: [(RunKind, NSRegularExpression, Int)] = {
        func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
        return [
            (.code, re("`([^`\\n]+)`"), 1),
            (.strong, re("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1"), 2),
            (.strike, re("(~~)(?=\\S)(.+?)(?<=\\S)\\1"), 2),
            (.emphasis, re("(?<![*\\w])(\\*)(?=[^\\s*])([^*\\n]+?)(?<=[^\\s*])\\1(?![*\\w])"), 1),
            (.emphasis, re("(?<![_\\w])(_)(?=[^\\s_])([^_\\n]+?)(?<=[^\\s_])\\1(?![_\\w])"), 1),
        ]
    }()

    /// Inline spans in `range`: the span itself (bold, italic, ...) and its
    /// delimiters, which are dimmed. Code spans win over everything inside them.
    static func inlineRuns(_ ns: NSString, in range: NSRange) -> [Run] {
        guard range.length >= 2 else { return [] }
        var spans: [(kind: RunKind, range: NSRange, delimiter: Int)] = []
        var claimed: [NSRange] = []

        let string = ns as String
        for (kind, regex, length) in patterns {
            regex.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
                guard let match else { return }
                let r = match.range
                if claimed.contains(where: { NSIntersectionRange($0, r).length > 0 }) { return }
                spans.append((kind, r, length))
                claimed.append(r)
            }
        }

        var runs: [Run] = []
        for span in spans.sorted(by: { $0.range.location < $1.range.location }) {
            runs.append(Run(range: span.range, kind: span.kind))
            runs.append(Run(range: NSRange(location: span.range.location, length: span.delimiter),
                            kind: .delimiter))
            runs.append(Run(range: NSRange(location: NSMaxRange(span.range) - span.delimiter,
                                           length: span.delimiter), kind: .delimiter))
        }
        return runs
    }
}
