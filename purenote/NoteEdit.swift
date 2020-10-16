//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteEdit: View {
    @EnvironmentObject var data: DataManager
    var note: Note
    
    var noteIndex: Int {
        data.notes.firstIndex(where: { $0.id == note.id })!
    }

    var body: some View {
        VStack {

            TextEditor(text: $data.notes[noteIndex].content)
           
        }.onDisappear(perform: {
            updateNote()
        })
    }
    
    func updateNote() {
        
        let documentURL = self.data.notes[noteIndex].url
        
        do {
            try self.data.notes[noteIndex].content.write(to: documentURL, atomically:true, encoding:String.Encoding.utf8)
        }
        catch {
            // failed
            print("Unexpected error, failed to update note: \(error).")
        }
    }
}

struct NoteDetail_Previews: PreviewProvider {
    static var previews: some View {

        NoteEdit(note: Note.sampleNote1 ).environmentObject(DataManager())
    }
}
