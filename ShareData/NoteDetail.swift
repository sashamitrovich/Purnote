//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteDetail: View {
    @EnvironmentObject var data: DataManager
    var note: Note
    
    var noteIndex: Int {
        data.notes.firstIndex(where: { $0.id == note.id })!
    }
    
    var body: some View {
        TextEditor(text: $data.notes[self.noteIndex].content )
    }
}

struct NoteDetail_Previews: PreviewProvider {
    static var previews: some View {
        let data = DataManager()
        NoteDetail(note:data.notes[0]).environmentObject(data)
    }
}
