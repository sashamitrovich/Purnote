//
//  NoteBody.swift
//  purenote
//
//  The rendered note, drawn one block at a time.
//
//  A single Markdown view over the whole note renders beautifully and is
//  completely opaque: MarkdownUI keeps no source positions, so there is no way
//  to ask it which line a tap landed on. Rendering block by block puts that
//  back in our hands -- each block already knows the lines it came from, so a
//  tap can tick the checkbox in the file, or open the editor with the caret in
//  the paragraph the reader was looking at.
//
//  The blocks are split by MarkdownBlocks (pure, unit tested). Vertical rhythm
//  moves from the theme's per-block margins to the VStack's spacing, because
//  each Markdown view now only knows about its own block.
//

import SwiftUI
import MarkdownUI

struct NoteBody: View {
    /// The note's source. Ticking a checkbox writes a new value back through
    /// this binding, which is what makes the tap land in the file.
    @Binding var source: String
    /// The note's directory, used to resolve relative image (and link) paths.
    var noteDirectory: URL
    /// Called when a block is tapped, with the offset of the block's first
    /// character -- the place the editor should put the caret.
    var onTapBlock: (Int) -> Void = { _ in }

    private var blocks: [MarkdownBlock] { MarkdownBlocks.split(source) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                if block.isTaskList {
                    taskList(block)
                } else {
                    Markdown(block.text, baseURL: noteDirectory, imageBaseURL: noteDirectory)
                        .markdownTheme(.purnote)
                        .markdownImageProvider(NoteImageProvider())
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        // the whole block is the tap target, not just its glyphs
                        .contentShape(Rectangle())
                        // laid out again underneath, to find the character the
                        // tap actually landed on rather than the top of the block
                        .overlay {
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    // high priority: NoteView puts a tap
                                    // gesture on the whole page for "write at
                                    // the end", and an ancestor's tap otherwise
                                    // wins over this one, so every tap landed
                                    // at the end of the note
                                    .highPriorityGesture(
                                        SpatialTapGesture().onEnded { tap in
                                            onTapBlock(caretOffset(in: block,
                                                                   width: geo.size.width,
                                                                   at: tap.location))
                                        }
                                    )
                            }
                        }
                }
            }
        }
    }

    /// A checklist, drawn as rows we own. The marker is a button so a tap has
    /// somewhere precise to land; the item's text is still Markdown, so bold
    /// and links inside a checklist item keep working.
    private func taskList(_ block: MarkdownBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(block.tasks) { task in
                HStack(alignment: .top, spacing: 4) {
                    // indentation, kept from the file so nesting still reads
                    if !task.indent.isEmpty {
                        Spacer().frame(width: CGFloat(task.indent.count) * 8)
                    }

                    Button {
                        toggle(task)
                    } label: {
                        checkbox(isCompleted: task.isCompleted)
                            // the drawn box is small; the thing you tap is the
                            // 44pt square Apple asks for, centred on it
                            // Padded out to a comfortable target rather than
                            // framed to a square one: a 44pt-tall row leaves a
                            // gap under every single-line item, and the list
                            // stops looking like a list. This keeps the full
                            // width and enough height to hit reliably.
                            .padding(.horizontal, 10)
                            .padding(.vertical, Self.markerVerticalPadding)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.content)
                    .accessibilityValue(task.isCompleted ? "ticked" : "not ticked")
                    .accessibilityAddTraits(.isButton)

                    Markdown(task.content)
                        // a ticked item reads muted, so the eye goes to what is
                        // still left to do. It has to be the theme's text style:
                        // MarkdownUI sets its own colour, so .foregroundColor is
                        // ignored. Keep the FontSize -- the hit-testing in
                        // font(for:) assumes the theme's base size.
                        .markdownTextStyle(\.text) {
                            FontSize(MarkdownTextView.baseFontSize)
                            ForegroundColor(task.isCompleted ? .secondary : .primary)
                        }
                        .markdownTheme(.purnote)
                        // the box sits markerVerticalPadding below the row top;
                        // give the first line the same so the two line up
                        .padding(.top, Self.markerVerticalPadding)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapBlock(block.offset) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// The same soft amber box the theme draws, lifted out so the tappable
    /// rows and the theme cannot drift apart.
    private func checkbox(isCompleted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(isCompleted ? Color.accentColor
                                      : Color(UIColor.tertiaryLabel),
                          lineWidth: 1.7)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isCompleted ? Color.accentColor : .clear)
            )
            .overlay {
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: Self.boxSize, height: Self.boxSize)
    }

    /// Drawn size of the box, and the invisible square you actually hit.
    private static let boxSize: CGFloat = 24
    private static let touchTarget: CGFloat = 44
    /// Vertical padding around the drawn box, so the tap target is taller than
    /// the box. The text's first line is nudged the same amount so the box and
    /// the text line up instead of the text floating a little higher.
    private static let markerVerticalPadding: CGFloat = 6

    /// Where in the file a tap on `block` points.
    private func caretOffset(in block: MarkdownBlock, width: CGFloat, at point: CGPoint) -> Int {
        let font = Self.font(for: block)
        let inside = TextHitTest.characterOffset(in: block.text,
                                                 font: font,
                                                 width: width,
                                                 lineSpacing: font.pointSize * 0.2,
                                                 at: point)
        return block.offset + inside
    }

    /// The font a block is drawn in, so it can be laid out again the same way.
    /// These mirror Theme.purnote -- if the theme's sizes change, these have to
    /// change with them or taps land a line or two out.
    private static func font(for block: MarkdownBlock) -> UIFont {
        let base = MarkdownTextView.baseFontSize
        let heading = block.text.prefix(while: { $0 == "#" }).count
        let isTable = block.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("|")

        let font: UIFont
        if isTable {
            // table cells render at 0.85em (see Theme.purnote's .tableCell)
            font = .systemFont(ofSize: base * 0.85)
        } else {
            switch heading {
            case 1: font = .systemFont(ofSize: base * 1.8, weight: .bold)
            case 2: font = .systemFont(ofSize: base * 1.4, weight: .semibold)
            case 3: font = .systemFont(ofSize: base * 1.15, weight: .semibold)
            default: font = .systemFont(ofSize: base)
            }
        }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }

    private func toggle(_ task: TaskItem) {
        source = MarkdownBlocks.toggleTask(in: source, line: task.id)
    }
}

#Preview {
    @Previewable @State var text = """
    # Shopping

    For the weekend.

    - [ ] milk
    - [x] bread
    - [ ] something with **bold** in it

    A closing paragraph.
    """
    return ScrollView {
        NoteBody(source: $text, noteDirectory: URL(fileURLWithPath: "/tmp"))
            .padding(20)
    }
    .background(Color.purnotePaper)
}
