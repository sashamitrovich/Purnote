//
//  LinkHit.swift
//  purenote
//
//  Is the tapped character part of a link?
//
//  The rendered page opens the editor when a block is tapped. A tap on a link
//  should open the link instead. NoteBody asks TextHitTest which character of
//  the block's *source* is under the finger, and asks this file whether that
//  character belongs to a link.
//
//  Offsets are Characters (what TextHitTest returns, and what the rest of the
//  app counts in), not UTF-16 units. Everything here works on an Array of
//  Characters, so an emoji or an accent before the link cannot shift the answer.
//
//  Recognised:   [label](https://example.com)   (with an optional "title",
//                                               balanced parentheses, wrapped
//                                               labels, <angle> destinations)
//                <https://example.com>
//                https://example.com            (bare)
//  Not links:    ![image](...), anything in `code` or a fenced code block, a
//                backslash-escaped bracket.
//  Only http, https, mailto and tel destinations are returned. A relative link
//  or any other scheme gives nil, and the tap goes to the editor as before.
//

import Foundation
import UIKit

enum LinkHit {

    /// A link in the rendered text: the span of its visible label, in Characters.
    typealias RenderedLink = (range: Range<Int>, url: URL)

    /// What the reader sees for a block of Markdown, with the links in it.
    ///
    /// `plain` drops everything that is markup on the page: emphasis and code
    /// markers, the `[`, `](destination)` around a link label, heading `#`s,
    /// blockquote `>`s and list markers, fence lines and images (an image is
    /// drawn as a picture, so it contributes no text). A soft line break reads
    /// as a space (MarkdownUI's default); a hard break, a new list item, a
    /// heading and a code line keep their line break. Link ranges are measured
    /// in Characters of `plain` and cover the visible label only. Only http,
    /// https, mailto and tel links are returned.
    ///
    /// A table is returned untouched with no links: it is drawn as a grid, so a
    /// text layout of it cannot say what is under a finger.
    static func rendered(from text: String) -> (plain: String, links: [RenderedLink]) {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map { Array($0) }
        if let first = lines.first(where: { !$0.allSatisfy { $0.isWhitespace } }),
           String(first).trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            return (text, [])
        }

        var out: [Character] = []
        var links: [RenderedLink] = []
        var pending: [Character] = []
        var hasPending = false
        var previousWasHeading = false
        var previousWasHardBreak = false
        var openFence: (char: Character, length: Int)?

        func flush() {
            guard hasPending else { return }
            let inline = Scanner(chars: pending).renderInline()
            if !out.isEmpty { out.append("\n") }
            let base = out.count
            out += inline.plain
            links += inline.links.map { ((base + $0.range.lowerBound)..<(base + $0.range.upperBound), $0.url) }
            pending = []
            hasPending = false
        }

        for line in lines {
            let scanner = Scanner(chars: line)
            if let open = openFence {
                if let close = scanner.fenceLine(), close.char == open.char,
                   close.length >= open.length, close.isBare {
                    openFence = nil
                } else {
                    if !out.isEmpty { out.append("\n") }
                    out += line
                }
                continue
            }
            if let fence = scanner.fenceLine() {
                flush()
                openFence = (fence.char, fence.length)
                previousWasHeading = false
                continue
            }
            if line.allSatisfy { $0.isWhitespace } {
                flush()
                previousWasHeading = false
                continue
            }

            var body = Array(line)
            let hard = body.count >= 2 && body.suffix(2).allSatisfy { $0 == " " }
                || body.last == "\\"
            if body.last == "\\" { body.removeLast() }
            while let last = body.last, last.isWhitespace { body.removeLast() }

            var isBlockStart = false
            var isHeading = false
            func dropSpaces() { while body.first?.isWhitespace == true { body.removeFirst() } }
            dropSpaces()
            while body.first == ">" {
                body.removeFirst()
                dropSpaces()
            }
            let hashes = body.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), hashes == body.count || body[hashes] == " " {
                body.removeFirst(min(hashes + 1, body.count))
                dropSpaces()
                isHeading = true
                isBlockStart = true
            } else if body.count >= 2, "-*+".contains(body[0]), body[1] == " " {
                body.removeFirst(2)
                dropSpaces()
                isBlockStart = true
            } else {
                let digits = body.prefix(while: { $0.isASCII && $0.isNumber }).count
                if (1...9).contains(digits), body.count > digits + 1,
                   body[digits] == "." || body[digits] == ")", body[digits + 1] == " " {
                    body.removeFirst(digits + 2)
                    dropSpaces()
                    isBlockStart = true
                }
            }

