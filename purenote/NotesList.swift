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
    @EnvironmentObject var toast: UndoToastModel
    @State private var noteToMove: Note?
    var isSearching = false

    /// Moves the note to Recently Deleted. The row goes and the Undo toast comes
    /// up; if the move fails the row stays and an alert says why.
    func delete(_ note: Note) {
        toast.delete(note: note, from: data, index: index)
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
            .menuRowStyle()
            .showIf(condition: note.isLocal)
            
            ICloudItemView(note : note)
                .environmentObject(self.data)
                .environmentObject(self.index)
                .frame(maxWidth: .infinity, alignment: .leading)
                .menuRowStyle()
                .showIf(condition: !note.isLocal)

        }
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
