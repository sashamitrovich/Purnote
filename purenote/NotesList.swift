//
//  NoteView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A Purnote-only drag type, so only our own note rows can be dropped onto
    /// a folder (never arbitrary text dragged in from another app).
    static let purnoteNote = UTType(exportedAs: "com.mitrovic.purenote.note")
}

struct NotesList: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @State private var noteToMove: Note?
    var isSearching = false
    
    func deleteItems(at offsets: IndexSet) {
        
        for offset in offsets.enumerated() {
            let url = data.notes[offset.element].url
            do {
                try CoordinatedFile.trash(url)
                try NoteAssets.trashAssetsFolder(forNoteAt: url)
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
                Button {
                    noteToMove = note
                } label: {
                    Text("Move Note")
                    Image(systemName: "folder")
                }
            }
            .onDrag {
                NSItemProvider(item: note.url.path as NSString,
                               typeIdentifier: UTType.purnoteNote.identifier)
            }
            .showIf(condition: note.isLocal)
            
            ICloudItemView(note : note)
                .environmentObject(self.data)
                .environmentObject(self.index)
                .frame(maxWidth: .infinity, alignment: .leading).showIf(condition: !note.isLocal)

        }
        .onDelete(perform: deleteItems).padding(.leading, 5.0)
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
