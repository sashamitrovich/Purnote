//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteEdit: View {
    @EnvironmentObject var data: DataManager
    var fromPinned:Bool
    var note: Note
    
    var noteIndex: Int {
        if fromPinned == true {
            return data.pinned.firstIndex(where: { $0.id == note.id })!
        }
        else {
            return data.notes.firstIndex(where: { $0.id == note.id })!
        }
    }

    var body: some View {
        VStack {
            if fromPinned == true {
                TextEditor(text: $data.pinned[noteIndex].content)
            }
            else {
                TextEditor(text: $data.notes[noteIndex].content)
            }

        }.onDisappear(perform: {
            data.updateNote(index: noteIndex)
        })
    }
}

struct NoteDetail_Previews: PreviewProvider {
    static var previews: some View {

        NoteEdit(fromPinned: false, note: Note.sampleNote1 )
    }
}
