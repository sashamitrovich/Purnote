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

    init(note: Note, initialCaret: Int? = nil) {
        _note = State(initialValue: note)
        _draft = State(initialValue: note.content)
        self.initialCaret = initialCaret
    }

    var body: some View {
        NavigationStack {

            MarkdownEditor(text: $draft, initialCaret: initialCaret)
                // the note and the list are kept in step with the buffer, which
                // is what the old binding's setter used to do on every keystroke
                .onChange(of: draft) { _, newValue in
                    note.content = newValue
                    if let index = data.notes.firstIndex(where: { $0.id == note.id }) {
                        data.notes[index].content = newValue
                    }
                }
                .autosaving(draft, save: { save() }, finish: { finish() })
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            finish()
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
        index.indexall()
    }

    /// Editing is over: this is when the file may be renamed to match its
    /// first line.
    func finish() {
        data.finishEditing(note)
        data.refresh(url: data.getCurrentUrl())
        index.indexall()
    }
}

//struct NoteDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        NoteEdit(note: DataManager.sampleDataManager().notes[0] , showSheetView: .constant(true) ).environmentObject(DataManager.sampleDataManager())
//    }
//}
