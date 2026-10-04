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
        }

        // Nothing selected, but the caret sits inside an empty marker pair just
        // made ("**|**"): pressing the button again cancels it rather than
        // stacking another pair of markers.
        if selected.isEmpty, lower >= n, upper + n <= text.count,
           String(text[index(text, lower - n)..<lo]) == marker,
           String(text[hi..<index(text, upper + n)]) == marker {
            text.replaceSubrange(index(text, lower - n)..<index(text, upper + n), with: "")
            return Result(text: text, lower: lower - n, upper: upper - n)
        }

        // Otherwise wrap the selection -- or the caret point -- in the marker.
        text.replaceSubrange(lo..<hi, with: marker + selected + marker)
        return selected.isEmpty
            ? Result(text: text, lower: lower + n, upper: lower + n)
            : Result(text: text, lower: lower + n, upper: upper + n)
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

    /// Inserts `string` at the selection, replacing whatever is selected, and
    /// places the caret just after the inserted text.
    static func insert(_ text: String, _ lower: Int, _ upper: Int, string: String) -> Result {
        var text = text
        let lo = index(text, lower), hi = index(text, upper)
        text.replaceSubrange(lo..<hi, with: string)
        let caret = lower + string.count
        return Result(text: text, lower: caret, upper: caret)
    }

    /// A GFM table skeleton: a header row, a separator row, and `rows` empty
    /// body rows, each `columns` wide. Inserted at the caret, then the user
    /// types into the cells.
    static func tableSkeleton(rows: Int, columns: Int) -> String {
        func row(_ cells: [String]) -> String {
            "| " + cells.joined(separator: " | ") + " |"
        }
        let width = max(columns, 1)
        let header = row(Array(repeating: "Header", count: width))
        let separator = row(Array(repeating: "---", count: width))
        let body = row(Array(repeating: "", count: width))
        var lines = [header, separator]
        for _ in 0..<max(rows, 1) {
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    /// Offset of the start of the line containing `offset`.
    static func lineStartOffset(_ text: String, at offset: Int) -> Int {
        let upToCursor = text[text.startIndex..<index(text, offset)]
        guard let newline = upToCursor.lastIndex(of: "\n") else { return 0 }
        return text.distance(from: text.startIndex, to: newline) + 1
    }
}
