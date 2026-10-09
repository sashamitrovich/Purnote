//
//  MarkdownEditor.swift
//  purenote
//

import SwiftUI
import PhotosUI

/// A one-off request from the formatting bar to place the caret at an offset.
/// The `id` makes two asks to the same offset distinct, so a deferred re-ask
/// (after a Menu dismisses) is still applied rather than swallowed as a no-op.
struct CaretRequest: Equatable {
    let offset: Int
    let id = UUID()
}

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

    /// Saves a picked image and returns the Markdown path to reference it.
    var saveImage: (Data, String) throws -> String

    /// The selection in character offsets -- the same units MarkdownFormatter
    /// works in.
    @State private var selection: Range<Int> = 0..<0
    /// Where the formatting bar wants the caret, applied by the text view on
    /// its own schedule rather than by syncing the live selection binding.
    @State private var caretRequest: CaretRequest?
    @State private var showingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        MarkdownTextView(text: $text, selection: $selection, caretRequest: $caretRequest, initialCaret: initialCaret)
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
            .photosPicker(isPresented: $showingPhotoPicker,
                          selection: $photoPickerItem,
                          matching: .images)
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task { await insertPickedImage(item) }
            }
    }

    private var formattingBar: some View {
        // Fixed whenever every button fits; scrolls only when the row genuinely
        // needs more room than the screen offers (narrow devices, large text).
        // A plain ScrollView rubber-banded even when the content already fit,
        // so the bar could be nudged around with nothing to scroll to.
        ViewThatFits(in: .horizontal) {
            barRow
            ScrollView(.horizontal) {
                barRow
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: 46)
        .background(Color.purnotePaper2)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var barRow: some View {
        HStack(spacing: 20) {
            ForEach(visibleActions) { action in
                if let items = action.menuItems {
                    Menu {
                        ForEach(items) { item in
                            Button(item.name, action: item.run)
                        }
                    } label: {
                        icon(for: action)
                    }
                    .accessibilityLabel(action.name)
                } else {
                    Button(action: action.run) {
                        icon(for: action)
                    }
                    .accessibilityLabel(action.name)
                }
            }

            // The less-used actions (strikethrough, code, table) live in an
            // overflow menu, so the bar itself never scrolls on a modern phone.
            // Amber, so it reads as "more" rather than one more ink button.
            Menu {
                ForEach(overflowActions) { action in
                    if let items = action.menuItems {
                        Menu {
                            ForEach(items) { item in
                                Button(item.name, action: item.run)
                            }
                        } label: {
                            Label(action.name, systemImage: action.icon)
                        }
                    } else {
                        Button(action.name, action: action.run)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .imageScale(.large)
                    .foregroundColor(Color.accentColor)
                    .frame(minWidth: 24, minHeight: 34)
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 20)
    }

    private func icon(for action: Action) -> some View {
        Image(systemName: action.icon)
            .imageScale(.large)
            .foregroundColor(Color.primary.opacity(0.85))
            .frame(minWidth: 24, minHeight: 34)
    }

    // MARK: - Actions
    //
    // The most-used actions sit leftmost so they are visible without
    // scrolling. The three list styles share one "List" menu -- they used to be
    // three buttons that pushed Checklist (the one people actually want) off
    // the right edge where it was easy to miss. There is deliberately no
    // "hide keyboard" button: it only ever hid the keyboard (never re-opened
    // it), and the editor already dismisses the keyboard by swiping down.

    private struct Action: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let run: () -> Void
        /// When set, this action renders as a Menu holding these actions rather
        /// than as a button that runs directly.
        let menuItems: [Action]?

        init(name: String, icon: String, run: @escaping () -> Void) {
            self.name = name
            self.icon = icon
            self.run = run
            self.menuItems = nil
        }

        init(name: String, icon: String, menuItems: [Action]) {
            self.name = name
            self.icon = icon
            self.run = {}
            self.menuItems = menuItems
        }
    }

    /// The seven actions always visible on the bar: the ones people reach for
    /// first. The rest (strikethrough, code, table) sit in the overflow menu.
    private var visibleActions: [Action] {
        [
            Action(name: "Bold", icon: "bold") { wrap("**") },
            Action(name: "Italic", icon: "italic") { wrap("*") },
            Action(name: "Heading", icon: "textformat.size") { toggleLinePrefix("# ") },
            Action(name: "List", icon: "list.bullet", menuItems: [
                Action(name: "Bulleted list", icon: "list.bullet") { toggleLinePrefix("- ") },
                Action(name: "Numbered list", icon: "list.number") { toggleLinePrefix("1. ") },
                Action(name: "Checklist", icon: "checklist") { toggleLinePrefix("- [ ] ") },
            ]),
            Action(name: "Quote", icon: "text.quote") { toggleLinePrefix("> ") },
            Action(name: "Link", icon: "link", run: insertLink),
            Action(name: "Photo", icon: "photo") { showingPhotoPicker = true },
        ]
    }

    private var overflowActions: [Action] {
        [
            Action(name: "Strikethrough", icon: "strikethrough") { wrap("~~") },
            Action(name: "Code", icon: "chevron.left.forwardslash.chevron.right") { wrap("`") },
            Action(name: "Table", icon: "tablecells", menuItems: [
                Action(name: "2 × 2", icon: "tablecells") { insertTable(rows: 2, columns: 2) },
                Action(name: "3 × 2", icon: "tablecells") { insertTable(rows: 3, columns: 2) },
                Action(name: "3 × 3", icon: "tablecells") { insertTable(rows: 3, columns: 3) },
                Action(name: "4 × 4", icon: "tablecells") { insertTable(rows: 4, columns: 4) },
            ])
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

        // Ask the text view to place the caret. Two asks: once for the direct
        // buttons (the text change is enough to wake the view), and once after
        // the current event, because a Menu item's action runs while the menu
        // dismisses and focus returning to the text view can move the caret
        // back to where it was a moment later.
        caretRequest = CaretRequest(offset: result.lower)
        let offset = result.lower
        DispatchQueue.main.async {
            caretRequest = CaretRequest(offset: offset)
        }
    }

    /// Saves a picked image and inserts the Markdown reference at the caret.
    private func insertPickedImage(_ item: PhotosPickerItem) async {
        guard let rawData = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: rawData) else { return }

        // normalise to JPEG (PNG when the image has transparency) so the file
        // on disk is a plain, viewable image whatever the source format was
        let data: Data
        let ext: String
        if let jpeg = image.jpegData(compressionQuality: 0.9) {
            data = jpeg
            ext = "jpg"
        } else if let png = image.pngData() {
            data = png
            ext = "png"
        } else {
            return
        }

        do {
            let relativePath = try saveImage(data, ext)
            let (lower, upper) = selectedOffsets
            apply(MarkdownFormatter.insert(text, lower, upper,
                                           string: NoteAssets.imageMarkdown(relativePath: relativePath)))
        } catch {
            // the image did not make it to disk; leave the editor untouched
            print("Failed to save picked image: \(error).")
        }
    }

    /// Inserts a table skeleton of the given size at the caret.
    private func insertTable(rows: Int, columns: Int) {
        let (lower, upper) = selectedOffsets
        let skeleton = MarkdownFormatter.tableSkeleton(rows: rows, columns: columns)
        apply(MarkdownFormatter.insert(text, lower, upper, string: skeleton))
    }
}

#Preview {
    @Previewable @State var text = "# Heading\n\nSome **bold** text.\n\n- a list item\n"
    return NavigationStack {
        MarkdownEditor(text: $text, saveImage: { _, _ in "image.jpg" })
    }
}
