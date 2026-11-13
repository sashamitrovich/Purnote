//
//  NoteView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI
import MarkdownUI

/// Where a tap asked the editor to put the caret.
private struct EditRequest: Identifiable {
    let id = UUID()
    let caret: Int
}

struct NoteView: View {


    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @EnvironmentObject var monitor: iCloudMonitor
    @Environment(\.dismiss) private var dismiss
    var note:Note
    /// The Undo toast of the screen this note was opened from: a delete here
    /// pops back to that screen, which shows the toast. Passed in, not read from
    /// the environment: a pushed screen does not see objects the list it came
    /// from put in the environment (reading it crashed the app, "No
    /// ObservableObject of type UndoToastModel found"). Nil where the note is
    /// opened from a screen with no toast (tags, smart folders): Delete is then
    /// not offered.
    var toast: UndoToastModel?
    /// Content read straight off disk after iCloud reported a change. The
    /// enclosing MenuView stops refreshing once a note is pushed on top of it,
    /// so without this a note edited on the Mac stayed stale exactly while you
    /// were looking at it.
    @State private var liveContent: String?
    /// A request to open the editor, carrying where the caret should go.
    ///
    /// The offset travels *with* the presentation rather than in a second piece
    /// of state beside it: set separately, it had not arrived by the time the
    /// editor was built, so every tap opened the note at its end.
    @State private var editing: EditRequest?
    @State var text = "some content to edit"
    @State private var showingMove = false
    /// A failed delete or duplicate, said here.
    @State private var alert: TrashAlert?


    /// The note as the list currently knows it, falling back to the copy this
    /// view was handed. Looking it up by index and force unwrapping crashed
    /// whenever a note was deleted or renamed on the Mac while it was open
    /// here -- which, for an app whose files are meant to be edited elsewhere,
    /// is ordinary rather than exceptional.
    var content: String {
        liveContent ?? data.notes.first(where: { $0.id == note.id })?.content ?? note.content
    }

    /// The note's source, writeable. Ticking a checkbox on the rendered page
    /// goes through here: straight to the file, the way an edit in the editor
    /// would, so the tap IS the change rather than view state to be saved later.
    private var sourceBinding: Binding<String> {
        Binding(
            get: { content },
            set: { newValue in
                guard newValue != content else { return }
                writeTick(from: content, to: newValue)
            }
        )
    }

    /// A tick changes exactly one line of the text this page shows. The same
    /// line is changed in what is on disk NOW and that is what gets written:
    /// the page may be minutes old, and writing its text back would undo
    /// whatever the Mac (or iCloud) did to the file since. If the line is no
    /// longer there the file was changed under the tap, so nothing is written
    /// and the page shows the file as it is.
    private func writeTick(from shown: String, to ticked: String) {
        let shownLines = shown.components(separatedBy: "\n")
        let tickedLines = ticked.components(separatedBy: "\n")
        var text = ticked
        if shownLines.count == tickedLines.count,
           let changed = shownLines.indices.first(where: { shownLines[$0] != tickedLines[$0] }),
           let fresh = try? CoordinatedFile.read(note.url) {
            let freshLines = fresh.components(separatedBy: "\n")
            let line: Int?
            if freshLines.indices.contains(changed), freshLines[changed] == shownLines[changed] {
                line = changed
            } else {
                let same = freshLines.indices.filter { freshLines[$0] == shownLines[changed] }
                line = same.count == 1 ? same[0] : nil
            }
            guard let line else { reloadFromDisk(); return }
            text = MarkdownBlocks.toggleTask(in: fresh, line: line)
            guard text != fresh else { reloadFromDisk(); return }
        }

        liveContent = text
        note.content = text
        if let i = data.notes.firstIndex(where: { $0.id == note.id }) {
            data.notes[i].content = text
        }
        do {
            try CoordinatedFile.write(text, to: note.url)
        } catch {
            // the tick stays on screen but did not reach the file; not
            // worth an alert, and the next edit will carry it
            print("Failed to write toggled checkbox: \(error).")
        }
        index.update(path: note.url.path)
    }

