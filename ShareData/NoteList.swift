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
                ForEach(data.note.indices, id: \.self) { index in
                    if data.note[index].isLocal  {
                        NavigationLink(destination: NoteDetail(note: data.note[index])) {
                            ListRow(note: data.note[index])
                        }
                    }
                    else {
                        DownloadiCloudItemView(index: index)
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
        
        for offset in offsets.enumerated() {
            do {
                try FileManager.default.trashItem(at: data.note[offset.offset].url, resultingItemURL: nil)
            }
            catch {
                // failed
                print("Unexpected error: \(error).")
            }
           
        }
        data.note.remove(atOffsets: offsets)
        
    }
}



struct BookList_Previews: PreviewProvider {
    static var previews: some View {
        NoteList().environmentObject(Data())
    }
}
