//
//  MarkdownEditor.swift
//  purenote
//

import SwiftUI

/// A plain text editor with an Apple Notes style formatting bar above the
/// keyboard.
///
/// The buffer stays raw Markdown at all times. Every button only inserts or
/// removes the syntax the user would otherwise have to type from memory, so
/// the file written to iCloud is always byte for byte what is in the editor --
/// there is no rich text model to serialise back out and no way for a round
/// trip to quietly reformat somebody's note.
struct MarkdownEditor: View {
    @Binding var text: String
    /// Where to put the caret when the editor opens, for a tap on the rendered
    /// page that means "let me write here".
    var initialCaret: Int? = nil

    /// The selection in character offsets -- the same units MarkdownFormatter
    /// works in.
    @State private var selection: Range<Int> = 0..<0

    var body: some View {
        MarkdownTextView(text: $text, selection: $selection, initialCaret: initialCaret)
            // TextEditor sat its text hard against the screen edges; the text
            // view has its own inset, so this only adds the outer gutter.
            .padding(.horizontal, 4)
            // A safe area inset rather than ToolbarItem(placement: .keyboard).
            // The keyboard placement only exists while the keyboard is up, and
            // it did not show at all on device; this is ours, so it is always
            // there, always at thumb height, and rides up above the keyboard
            // when the keyboard appears.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                formattingBar
            }
            .tint(Color(UIColor.systemOrange))
    }

    private var formattingBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 28) {
                ForEach(actions) { action in
                    Button(action: action.run) {
                        Image(systemName: action.icon)
                            .imageScale(.large)
                            .frame(minWidth: 24, minHeight: 34)
                    }
                    .accessibilityLabel(action.name)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .frame(height: 46)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Actions

    private struct Action: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let run: () -> Void
    }

    private var actions: [Action] {
        [
            Action(name: "Heading", icon: "textformat.size") { toggleLinePrefix("# ") },
            Action(name: "Bold", icon: "bold") { wrap("**") },
            Action(name: "Italic", icon: "italic") { wrap("*") },
            Action(name: "Strikethrough", icon: "strikethrough") { wrap("~~") },
            Action(name: "Code", icon: "chevron.left.forwardslash.chevron.right") { wrap("`") },
            Action(name: "Bulleted list", icon: "list.bullet") { toggleLinePrefix("- ") },
            Action(name: "Numbered list", icon: "list.number") { toggleLinePrefix("1. ") },
            Action(name: "Checklist", icon: "checklist") { toggleLinePrefix("- [ ] ") },
            Action(name: "Quote", icon: "text.quote") { toggleLinePrefix("> ") },
            Action(name: "Link", icon: "link", run: insertLink),
            Action(name: "Hide keyboard", icon: "keyboard.chevron.compact.down") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            },
        ]
    }

    // MARK: - Editing
    //
    // Everything below works in integer offsets rather than String.Index,
    // because mutating the string invalidates every index into the old value.

    private var selectedOffsets: (lower: Int, upper: Int) {
        (min(selection.lowerBound, text.count), min(selection.upperBound, text.count))
    }

    private func setSelection(_ lower: Int, _ upper: Int) {
        selection = lower..<max(lower, upper)
    }

    // The actual text edits live in MarkdownFormatter (pure, unit-tested); these
    // just translate the current TextSelection to offsets and back.

    private func wrap(_ marker: String) {
        let (lower, upper) = selectedOffsets
        apply(MarkdownFormatter.wrap(text, lower, upper, with: marker))
    }

    private func toggleLinePrefix(_ prefix: String) {
        let (lower, upper) = selectedOffsets
        apply(MarkdownFormatter.toggleLinePrefix(text, lower, upper, prefix: prefix))
    }

    private func insertLink() {
        let (lower, upper) = selectedOffsets
        apply(MarkdownFormatter.insertLink(text, lower, upper))
    }

    private func apply(_ result: MarkdownFormatter.Result) {
        text = result.text
        setSelection(result.lower, result.upper)
    }
}

#Preview {
    @Previewable @State var text = "# Heading\n\nSome **bold** text.\n\n- a list item\n"
    return NavigationStack {
        MarkdownEditor(text: $text)
    }
}
