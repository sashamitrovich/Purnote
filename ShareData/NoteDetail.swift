//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteDetail: View {
    @EnvironmentObject var data: Data
    var note: Note
    
    var noteIndex: Int {
        data.note.firstIndex(where: { $0.id == note.id })!
    }
    
    var body: some View {
        TextEditor(text: $data.note[self.noteIndex].content )
    }
}

struct NoteDetail_Previews: PreviewProvider {
    static var previews: some View {
        let data = Data()
        NoteDetail(note:data.note[0]).environmentObject(data)
    }
}
