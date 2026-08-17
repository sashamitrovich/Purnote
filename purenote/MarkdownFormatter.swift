//
//  MarkdownFormatter.swift
//  purenote
//
//  The pure string logic behind the formatting bar, lifted out of MarkdownEditor
//  so it can be unit-tested. Everything works in integer offsets rather than
//  String.Index, because mutating the string invalidates every index into the
//  old value. Each operation returns the new text and the new selection.
//

import Foundation

enum MarkdownFormatter {

    /// Block prefixes the line buttons toggle between. Longest first, so that
    /// "- [ ] " is recognised before the "- " inside it.
    static let blockPrefixes = ["- [ ] ", "- [x] ", "### ", "## ", "# ", "1. ", "- ", "> "]

    struct Result: Equatable {
        var text: String
        var lower: Int
        var upper: Int
    }

    private static func index(_ text: String, _ offset: Int) -> String.Index {
        text.index(text.startIndex, offsetBy: min(max(offset, 0), text.count))
    }

    /// Wraps the selection in `marker`, or unwraps it if it is already wrapped.
    /// With nothing selected it inserts the pair and drops the cursor between
    /// them, so tapping **B** and typing does what you would expect.
    static func wrap(_ text: String, _ lower: Int, _ upper: Int, with marker: String) -> Result {
        var text = text
        let lo = index(text, lower), hi = index(text, upper)
        let selected = String(text[lo..<hi])
        let n = marker.count

        if selected.count >= 2 * n, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            text.replaceSubrange(lo..<hi, with: String(selected.dropFirst(n).dropLast(n)))
            return Result(text: text, lower: lower, upper: upper - 2 * n)
        } else {
            text.replaceSubrange(lo..<hi, with: marker + selected + marker)
            return selected.isEmpty
                ? Result(text: text, lower: lower + n, upper: lower + n)
                : Result(text: text, lower: lower + n, upper: upper + n)
        }
    }

    /// Adds `prefix` to the start of the current line, removes it again if it is
    /// already there, and replaces any competing block prefix.
    static func toggleLinePrefix(_ text: String, _ lower: Int, _ upper: Int, prefix: String) -> Result {
        var text = text
        let lineStart = lineStartOffset(text, at: lower)
        let line = text[index(text, lineStart)...]
        let existing = blockPrefixes.first { line.hasPrefix($0) }

        var delta = 0
        if let existing {
            text.removeSubrange(index(text, lineStart)..<index(text, lineStart + existing.count))
            delta -= existing.count
        }
        if existing != prefix {
            text.insert(contentsOf: prefix, at: index(text, lineStart))
            delta += prefix.count
        }
        return Result(text: text,
                      lower: max(lower + delta, lineStart),
                      upper: max(upper + delta, lineStart))
    }

    /// Turns the selection into `[selection](url)` and selects the "url"
    /// placeholder, so the next thing typed replaces it.
    static func insertLink(_ text: String, _ lower: Int, _ upper: Int) -> Result {
        var text = text
        let lo = index(text, lower), hi = index(text, upper)
        let selected = String(text[lo..<hi])
        text.replaceSubrange(lo..<hi, with: "[\(selected)](url)")
        let placeholder = lower + selected.count + 3   // past "[selected]("
        return Result(text: text, lower: placeholder, upper: placeholder + 3)
    }

    /// Offset of the start of the line containing `offset`.
    static func lineStartOffset(_ text: String, at offset: Int) -> Int {
        let upToCursor = text[text.startIndex..<index(text, offset)]
        guard let newline = upToCursor.lastIndex(of: "\n") else { return 0 }
        return text.distance(from: text.startIndex, to: newline) + 1
    }
}