            if hasPending, isBlockStart || previousWasHeading {
                flush()
            }
            if hasPending {
                pending.append(previousWasHardBreak ? "\n" : " ")
            }
            pending += body
            hasPending = true
            previousWasHeading = isHeading
            previousWasHardBreak = hard
        }
        flush()
        return (String(out), links)
    }

    /// The URL of the link under `point` when `text` is laid out at `width`
    /// in `font`, or nil.
    ///
    /// The hit test runs on the *rendered* text (see `rendered(from:)`), not on
    /// the Markdown source, and asks which character contains the point rather
    /// than which edge is nearest. So words after a link are not the link, even
    /// though the source carries a long hidden destination after the label.
    static func url(at point: CGPoint, in text: String, font: UIFont, width: CGFloat,
                    lineSpacing: CGFloat) -> URL? {
        let rendered = rendered(from: text)
        guard !rendered.links.isEmpty,
              let index = TextHitTest.characterIndex(containing: point, in: rendered.plain,
                                                     font: font, width: width,
                                                     lineSpacing: lineSpacing)
        else { return nil }
        return rendered.links.first { $0.range.contains(index) }?.url
    }

    private static let openableSchemes: Set<String> = ["http", "https", "mailto", "tel"]

    /// The URL for `string`, if it is one we open.
    private static func openable(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              openableSchemes.contains(scheme)
        else { return nil }
        return url
    }

    private struct Scanner {
        let chars: [Character]
        var n: Int { chars.count }

        // MARK: code

        /// Run of `ch` starting at `i`.
        private func runLength(of ch: Character, at i: Int) -> Int {
            var j = i
            while j < n, chars[j] == ch { j += 1 }
            return j - i
        }

        /// Index of the start of the line after the one containing `i`.
        private func endOfLine(from i: Int) -> Int {
            var j = i
            while j < n, !chars[j].isNewline { j += 1 }
            return min(j + 1, n)
        }

        private func fence(onLineAt i: Int) -> (char: Character, length: Int, isBare: Bool)? {
            var j = i
            var indent = 0
            while j < n, chars[j] == " ", indent < 4 { j += 1; indent += 1 }
            guard indent <= 3, j < n, chars[j] == "`" || chars[j] == "~" else { return nil }
            let ch = chars[j]
            let length = runLength(of: ch, at: j)
            guard length >= 3 else { return nil }
            j += length
            var bare = true
            var k = j
            while k < n, !chars[k].isNewline {
                if !chars[k].isWhitespace { bare = false }
                k += 1
            }
            return (ch, length, bare)
        }

        /// Index just past the code span that opens at `i` (a run of backticks
        /// closed by a run of the same length), or just past the run if it
        /// never closes.
        private func codeSpanEnd(from i: Int) -> Int {
            let length = runLength(of: "`", at: i)
            var j = i + length
            while j < n {
                if chars[j] == "`" {
                    let run = runLength(of: "`", at: j)
                    if run == length { return j + run }
                    j += run
                } else {
                    j += 1
                }
            }
            return i + length
        }

        // MARK: inline links

        private func skipWhitespace(_ p: Int) -> Int {
            var p = p
            while p < n, chars[p].isWhitespace { p += 1 }
            return p
        }

        /// `[label](destination "title")` opening at the `[` at `open`.
        private func inlineLink(at open: Int) -> (end: Int, destination: String, label: Range<Int>)? {
            // the label: brackets nest, backslash escapes, code spans hide them
            var depth = 1
            var j = open + 1
            while j < n {
                let ch = chars[j]
                if ch == "\\" {
                    j += 2
                } else if ch == "`" {
                    j = codeSpanEnd(from: j)
                } else if ch == "[" {
                    depth += 1
                    j += 1
                } else if ch == "]" {
                    depth -= 1
                    if depth == 0 { break }
                    j += 1
                } else if ch.isNewline, j + 1 < n, chars[j + 1].isNewline {
                    return nil // a blank line ends the paragraph
                } else {
                    j += 1
                }
            }
            guard j < n, chars[j] == "]", j + 1 < n, chars[j + 1] == "(" else { return nil }

            var p = skipWhitespace(j + 2)
            guard p < n else { return nil }

            // the destination
            var destination = ""
            if chars[p] == "<" {
                p += 1
                while p < n, chars[p] != ">" {
                    if chars[p].isNewline || chars[p] == "<" { return nil }
                    destination.append(chars[p])
                    p += 1
                }
                guard p < n else { return nil }
                p += 1
            } else {
                var parens = 0
                while p < n, !chars[p].isWhitespace {
                    let ch = chars[p]
                    if ch == "\\", p + 1 < n, chars[p + 1].isPunctuation || chars[p + 1].isSymbol {
                        destination.append(chars[p + 1])
                        p += 2
                        continue
                    }
                    if ch == "(" {
                        parens += 1
                    } else if ch == ")" {
                        if parens == 0 { break }
                        parens -= 1
                    }
                    destination.append(ch)
                    p += 1
                }
                if parens != 0 || destination.isEmpty { return nil }
            }

            // an optional title, then the closing parenthesis
            let afterDestination = p
            p = skipWhitespace(p)
            if p < n, chars[p] != ")" {
                guard p > afterDestination else { return nil } // title needs a space before it
                let closer: Character
                switch chars[p] {
                case "\"": closer = "\""
                case "'": closer = "'"
                case "(": closer = ")"
                default: return nil
                }
                p += 1
                while p < n, chars[p] != closer {
                    p += chars[p] == "\\" ? 2 : 1
                }
                guard p < n else { return nil }
                p = skipWhitespace(p + 1)
            }
            guard p < n, chars[p] == ")" else { return nil }
            return (p + 1, destination, (open + 1)..<j)
        }

        // MARK: autolinks and bare URLs

        /// `<https://example.com>` or `<name@example.com>` opening at `open`.
        /// A well-formed autolink of a scheme we do not open comes back with a
        /// nil url, so it is skipped rather than rescanned.
        private func autolink(at open: Int) -> (end: Int, url: URL?)? {
            var j = open + 1
            while j < n, chars[j] != ">" {
                if chars[j].isWhitespace || chars[j] == "<" { return nil }
                j += 1
            }
            guard j < n, j > open + 1 else { return nil }
            let content = String(chars[(open + 1)..<j])
            if let colon = content.firstIndex(of: ":") {
                let scheme = content[..<colon]
                guard scheme.count >= 2, scheme.first?.isASCII == true, scheme.first?.isLetter == true,
                      scheme.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+.-".contains($0)) })
                else { return nil }
                return (j + 1, LinkHit.openable(content))
            }
            if content.contains("@"), !content.contains("\\") {
                return (j + 1, LinkHit.openable("mailto:" + content))
            }
            return nil
        }

        /// A bare http:// or https:// URL starting at `i`.
        private func bareURL(at i: Int) -> (end: Int, url: URL)? {
            if i > 0, chars[i - 1].isLetter || chars[i - 1].isNumber { return nil }
            let lower = String(chars[i..<min(i + 8, n)]).lowercased()
            let schemeLength: Int
            if lower.hasPrefix("https://") {
                schemeLength = 8
            } else if lower.hasPrefix("http://") {
                schemeLength = 7
            } else {
                return nil
            }
            let bodyStart = i + schemeLength
            var end = bodyStart
            while end < n, !chars[end].isWhitespace, chars[end] != "<" { end += 1 }

            // sentence punctuation and a closing bracket that belongs to the
            // text around the URL are not part of it
            while end > bodyStart {
                let last = chars[end - 1]
                let trailing: Set<Character> = [".", ",", ";", ":", "!", "?", "\"", "'", "*", "_", "~"]
                if trailing.contains(last) {
                    end -= 1
                } else if last == ")" || last == "]" {
                    let open: Character = last == ")" ? "(" : "["
                    let body = chars[bodyStart..<end]
                    if body.filter({ $0 == last }).count > body.filter({ $0 == open }).count {
                        end -= 1
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
            guard end > bodyStart, let url = LinkHit.openable(String(chars[i..<end])) else { return nil }
            return (end, url)
        }

        // MARK: rendering (what the reader sees)

        /// The visible text of an inline run, with the links in it. Markers
        /// (emphasis, code backticks, escapes, the `[](...)` around a label,
        /// images) are dropped; link ranges are the visible label in the output.
        /// Images are dropped entirely (they draw as a picture, not as text).
        func renderInline() -> (plain: [Character], links: [RenderedLink]) {
            var out: [Character] = []
            var links: [RenderedLink] = []
            var i = 0
            while i < n {
                let ch = chars[i]
                switch ch {
                case "\\":
                    if i + 1 < n, chars[i + 1].isPunctuation || chars[i + 1].isSymbol {
                        out.append(chars[i + 1])
                        i += 2
                    } else {
                        out.append(ch)
                        i += 1
                    }
                case "`":
                    let length = runLength(of: "`", at: i)
                    let end = codeSpanEnd(from: i)
                    if end > i + length {
                        var content = Array(chars[(i + length)..<(end - length)])
                        if content.count >= 2, content.first == " ", content.last == " ",
                           content.contains(where: { $0 != " " }) {
                            content.removeFirst()
                            content.removeLast()
                        }
                        out += content
                    } else {
                        out += chars[i..<end]
                    }
                    i = end
                case "!":
                    if i + 1 < n, chars[i + 1] == "[", let parsed = inlineLink(at: i + 1) {
                        i = parsed.end
                    } else {
                        out.append(ch)
                        i += 1
                    }
                case "[":
                    if let parsed = inlineLink(at: i) {
                        let label = Scanner(chars: Array(chars[parsed.label])).renderInline()
                        let start = out.count
                        out += label.plain
                        if !label.plain.isEmpty, let url = LinkHit.openable(parsed.destination) {
                            links.append((start..<out.count, url))
                        }
                        i = parsed.end
                    } else {
                        out.append(ch)
                        i += 1
                    }
                case "<":
                    if let parsed = autolink(at: i) {
                        let start = out.count
                        out += chars[(i + 1)..<(parsed.end - 1)]
                        if let url = parsed.url { links.append((start..<out.count, url)) }
                        i = parsed.end
                    } else {
                        out.append(ch)
                        i += 1
                    }
                case "h", "H":
                    if let parsed = bareURL(at: i) {
                        let start = out.count
                        out += chars[i..<parsed.end]
                        links.append((start..<out.count, parsed.url))
                        i = parsed.end
                    } else {
                        out.append(ch)
                        i += 1
                    }
                case "*", "_", "~":
                    let length = runLength(of: ch, at: i)
                    if isEmphasisDelimiter(ch, at: i, length: length) {
                        i += length
                    } else {
                        out += chars[i..<(i + length)]
                        i += length
                    }
                default:
                    out.append(ch)
                    i += 1
                }
            }
            return (out, links)
        }

        /// Whether a run of `*`, `_` or `~` is emphasis markup rather than a
        /// literal character ("2 * 3", snake_case).
        private func isEmphasisDelimiter(_ ch: Character, at i: Int, length: Int) -> Bool {
            if ch == "~", length > 2 { return false }
            let before: Character? = i > 0 ? chars[i - 1] : nil
            let after: Character? = i + length < n ? chars[i + length] : nil
            let opens = after.map { !$0.isWhitespace } ?? false
            let closes = before.map { !$0.isWhitespace } ?? false
            guard opens || closes else { return false }
            if ch == "_", let b = before, let a = after,
               (b.isLetter || b.isNumber), (a.isLetter || a.isNumber) {
                return false // inside a word
            }
            return true
        }

        /// A fence line (opening or closing), for the line-level pass.
        func fenceLine() -> (char: Character, length: Int, isBare: Bool)? {
            fence(onLineAt: 0)
        }
    }
}
