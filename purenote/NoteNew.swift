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

    var body: some View {

        NavigationStack {
            VStack {


                // because no support for placeholder
                // inspired by: https://lostmoa.com/blog/AddPlaceholderTextToSwiftUITextEditor/
                ZStack(alignment: .topLeading) {


                    MarkdownEditor(text: $newNote.content)

                }
                .autosaving(newNote.content) { save() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            save()
                            self.isEditing = false
                        } label: {
                            Text("Done").font(.title2).foregroundColor(Color(UIColor.systemOrange))
                        }
                    }
                }


            }
            .onAppear(perform: {
                newNote=Note(type: .Note)
            }
            )
        }
    }

    /// Creates the file on the first save and updates it after that, so a new
    /// note survives the app being swiped away before Done is ever tapped.
    /// An untouched note is never written -- opening the editor and backing
    /// straight out should not leave an empty file behind.
    func save() {
        guard !newNote.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        data.persist(newNote)
        data.refresh(url: data.getCurrentUrl())
        index.indexall()
    }
}

struct NewNote_Previews: PreviewProvider {
    @State static var newNote = Note(type: .Folder)
    static var previews: some View {
        NoteNew(isEditing: .constant(true), newNote: DataManager.sampleDataManager().notes[0]).environmentObject(DataManager.sampleDataManager())
    }
}
