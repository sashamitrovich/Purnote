//
//  ListContinuation.swift
//  purenote
//
//  What the Return key should do inside a list.
//
//  Pressing Return on "- milk" should give you another bullet, not a bare new
//  line -- the thing every notes app does and the reason writing a list in
//  Purnote used to mean typing the marker again every time.
//
//  Pure string work, like MarkdownFormatter: given the text and where the caret
//  is, say what the text and the caret should become. The editor's only job is
//  to ask, and to apply the answer.
//

import Foundation

enum ListContinuation {

    struct Result: Equatable {
        var text: String
        var caret: Int
    }

    /// A single edit to make, described rather than performed.
    ///
    /// The editor needs this rather than a finished string: UITextView applies
    /// it as one change, which keeps undo to a single step and means the app
    /// never assigns a whole new buffer underneath the user.
    struct Edit: Equatable {
        /// Character offsets into the text as it stands before the edit.
        var range: Range<Int>
        var replacement: String
        /// Where the caret goes afterwards, in character offsets.
        var caret: Int
    }

    /// The list marker at the start of a line.
    struct Marker: Equatable {
        /// Whitespace before the marker, carried onto the next item so nesting
        /// survives a Return.
        var indent: String
        /// The marker as it appears in the file, e.g. "- ", "1. ", "- [x] ".
        var text: String
        /// What the *next* item's marker should be: numbers advance, and a
        /// ticked box starts the next item unticked, because the new item has
        /// not been done yet.
        var next: String
    }

    /// Reads the list marker at the beginning of `line`, if there is one.
    static func marker(of line: String) -> Marker? {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let rest = Substring(line.dropFirst(indent.count))

        // a checkbox: "- [ ] " / "* [x] " ...
        for bullet in ["- ", "* ", "+ "] where rest.hasPrefix(bullet) {
            let afterBullet = rest.dropFirst(bullet.count)
            for box in ["[ ] ", "[x] ", "[X] "] where afterBullet.hasPrefix(box) {
                return Marker(indent: indent,
                              text: bullet + box,
                              next: bullet + "[ ] ")
            }
            // a plain bullet
            return Marker(indent: indent, text: bullet, next: bullet)
        }

        // a quote
        if rest.hasPrefix("> ") {
            return Marker(indent: indent, text: "> ", next: "> ")
        }

        // a numbered item: "1. ", "12) "
        let digits = rest.prefix { $0.isNumber }
        if !digits.isEmpty {
            let afterDigits = rest.dropFirst(digits.count)
            for separator in [". ", ") "] where afterDigits.hasPrefix(separator) {
                let number = Int(digits) ?? 0
                return Marker(indent: indent,
                              text: digits + separator,
                              next: "\(number + 1)" + separator)
            }
        }

        return nil
    }

    /// What should happen when Return is pressed at `caret`, as a finished
    /// string. Kept for the tests and for anything that wants the whole text.
    static func onReturn(_ text: String, at caret: Int) -> Result? {
        guard let edit = edit(text, at: caret) else { return nil }
        var out = text
        out.replaceSubrange(index(out, edit.range.lowerBound)..<index(out, edit.range.upperBound),
                            with: edit.replacement)
        return Result(text: out, caret: edit.caret)
    }

    /// What should happen when Return is pressed at `caret`, as one edit.
    ///
    /// Returns nil when the newline should simply be inserted, which is the
    /// answer everywhere except inside a list.
    static func edit(_ text: String, at caret: Int) -> Edit? {
        let caret = min(max(caret, 0), text.count)
        guard !isInsideCodeFence(text, at: caret) else { return nil }

        let lines = text.components(separatedBy: "\n")
        let (lineIndex, lineStart) = line(containing: caret, in: lines)
        guard lines.indices.contains(lineIndex) else { return nil }

        let line = lines[lineIndex]
        guard let marker = marker(of: line) else { return nil }

        let content = line.dropFirst(marker.indent.count + marker.text.count)

        // Return on an item with nothing in it means "I am done with this
        // list". A nested item steps out one level first, the way Notes does;
        // a top level one loses its marker and leaves an ordinary empty line.
        if content.isEmpty {
            return endingItem(text, lines: lines,
                              lineIndex: lineIndex, lineStart: lineStart,
                              marker: marker)
        }

        // an ordinary continuation: newline, the same indentation, the next
        // marker, and the caret ready to type
        let insertion = "\n" + marker.indent + marker.next
        return Edit(range: caret..<caret,
                    replacement: insertion,
                    caret: caret + insertion.count)
    }

    /// Backs out of an empty list item, either by one level of indentation or
    /// out of the list altogether.
    private static func endingItem(_ text: String, lines: [String],
                                   lineIndex: Int, lineStart: Int,
                                   marker: Marker) -> Edit {
        let lineEnd = lineStart + lines[lineIndex].count

        let replacement: String
        if let outdented = outdent(marker.indent) {
            // still inside a nested list: keep the marker, lose a level
            replacement = outdented + marker.text
        } else {
            // out of the list entirely
            replacement = ""
        }

        return Edit(range: lineStart..<lineEnd,
                    replacement: replacement,
                    caret: lineStart + replacement.count)
    }

    /// One level less indentation, or nil if there was none to give back.
    private static func outdent(_ indent: String) -> String? {
        if indent.hasSuffix("\t") { return String(indent.dropLast()) }
        if indent.hasSuffix("    ") { return String(indent.dropLast(4)) }
        if indent.hasSuffix("  ") { return String(indent.dropLast(2)) }
        if indent.hasSuffix(" ") { return String(indent.dropLast()) }
        return nil
    }

    /// True when the caret sits inside a ``` fenced code block, where a list
    /// marker is just code and Return means a plain new line.
    static func isInsideCodeFence(_ text: String, at caret: Int) -> Bool {
        let before = text[text.startIndex..<index(text, caret)]
        let fences = before.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            .count
        return fences % 2 == 1
    }

    // MARK: - Offsets

    /// The index of the line containing `caret`, and the offset that line
    /// starts at.
    private static func line(containing caret: Int, in lines: [String]) -> (index: Int, start: Int) {
        var start = 0
        for (i, line) in lines.enumerated() {
            let end = start + line.count
            if caret <= end { return (i, start) }
            start = end + 1     // the newline
        }
        return (max(lines.count - 1, 0), start)
    }

    private static func index(_ text: String, _ offset: Int) -> String.Index {
        text.index(text.startIndex, offsetBy: min(max(offset, 0), text.count))
    }
}
