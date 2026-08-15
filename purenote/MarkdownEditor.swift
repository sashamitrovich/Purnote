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

    @State private var selection: TextSelection?
    @FocusState private var focused: Bool

    /// Block prefixes the line buttons toggle between. Longest first, so that
    /// "- [ ] " is recognised before the "- " inside it.
    private static let blockPrefixes = ["- [ ] ", "- [x] ", "### ", "## ", "# ", "1. ", "- ", "> "]

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .focused($focused)
            .task {
                // the presentation animation has to finish before the editor
                // can become first responder. onAppear, and a short sleep, are
                // both too early inside a sheet or a fullScreenCover: the
                // focus is dropped, the keyboard never comes up, and the
                // formatting bar goes with it
                try? await Task.sleep(for: .milliseconds(450))
                focused = true
            }
            // TextEditor sits its text hard against the screen edges. Pad the
            // editor itself (not the whole view) so text gets a comfortable
            // gutter, while the formatting bar below still spans full width --
            // the padding is applied before .safeAreaInset for exactly that
            // reason.
            .padding(.horizontal, 12)
            .padding(.top, 8)
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
            Action(name: "Hide keyboard", icon: "keyboard.chevron.compact.down") { focused = false },
        ]
    }

    // MARK: - Editing
    //
    // Everything below works in integer offsets rather than String.Index,
    // because mutating the string invalidates every index into the old value.

    private var selectedOffsets: (lower: Int, upper: Int) {
        let range: Range<String.Index>
        switch selection?.indices {
        case .selection(let r):
            range = r
        case .multiSelection(let set):
            range = set.ranges.first ?? text.endIndex..<text.endIndex
        case nil:
            range = text.endIndex..<text.endIndex
        @unknown default:
            range = text.endIndex..<text.endIndex
        }
        return (text.distance(from: text.startIndex, to: range.lowerBound),
                text.distance(from: text.startIndex, to: range.upperBound))
    }

    private func index(_ offset: Int) -> String.Index {
        text.index(text.startIndex, offsetBy: min(max(offset, 0), text.count))
    }

    private func setSelection(_ lower: Int, _ upper: Int) {
        selection = lower == upper
            ? TextSelection(insertionPoint: index(lower))
            : TextSelection(range: index(lower)..<index(upper))
    }

    /// Wraps the selection in `marker`, or unwraps it if it is already wrapped.
    /// With nothing selected it inserts the pair and drops the cursor between
    /// them, so tapping **B** and typing does what you would expect.
    private func wrap(_ marker: String) {
        let (lower, upper) = selectedOffsets
        let selected = String(text[index(lower)..<index(upper)])
        let n = marker.count

        if selected.count >= 2 * n, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            text.replaceSubrange(index(lower)..<index(upper),
                                 with: String(selected.dropFirst(n).dropLast(n)))
            setSelection(lower, upper - 2 * n)
        } else {
            text.replaceSubrange(index(lower)..<index(upper), with: marker + selected + marker)
            if selected.isEmpty {
                setSelection(lower + n, lower + n)
            } else {
                setSelection(lower + n, upper + n)
            }
        }
    }

    /// Adds `prefix` to the start of the current line, removes it again if it
    /// is already there, and replaces any competing block prefix.
    private func toggleLinePrefix(_ prefix: String) {
        let (lower, upper) = selectedOffsets
        let lineStart = lineStartOffset(at: lower)
        let line = text[index(lineStart)...]
        let existing = Self.blockPrefixes.first { line.hasPrefix($0) }

        var delta = 0
        if let existing {
            text.removeSubrange(index(lineStart)..<index(lineStart + existing.count))
            delta -= existing.count
        }
        if existing != prefix {
            text.insert(contentsOf: prefix, at: index(lineStart))
            delta += prefix.count
        }
        setSelection(max(lower + delta, lineStart), max(upper + delta, lineStart))
    }

    /// Turns the selection into `[selection](url)` and selects the placeholder,
    /// so the next thing typed replaces it.
    private func insertLink() {
        let (lower, upper) = selectedOffsets
        let selected = String(text[index(lower)..<index(upper)])
        text.replaceSubrange(index(lower)..<index(upper), with: "[\(selected)](url)")

        let placeholder = lower + selected.count + 3   // past "[selected]("
        setSelection(placeholder, placeholder + 3)
    }

    private func lineStartOffset(at offset: Int) -> Int {
        let upToCursor = text[text.startIndex..<index(offset)]
        guard let newline = upToCursor.lastIndex(of: "\n") else { return 0 }
        return text.distance(from: text.startIndex, to: newline) + 1
    }
}

#Preview {
    @Previewable @State var text = "# Heading\n\nSome **bold** text.\n\n- a list item\n"
    return NavigationStack {
        MarkdownEditor(text: $text)
    }
}
