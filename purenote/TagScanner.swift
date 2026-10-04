//
//  TagScanner.swift
//  purenote
//

import Foundation

/// Extracts `#tag` tokens from a note's Markdown, so tags can stay plain text
/// in the file rather than living in a database.
///
/// A tag is a `#` followed by one or more tag characters (letters, numbers,
/// `_`, `-`). The `#` must not be attached to a word or a URL fragment, and it
/// must not sit inside code:
///
/// - `# Heading` / `## Sub` are headings, not tags (no tag characters after `#`).
/// - `C#`, `word#suffix`, `https://x/a#frag`, `\#escaped` are not tags.
/// - `` `#code` `` and fenced blocks are ignored.
enum TagScanner {

    static func tags(in text: String) -> [String] {
        let chars = Array(text)
        var result: [String] = []
        var seen = Set<String>()
        var index = 0

        // scanner state
        var inFence = false
        var fenceChar: Character = "`"
        var fenceLength = 0
        var inCodeSpan = false
        var codeSpanLength = 0

        func isTagCharacter(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "-"
        }
        func isWordCharacter(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_"
        }
        func isLineStart(_ i: Int) -> Bool {
            i == 0 || chars[i - 1] == "\n"
        }
        func runLength(of c: Character, from i: Int) -> Int {
            var j = i
            while j < chars.count && chars[j] == c { j += 1 }
            return j - i
        }

        while index < chars.count {
            let c = chars[index]

            // Inside a fenced block, look only for the closing fence.
            if inFence {
                if c == fenceChar && isLineStart(index),
                   runLength(of: fenceChar, from: index) >= fenceLength {
                    inFence = false
                    index += runLength(of: fenceChar, from: index)
                    continue
                }
                index += 1
                continue
            }

            // A fence opener: ``` or ~~~ at the start of a line.
            if (c == "`" || c == "~") && isLineStart(index) {
                let run = runLength(of: c, from: index)
                if run >= 3 {
                    inFence = true
                    fenceChar = c
                    fenceLength = run
                    index += run
                    continue
                }
            }

            // Inline code span.
            if c == "`" {
                let run = runLength(of: c, from: index)
                if !inCodeSpan {
                    inCodeSpan = true
                    codeSpanLength = run
                } else if run == codeSpanLength {
                    inCodeSpan = false
                }
                index += run
                continue
            }

            if inCodeSpan {
                index += 1
                continue
            }

            // A candidate tag.
            if c == "#" {
                let previous: Character? = index == 0 ? nil : chars[index - 1]
                let blocked = previous.map {
                    isWordCharacter($0) || $0 == "/" || $0 == "#" || $0 == "\\" || $0 == "&"
                } ?? false

                if !blocked {
                    var j = index + 1
                    var tag = ""
                    while j < chars.count && isTagCharacter(chars[j]) {
                        tag.append(chars[j])
                        j += 1
                    }
                    if !tag.isEmpty {
                        let key = tag.lowercased()
                        if !seen.contains(key) {
                            seen.insert(key)
                            result.append(tag)
                        }
                        index = j
                        continue
                    }
                }
            }

            index += 1
        }

        return result
    }
}
