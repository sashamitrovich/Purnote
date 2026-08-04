//
//  NewBook.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteNew: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @Binding var isEditing: Bool
    @State var newNote: Note
    @FocusState private var editorFocused: Bool
    
    
    
    var body: some View {
        
        NavigationView {
            VStack {
                
                
                // because no support for placeholder
                // inspired by: https://lostmoa.com/blog/AddPlaceholderTextToSwiftUITextEditor/
                ZStack(alignment: .topLeading) {
                    
                    
                    TextEditor(text: $newNote.content)
                        .focused($editorFocused)
                                                            
                }
                .navigationBarItems(trailing:  Button(action: {
                    if newNote.content != "" {
                        data.addSaveNote(newNote: &newNote)
                        data.refresh(url: data.getCurrentUrl())
                        index.indexall()
                    }
                    self.isEditing = false
                    
                    
                }) {
                    Text("Done").font(.title2).foregroundColor(Color(UIColor.systemOrange))
                })
                
                
            }
            .onAppear(perform: {
                newNote=Note(type: .Note)
                editorFocused = true
            }
            )
        }
    }
}

struct NewNote_Previews: PreviewProvider {
    @State static var newNote = Note(type: .Folder)
    static var previews: some View {
        NoteNew(isEditing: .constant(true), newNote: DataManager.sampleDataManager().notes[0]).environmentObject(DataManager.sampleDataManager())
    }
}
