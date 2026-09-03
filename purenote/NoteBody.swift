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
                    Markdown(block.text)
                        .markdownTheme(.purnote)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        // the whole block is the tap target, not just its glyphs
                        .contentShape(Rectangle())
                        .onTapGesture { onTapBlock(block.offset) }
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
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.content)
                    .accessibilityValue(task.isCompleted ? "ticked" : "not ticked")
                    .accessibilityAddTraits(.isButton)

                    Markdown(task.content)
                        .markdownTheme(.purnote)
                        .padding(.top, 1)
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
            .strokeBorder(isCompleted ? Color(UIColor.systemOrange)
                                      : Color(UIColor.tertiaryLabel),
                          lineWidth: 1.7)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isCompleted ? Color(UIColor.systemOrange) : .clear)
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
        NoteBody(source: $text)
            .padding(20)
    }
    .background(Color.purnotePaper)
}
