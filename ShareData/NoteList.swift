//
//  BookList.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteList: View {
    @EnvironmentObject var data: Data
    
    var body: some View {
        
        NavigationView {
            List {
                ForEach(data.note) { note in
                    NavigationLink(destination: NoteDetail(note: note)) {
                        ListRow(note: note)
                    }
                }.onDelete(perform: deleteItems)
            }
            .navigationBarTitle("Notes")
            .navigationBarItems(trailing: NavigationLink(destination: NewNote(newNote: Note()), label: { Image(systemName: "square.and.pencil") }
            ).isDetailLink(true)
            )
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        data.note.remove(atOffsets: offsets)
    }
}



struct BookList_Previews: PreviewProvider {
    static var previews: some View {
        NoteList().environmentObject(Data())
    }
}
