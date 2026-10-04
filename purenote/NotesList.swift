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
    @State private var noteToMove: Note?
    var isSearching = false
    
    func delete(_ note: Note) {
        do {
            try CoordinatedFile.trash(note.url)
            try NoteAssets.trashAssetsFolder(forNoteAt: note.url)
        }
        catch {
            // failed
            print("Failed to delete note: \(error).")
        }
        data.notes.removeAll { $0.id == note.id }
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
                Button {
                    noteToMove = note
                } label: {
                    Text("Move Note")
                    Image(systemName: "folder")
                }
                Button(role: .destructive) {
                    delete(note)
                } label: {
                    Text("Delete Note")
                    Image(systemName: "trash")
                }
            }
            .draggable(note.url.path)
            .showIf(condition: note.isLocal)
            
            ICloudItemView(note : note)
                .environmentObject(self.data)
                .environmentObject(self.index)
                .frame(maxWidth: .infinity, alignment: .leading).showIf(condition: !note.isLocal)

        }
        .padding(.leading, 5.0)
        .sheet(item: $noteToMove) { note in
            MoveNoteSheet(note: note)
                .environmentObject(data)
                .environmentObject(index)
        }
        
        VStack {
            HStack {
                Text("Tap the")
                Image(systemName: "square.and.pencil")
                Text("button to create a new note")
            }.placeholderForegroundColor()
        }.showIf(condition: data.notes.count == 0 && !isSearching)
    }
}
