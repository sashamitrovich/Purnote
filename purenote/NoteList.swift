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

                    
                    Button(action: {
                        data.refresh(url: folder.url)
                                }) {
                                    HStack {
                                        if (folder.id == "..") {
                                            Image(systemName: "arrowshape.turn.up.left")
                                                .font(.title2)
                                        }
                                        else {
                                            Image(systemName: "folder")
                                                .font(.title2)
                                        }
                              
                                        Text(folder.id)
                                            .fontWeight(.semibold)
                                            .font(.title2)
                                    }

                                }
                }
                
                ForEach(data.notes.indices, id: \.self) { index in
                    if data.notes[index].isLocal  {
                        NavigationLink(destination: NoteEdit(note: data.notes[index])) {
                            ListRow(note: data.notes[index])
                        }
                    }
                    else {
                        ICloudItemView(index: index).environmentObject(self.data)
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
                    Button(action: {}) {Image(systemName: "plus.rectangle.on.folder").font(.title2)}
                    Spacer(minLength: 15)
                                        
                    NavigationLink(destination: NoteNew(newNote: Note(type: .Note)), label: { Image(systemName: "square.and.pencil").font(.title2) }
                    ).isDetailLink(true)
                }
                                
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification), perform: { _ in
            data.refresh() // so that we can have an up-to-date list of items when the user brings the app back to the foreground
        })
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
