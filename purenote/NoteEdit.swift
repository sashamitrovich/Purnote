//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteEdit: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @State var note: Note
    /// Character offset the editor should open at, from the block the reader
    /// tapped on the rendered page.
    var initialCaret: Int? = nil
    @Environment(\.dismiss) private var dismiss

    /// The editor's own copy of the text.
    ///
    /// This has to be real @State holding a String. Note is a class, so a
    /// binding that only writes `note.content` mutates an object in place and
    /// SwiftUI is never told anything changed -- the editor then does not see
    /// edits the app itself makes, and an edit applied during typing (Return
    /// continuing a list) arrived late and twice. A new note was bound to
    /// @State and behaved correctly, which is what gave the bug away.
    ///
    /// Seeded here rather than in onAppear: the text view is built before
    /// onAppear runs, so filling it later meant the caret was placed in an
    /// empty string and every tap opened the note at the very top.
    @State private var draft: String

    /// The text the note had when editing opened (or when it was last
    /// finished). The file name was derived from its first line, and autosave
    /// overwrites the stored content while typing, so it has to be kept here to
    /// tell a name the app made from one the user chose.
    @State private var titleSource: String

    /// The text the note had when the editor opened, to tell whether Done
    /// finishes a real edit (see RatingPrompt).
    private let openedWith: String

    /// Undo / Redo state of the editor, shown in the top bar.
    @StateObject private var editor = EditorController()

    init(note: Note, initialCaret: Int? = nil) {
        _note = State(initialValue: note)
        _draft = State(initialValue: note.content)
        _titleSource = State(initialValue: note.content)
        openedWith = note.content
        self.initialCaret = initialCaret
    }

    var body: some View {
        NavigationStack {

            MarkdownEditor(text: $draft, initialCaret: initialCaret,
                           saveImage: { data, ext in try savePickedImage(data, ext) },
                           controller: editor)
                // the note and the list are kept in step with the buffer, which
                // is what the old binding's setter used to do on every keystroke
                .onChange(of: draft) { _, newValue in
                    note.content = newValue
                    if let index = data.notes.firstIndex(where: { $0.id == note.id }) {
                        data.notes[index].content = newValue
                    }
                }
                .autosaving(draft, save: { save() }, finish: { finish() })
                // inside the stack: the NavigationStack paints an opaque
                // system background over anything set on it from outside
                .background(Color.pn.page.ignoresSafeArea())
                .toolbar {
                    EditorUndoRedoToolbar(controller: editor)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            finish()
                            if draft != openedWith { RatingPrompt().recordSuccess() }
                            dismiss()
                        } label: {
                            Text("Done").bold()
                        }
                    }
                }
        }
    }

    func save() {
        data.persist(note)
        data.refresh(url: data.getCurrentUrl())
        // only this note is re-read, off the main thread
        index.update(path: note.url.path)
    }

    /// Saves a picked image into the note's assets folder. The note is
    /// persisted first so it has a real file URL to derive the folder from.
    private func savePickedImage(_ imageData: Data, _ ext: String) throws -> String {
        data.persist(note)
        return try NoteAssets.addImage(imageData, fileExtension: ext, to: note.url)
    }

    /// Editing is over: this is when the file may be renamed to match its
    /// first line.
    func finish() {
        let pathBefore = note.url.path
        data.finishEditing(note, previousContent: titleSource)
        // from here on the file name stands for what the note says now -- but
        // only if the rename went through, or there was nothing to rename to
        if NoteNaming.mayRename(stem: note.url.deletingPathExtension().lastPathComponent,
                                previousContent: note.content) {
            titleSource = note.content
        }
        data.refresh(url: data.getCurrentUrl())
        // the file may have been renamed to match its first line
        if note.url.path != pathBefore { index.rename(from: pathBefore, to: note.url.path) }
        index.update(path: note.url.path)
    }
}

//struct NoteDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        NoteEdit(note: DataManager.sampleDataManager().notes[0] , showSheetView: .constant(true) ).environmentObject(DataManager.sampleDataManager())
//    }
//}
