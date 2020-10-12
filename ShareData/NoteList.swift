//
//  NoteList.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI
import SwiftUIRefresh // big thanks to https://github.com/siteline/SwiftUIRefresh

struct NoteList: View {
    @EnvironmentObject var data: DataManager
    @State private var isShowing = false

    
    var body: some View {
        
        NavigationView {
            List {
                ForEach(data.folders) { folder in
                    Button( folder.id) {
                        data.refresh(url: folder.url)
                    }
                }
                
                ForEach(data.notes.indices, id: \.self) { index in
                    if data.notes[index].isLocal  {
                        NavigationLink(destination: NoteEdit(note: data.notes[index])) {
                            ListRow(note: data.notes[index])
                        }
                    }
                    else {
                        DownloadiCloudItemView(index: index)
                    }
                }.onDelete(perform: deleteItems)
            }.pullToRefresh(isShowing: $isShowing) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    data.refresh()
                    isShowing = false
                    
                }
            }
            .navigationBarTitle(data.getCurrentUrl().lastPathComponent)
            .navigationBarItems(trailing:
                HStack {
                    Button(action: {}) {Image(systemName: "plus.rectangle.on.folder")}
                    Spacer(minLength: 15)
                                        
                    NavigationLink(destination: NoteNew(newNote: Note(type: .Note)), label: { Image(systemName: "square.and.pencil") }
                    ).isDetailLink(true)
                }
                                
            )
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        
        for offset in offsets.enumerated() {
            do {
                try FileManager.default.trashItem(at: data.notes[offset.offset].url, resultingItemURL: nil)
            }
            catch {
                // failed
                print("Unexpected error: \(error).")
            }
            
        }
        data.notes.remove(atOffsets: offsets)
        
    }
}



struct NoteList_Previews: PreviewProvider {
    static var previews: some View {
        NoteList()
            .environmentObject(DataManager())
    }
}
