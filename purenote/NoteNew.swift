//
//  NewBook.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteNew: View {
    @EnvironmentObject var data: DataManager
    //    @State var newNote: Note
    @State var newNote: Note
    
    
    var body: some View {
        VStack {
            
            TextEditor(text: $newNote.content)

            
        }
        .onAppear(perform: {
            newNote=Note(type: .Note)
            }
        )
        .onDisappear(perform: {
            if newNote.content != "" {
                data.addSaveNote(newNote: &newNote)
            }
        })
    }
}

struct NewNote_Previews: PreviewProvider {
    @State static var newNote = Note(type: .Folder)
    static var previews: some View {
        let newNote = Note(type: .Folder)
        NoteNew(newNote: newNote).environmentObject(DataManager())
    }
}
