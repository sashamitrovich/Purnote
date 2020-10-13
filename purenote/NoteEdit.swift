//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteEdit: View {
    @EnvironmentObject var data: DataManager
    @State var note: Note
    
    var noteIndex: Int {
        data.notes.firstIndex(where: { $0.id == note.id }) ?? 0
    }

    var body: some View {
        VStack {
            TextEditor(text: $note.content)
        }.onDisappear(perform: {
            data.updateNote(note: note)
        })
    }
}

//struct NoteDetail_Previews: PreviewProvider {
//    static var previews: some View {
//
//        NoteDetail(index: 0).environmentObject(DataManager())
//    }
//}
