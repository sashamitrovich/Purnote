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
    @Environment(\.dismiss) private var dismiss

    /// Edits go through the note object itself rather than through an index
    /// into data.notes. The note can be deleted or renamed on the Mac while it
    /// is open here, and resolving it by index meant a crash when that
    /// happened -- on every keystroke, since the lookup was re-evaluated every
    /// time the binding was read.
    private var content: Binding<String> {
        Binding(
            get: { note.content },
            set: { newValue in
                note.content = newValue
                if let index = data.notes.firstIndex(where: { $0.id == note.id }) {
                    data.notes[index].content = newValue
                }
            }
        )
    }

    var body: some View {
        NavigationStack {

            MarkdownEditor(text: content)
                .autosaving(note.content) { save() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            save()
                            dismiss()
                        } label: {
                            Text("Done").font(.title2).foregroundColor(Color(UIColor.systemOrange))
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
}

//struct NoteDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        NoteEdit(note: DataManager.sampleDataManager().notes[0] , showSheetView: .constant(true) ).environmentObject(DataManager.sampleDataManager())
//    }
//}
