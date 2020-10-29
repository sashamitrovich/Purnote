//
//  NoteView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI

struct NotesList: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @State var showingDirectoryPicker = false
    @State var noteToMove = Note(type: .Note)
    var isSearching = false
    
    func deleteItems(at offsets: IndexSet) {
        
        for offset in offsets.enumerated() {
            do {
                try FileManager.default.trashItem(at: data.notes[offset.element].url, resultingItemURL: nil)
            }
            catch {
                // failed
                print("Failed to delete notes: \(error).")
            }
            
        }
        data.notes.remove(atOffsets: offsets)
        index.indexall()
        
    }
    
    var body: some View {
        
        ForEach(data.notes) { note in
            NavigationLink(destination:
                            NoteView(note: note).environmentObject(data).environmentObject(index)
            ) {
                ListRow(note: note).environmentObject(self.data)
            }
            .contextMenu {
                Button(action: {
                    noteToMove = note
                    showingDirectoryPicker.toggle()
                }) {
                    Text("Move Note")
                    Image(systemName: "folder")
                }
            }                        
            .sheet(isPresented: $showingDirectoryPicker) {

                DocumentPickerViewController  { url in

                    let newNoteUrl : URL = url.appendingPathComponent(note.id)

                    do {
                        try FileManager.default.moveItem(at: noteToMove.url, to: newNoteUrl)
                    }
                    catch {
                        // failed
                        print("Failed to move file: \(error).")
                    }

                    data.refresh(url: data.getCurrentUrl())
                }

            }
            .showIf(condition: note.isLocal)
            
            ICloudItemView(note : note)
                .environmentObject(self.data)
                .environmentObject(self.index)
                .frame(maxWidth: .infinity, alignment: .leading).showIf(condition: !note.isLocal)

        }
        .onDelete(perform: deleteItems).padding(.leading, 5.0)
        
        VStack {
            HStack {
                Text("Tap the")
                Image(systemName: "square.and.pencil")
                Text("button to create a new note")
            }.placeholderForegroundColor()
        }.showIf(condition: data.notes.count == 0 && !isSearching)
    }
}
