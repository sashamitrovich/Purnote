//
//  MarkdownBlocks.swift
//  purenote
//
//  Splits a note's Markdown source into top level blocks, each one keeping the
//  range of source lines it came from.
//
//  MarkdownUI renders a note beautifully but tells us nothing about where any
//  of it came from: TaskListMarkerConfiguration carries only `isCompleted`, and
//  its BlockNode tree has no source positions and is internal to the package.
//  So a tap on the rendered note cannot be traced back to the file.
//
//  Rather than fight that, we do the small amount of parsing we actually need
//  ourselves. Knowing which lines a block occupies is enough to tick a checkbox
//  in the file, and to drop the editor's caret where the reader tapped -- and
//  it is pure string work, so it can be unit tested the way MarkdownFormatter
//  already is.
//

import Foundation

/// One top level block of a note, and where it lives in the source.
struct MarkdownBlock: Identifiable, Equatable {
    /// Position in document order. Stable for a given source string, which is
    /// all a ForEach needs.
    let id: Int
    /// The lines this block occupies, as indices into the source's lines.
    let lines: Range<Int>
    /// The block's own source, ready to hand to a Markdown view.
    let text: String
    /// Offset of the block's first character in the whole source, so a tap can
    /// become a caret position.
    let offset: Int
    /// The task list items in this block, empty for every other kind of block.
    let tasks: [TaskItem]

    var isTaskList: Bool { !tasks.isEmpty }
}

/// A single `- [ ]` line.
struct TaskItem: Identifiable, Equatable {
    /// Index of the line in the source.
    let id: Int
    var isCompleted: Bool
    /// The indentation in front of the marker, preserved so nesting survives.
    let indent: String
    /// Everything after the marker -- the item's own Markdown.
    let content: String
}

enum MarkdownBlocks {

    /// Splits `text` into blocks on blank lines, keeping fenced code blocks
    /// whole -- a blank line inside a fence is part of the code, not a break
    /// between blocks.
    static func split(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")

        // Offset of the first character of each line, so a block can report
        // where it starts without counting the string again.
        var lineOffsets: [Int] = []
        var running = 0
        for line in lines {
            lineOffsets.append(running)
            running += line.count + 1   // + the newline we split on
        }

        var blocks: [MarkdownBlock] = []
        var start: Int? = nil
        var inFence = false

        func append(_ range: Range<Int>) {
            guard !range.isEmpty else { return }
            blocks.append(
                MarkdownBlock(id: blocks.count,
                              lines: range,
                              text: lines[range].joined(separator: "\n"),
                              offset: lineOffsets[range.lowerBound],
                              tasks: tasks(in: lines, range))
            )
        }

        /// Closes the run of lines that started at `start`.
        ///
        /// A blank line is not the only thing that ends a block: Markdown lets a
        /// list follow a heading with nothing in between, and the sample notes
        /// do exactly that. So the run is broken further wherever it changes
        /// between checkbox lines and everything else -- otherwise a heading
        /// glued to a checklist made the whole thing "not a checklist", and the
        /// boxes were not tappable.
        func closeBlock(at end: Int) {
            guard let from = start, from < end else { start = nil; return }
            defer { start = nil }

            // a fenced code block is always one piece, markers inside are code
            if lines[from].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                append(from..<end)
                return
            }

            var runStart = from
            var runIsTask = taskItem(lines[from], line: from) != nil
            for i in (from + 1)..<end {
                let isTask = taskItem(lines[i], line: i) != nil
                if isTask != runIsTask {
                    append(runStart..<i)
                    runStart = i
                    runIsTask = isTask
                }
            }
            append(runStart..<end)
        }

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inFence {
                    // the closing fence belongs to the block it closes
                    inFence = false
                    closeBlock(at: i + 1)
                } else {
                    if start == nil { start = i }
                    inFence = true
                }
                continue
            }

            if inFence { continue }

            if trimmed.isEmpty {
                closeBlock(at: i)
            } else if start == nil {
                start = i
            }
        }
        closeBlock(at: lines.count)

        return blocks
    }

    /// The task list items among a range of lines. A block counts as a task
    /// list only when every one of its lines is a task item: a paragraph that
    /// merely happens to mention a checkbox stays an ordinary block, and so
    /// does a mixed list, where tapping a marker would be ambiguous.
    private static func tasks(in lines: [String], _ range: Range<Int>) -> [TaskItem] {
        var items: [TaskItem] = []
        for i in range {
            guard let item = taskItem(lines[i], line: i) else { return [] }
            items.append(item)
        }
        return items
    }

    /// Parses one `- [ ] something` line, at any indentation, accepting `x` or
    /// `X` as ticked. Returns nil for anything else.
    static func taskItem(_ line: String, line index: Int) -> TaskItem? {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let rest = line.dropFirst(indent.count)

        for marker in ["- ", "* ", "+ "] where rest.hasPrefix(marker) {
            let afterBullet = rest.dropFirst(marker.count)
            for (box, done) in [("[ ] ", false), ("[x] ", true), ("[X] ", true)]
            where afterBullet.hasPrefix(box) {
                return TaskItem(id: index,
                                isCompleted: done,
                                indent: indent,
                                content: String(afterBullet.dropFirst(box.count)))
            }
        }
        return nil
    }

    /// Returns `text` with the checkbox on `line` flipped, and everything else
    /// -- including the bullet character and the indentation -- exactly as it
    /// was. Only the one character inside the brackets changes, so a note round
    /// trips through a tap unaltered.
    static func toggleTask(in text: String, line index: Int) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(index),
              let item = taskItem(lines[index], line: index)
        else { return text }

        let bullet = lines[index]
            .dropFirst(item.indent.count)
            .prefix(2)                       // "- ", "* " or "+ "
        let box = item.isCompleted ? "[ ] " : "[x] "
        lines[index] = item.indent + bullet + box + item.content

        return lines.joined(separator: "\n")
    }
}
