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

enum LinkHit {

    /// The URL to open when the Character at `offset` of `text` is inside a
    /// link, or nil when it is not (or the link is not one we open).
    ///
    /// `offset` counts Characters. A value outside `0..<text.count` gives nil.
    static func url(at offset: Int, in text: String) -> URL? {
        guard offset >= 0, !text.isEmpty else { return nil }
        let chars = Array(text)
        guard offset < chars.count else { return nil }
        return Scanner(chars: chars).links().first { $0.range.contains(offset) }?.url
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

    private struct Link {
        let range: Range<Int>
        let url: URL
    }

    private struct Scanner {
        let chars: [Character]
        var n: Int { chars.count }

        func links() -> [Link] {
            var found: [Link] = []
            var i = 0
            while i < n {
                if isLineStart(i), let end = fencedCodeEnd(from: i) {
                    i = end
                    continue
                }
                switch chars[i] {
                case "\\":
                    i += 2
                case "`":
                    i = codeSpanEnd(from: i)
                case "!":
                    // an image is not a link; skip the whole construct so the
                    // alt text and the address are not looked at
                    if i + 1 < n, chars[i + 1] == "[", let parsed = inlineLink(at: i + 1) {
                        i = parsed.end
                    } else {
                        i += 1
                    }
                case "[":
                    if let parsed = inlineLink(at: i) {
                        if let url = LinkHit.openable(parsed.destination) {
                            found.append(Link(range: i..<parsed.end, url: url))
                        }
                        i = parsed.end
                    } else {
                        i += 1
                    }
                case "<":
                    if let parsed = autolink(at: i) {
                        if let url = parsed.url {
                            found.append(Link(range: i..<parsed.end, url: url))
                        }
                        i = parsed.end
                    } else {
                        i += 1
                    }
                case "h", "H":
                    if let parsed = bareURL(at: i) {
                        found.append(Link(range: i..<parsed.end, url: parsed.url))
                        i = parsed.end
                    } else {
                        i += 1
                    }
                default:
                    i += 1
                }
            }
            return found
        }

        // MARK: code

        private func isLineStart(_ i: Int) -> Bool {
            i == 0 || chars[i - 1].isNewline
        }

        /// Run of `ch` starting at `i`.
        private func runLength(of ch: Character, at i: Int) -> Int {
            var j = i
            while j < n, chars[j] == ch { j += 1 }
            return j - i
        }

        /// If a fence opens on the line starting at `i`, the index just past
        /// the line that closes it (or the end of the text if it never closes).
        private func fencedCodeEnd(from i: Int) -> Int? {
            guard let open = fence(onLineAt: i) else { return nil }
            var j = endOfLine(from: i)
            while j < n {
                let lineStart = j
                if let close = fence(onLineAt: lineStart),
                   close.char == open.char, close.length >= open.length, close.isBare {
                    return endOfLine(from: lineStart)
                }
                j = endOfLine(from: lineStart)
            }
            return n
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
        private func inlineLink(at open: Int) -> (end: Int, destination: String)? {
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
            return (p + 1, destination)
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
    }
}