    private func reloadFromDisk() {
        guard let updated = try? CoordinatedFile.read(note.url) else { return }
        liveContent = updated
        note.content = updated
    }

    /// Opens the editor at the given offset. The iCloud cache is dropped
    /// first: editing rewrites the note (and a rename rewrites the image
    /// references), so a stale cached copy would render the wrong images.
    private func openEditor(at offset: Int) {
        liveContent = nil
        editing = EditRequest(caret: offset)
    }

    /// The widest the text column gets. On an iPad or a landscape phone a
    /// full-width line of New York is too long to read; the column is centred.
    static let maxColumnWidth: CGFloat = 640

    private var isPinned: Bool { data.isPinned(note) }

    private var kicker: String {
        NoteKicker.text(folder: NoteKicker.folderName(of: note.url, libraryRoot: index.rootUrl),
                        modified: NoteDates.modified(of: note.url))
    }

    var body: some View {

        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kickerLine
                    NoteBody(source: sourceBinding,
                             noteDirectory: note.url.deletingLastPathComponent(),
                             onTapBlock: { offset in
                                 openEditor(at: offset)
                             })
                        .padding(.top, 10.0)
                        .environmentObject(data)
                        .environmentObject(index)
                        .onChange(of: monitor.changeCount) { reloadFromDisk() }
                    let tags = TagScanner.tags(in: content)
                    if !tags.isEmpty {
                        TagChipsRow(tags: tags)
                            .padding(.top, 24)
                    }
                }
                .frame(maxWidth: Self.maxColumnWidth, alignment: .topLeading)
                .padding(.horizontal, 20.0)
                // fill the height of the scroll view so the tap target is
                // the whole page, not just the glyphs. Tapping the empty
                // space below a short note now opens the editor too, which
                // is where a tap most obviously means "let me write here".
                // The column is capped, then centred in the full width.
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
            }
            .scrollContentBackground(.hidden)
            .background(Color.pn.page)
        }
        // the gesture and the cover live on the ScrollView, so the whole
        // visible area is tappable rather than only the rendered text
        .contentShape(Rectangle())
        .onTapGesture {
            // a tap on the empty space below the note means "write at the end",
            // which is where a new thought goes
            openEditor(at: content.count)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit") { openEditor(at: content.count) }
                    .accessibilityIdentifier("note.edit")
                moreMenu
            }
        }
        .fullScreenCover(item: $editing) { request in
            NoteEdit(note: note, initialCaret: request.caret)
                .environmentObject(data)
                .environmentObject(index)
        }
        .sheet(isPresented: $showingMove, onDismiss: popIfMoved) {
            MoveNoteSheet(note: note)
                .environmentObject(data)
                .environmentObject(index)
        }
        .alert(alert?.title ?? "",
               isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alert?.message ?? "")
        }
    }

    // MARK: - Kicker

    /// "[ribbon] JOURNAL · EDITED TODAY, 07:40": small SF capitals above the title.
    private var kickerLine: some View {
        HStack(alignment: .center, spacing: 8) {
            if isPinned {
                RibbonShape()
                    .fill(Color.pn.ribbon)
                    .frame(width: 11, height: 17)
                    .accessibilityLabel("Pinned")
                    .accessibilityIdentifier("note.ribbon")
            }
            Text(kicker)
                .font(PurnoteType.Twin.caps())
                .tracking(PurnoteType.capsTracking)
                .textCase(.uppercase)
                .foregroundColor(Color.pn.ink2)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("note.kicker")
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The "..." menu

    private var moreMenu: some View {
        Menu {
            Section {
                ShareLink(item: note.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("note.share")
                Button {
                    UIPasteboard.general.string = content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("note.copy")
                if data.libraryRoot != nil {
                    Button {
                        data.togglePin(note)
                    } label: {
                        Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                    }
                    .accessibilityIdentifier("note.pin")
                }
            }
            Section {
                Button {
                    duplicate()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .accessibilityIdentifier("note.duplicate")
                Button {
                    showingMove = true
                } label: {
                    Label("Move to Folder\u{2026}", systemImage: "folder")
                }
                .accessibilityIdentifier("note.move")
            }
            if toast != nil {
                Section {
                    Button(role: .destructive) {
                        deleteNote()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("note.delete")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("Note actions")
        .accessibilityIdentifier("note.more")
    }

    // MARK: - Actions

    /// A copy beside the note ("<name> 2.md", pictures included), then back to the list,
    /// where the copy now is.
    private func duplicate() {
        do {
            let copy = try NoteDuplicate.duplicate(noteAt: note.url, content: content)
            index.update(path: copy.path)
            data.refresh(url: data.getCurrentUrl())
            dismiss()
        } catch {
            alert = TrashAlert(title: "Could not duplicate",
                               message: "\(error.localizedDescription) Nothing was copied.")
        }
    }

    /// Moves the note to Recently Deleted through the same path as the list's
    /// Delete (UndoToastModel.delete), then goes back to the list, where the
    /// Undo toast is. A delete that failed stays here with an alert: the
    /// screen behind owns the toast's alert, and an alert on a covered screen
    /// is not shown.
    private func deleteNote() {
        guard let toast else { return }
        // a note opened from search or a tag may come with a DataManager that
        // has no library behind it; the library root says where it is trashed from
        let source = data.libraryRoot == nil
            ? DataManager(searchNotes: [note], libraryRoot: index.rootUrl)
            : data
        let before = toast.current?.id
        toast.delete(note: note, from: source, index: index)
        if toast.current?.id != before {
            // in the trash (even when its pictures stayed behind: the toast's alert says so)
            dismiss()
        } else if let failure = toast.alert {
            toast.alert = nil
            alert = failure
        }
    }

    /// After the Move sheet: a note that is no longer at its address would be
    /// written back to the old place by the next edit, so leave it.
    private func popIfMoved() {
        if !FileManager.default.fileExists(atPath: note.url.path) { dismiss() }
    }

}


/// The reading view's type, in one place: the theme below draws with it and
/// NoteBody's hit test lays text out with it, so the two cannot drift.
///
/// Serif body (spike S5): New York 17 pt, scaling with Dynamic Type as the
/// body style does. If the S5 acceptance check fails, set `usesSerifBody` to
/// false: the body goes back to the shipped SF at the editor's 19 pt (and the
/// headings to their shipped scale), headings stay in New York.
enum NoteBodyStyle {
    static let usesSerifBody = true

    /// Body size at the Large content size.
    static var baseSize: CGFloat { usesSerifBody ? PurnoteType.bodyPoints : MarkdownTextView.baseFontSize }

    /// Heading sizes as multiples of the body (type scale: 34, 22, 18 over a 17 body).
    static var h1Scale: CGFloat { usesSerifBody ? 34.0 / 17.0 : 1.8 }
    static var h2Scale: CGFloat { usesSerifBody ? 22.0 / 17.0 : 1.4 }
    static var h3Scale: CGFloat { usesSerifBody ? 18.0 / 17.0 : 1.15 }
    /// Quote: New York italic 18 over the 17 body.
    static var quoteScale: CGFloat { usesSerifBody ? 18.0 / 17.0 : 1.0 }
    /// Table cells: SF 15 over the 17 body (0.85 as shipped).
    static var tableScale: CGFloat { usesSerifBody ? 15.0 / 17.0 : 0.85 }
    /// Code: SF Mono 14 over the 17 body.
    static var codeScale: CGFloat { usesSerifBody ? 14.0 / 17.0 : 0.9 }
}

extension Theme {
    /// Purnote's rendering: the basic theme with a tighter vertical rhythm
    /// (notes usually open with a heading, so 1.5rem of space above it is
    /// wasted), links in the app's amber (ribbonText), and the type scale of
    /// direction B (see NoteBodyStyle).
    static let purnote = Theme.basic
        // the body text. Dynamic Type scales this base size (MarkdownUI wraps
        // it in a ScaledMetric relative to .body); NoteBody's hit test scales
        // the same size with UIFontMetrics(.body).
        .text {
            FontFamily(.system(NoteBodyStyle.usesSerifBody ? .serif : .default))
            FontSize(NoteBodyStyle.baseSize)
        }
        .link {
            ForegroundColor(Color.pn.ribbonText)
        }
        // inline code: SF Mono, a step smaller than the text
        .code {
            FontFamily(.system(.monospaced))
            FontSize(.em(NoteBodyStyle.codeScale))
        }
        // a soft, rounded checkbox instead of the default hard SF square --
        // amber when ticked, a quiet hollow box when not
        .taskListMarker { configuration in
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(
                    configuration.isCompleted
                        ? Color.pn.ribbon
                        : Color.pn.ink3,
                    lineWidth: 1.7
                )
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(configuration.isCompleted ? Color.pn.ribbon : .clear)
                )
                .overlay {
                    if configuration.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 18, height: 18)
                .padding(.trailing, 4)
        }
        // Headings are set in a serif -- the same voice as the note titles in
        // the list. It is Purnote's one deliberate step away from the all-SF
        // look of Notes, and it reads warmer for something you sat down to write.
        .heading1 { configuration in
            configuration.label
                .accessibilityAddTraits(.isHeader)
                .markdownMargin(top: .rem(0.4), bottom: .rem(0.5))
                .markdownTextStyle {
                    FontFamily(.system(.serif))
                    FontWeight(.bold)
                    FontSize(.em(NoteBodyStyle.h1Scale))
                }
        }
        .heading2 { configuration in
            configuration.label
                .accessibilityAddTraits(.isHeader)
                .markdownMargin(top: .rem(0.9), bottom: .rem(0.4))
                .markdownTextStyle {
                    FontFamily(.system(.serif))
                    FontWeight(.semibold)
                    FontSize(.em(NoteBodyStyle.h2Scale))
                }
        }
        .heading3 { configuration in
            configuration.label
                .accessibilityAddTraits(.isHeader)
                .markdownMargin(top: .rem(0.8), bottom: .rem(0.3))
                .markdownTextStyle {
                    FontFamily(.system(.serif))
                    FontWeight(.semibold)
                    FontSize(.em(NoteBodyStyle.h3Scale))
                }
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: .zero, bottom: .rem(0.6))
        }
        // New York italic with an amber rule on the left. The rule is an
        // overlay, so the text keeps the basic theme's indent: the width the
        // hit test lays the block out in does not change.
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    FontStyle(.italic)
                    FontSize(.em(NoteBodyStyle.quoteScale))
                }
                .relativePadding(.leading, length: .em(2))
                .relativePadding(.trailing, length: .em(1))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.pn.ribbon)
                        .frame(width: 3)
                }
        }
        // Lighter tables: row hairlines only (no vertical rules, no outer
        // border), a semibold secondary header, and cell text in SF, a step
        // smaller, in tabular figures so a wide table fits the phone without wrapping.
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(.insideHorizontalBorders, color: Color.pn.rule))
                .markdownMargin(top: .zero, bottom: .rem(0.8))
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamily(.system(.default))
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                        ForegroundColor(Color.pn.ink2)
                    }
                    FontSize(.em(NoteBodyStyle.tableScale))
                    FontDigitVariant(.monospaced)
                }
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .padding(.vertical, 4)
                .padding(.trailing, 4)
        }
        // the default code block does not scroll, so long lines are simply
        // cut off at the right edge of the screen
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle {
                        FontFamily(.system(.monospaced))
                        FontSize(.em(NoteBodyStyle.codeScale))
                    }
                    .padding(10)
            }
            .background(Color.pn.fill)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: .zero, bottom: .rem(0.8))
        }
}

//struct NoteView_Previews: PreviewProvider {
//    static var previews: some View {
//        NoteView(note: DataManager.sampleNotes[0])
//    }
//}

enum ShowSheet
{
    case yes
    case no
}

extension ShowSheet: Identifiable {
    var id: ShowSheet { self }
}
