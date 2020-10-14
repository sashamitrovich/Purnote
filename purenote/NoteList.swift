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
                ForEach(data.pinned) { pinnedNote in
                    HStack {
                        NavigationLink(destination: NoteEdit(note: pinnedNote)) {
                            ListRow(note: pinnedNote).environmentObject(self.data)
                        }
                        
                        Button(action: {
                            withAnimation {
                                unpin()
                            }
                            
                        }, label: {
                            Image(systemName: "star.fill")
                        }).buttonStyle(PlainButtonStyle())
                    }
                }
                
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
                
                ForEach(data.notes) { note in
                    if note.isLocal  {
                        
                        HStack {
                            NavigationLink(destination: NoteEdit(note: note).environmentObject(self.data)) {
                                ListRow(note: note).environmentObject(self.data)
                            }
                            
                            Button(action: { withAnimation  {
                                guard data.pinned.count <= 1 else {
                                    print ("Unexpected size of data.pinned")
                                    return
                                }
                                
                                if (data.pinned.count == 1) {
                                    unpin()
                                }
                                
                                
                                
                                data.notes.removeAll(where: { $0.url.path == note.url.path })
                                data.pinned.append(note)
                                
                            } }, label: {
                                Image(systemName: "pin.fill")
                            }).buttonStyle(PlainButtonStyle())
                        }
                    }
                    else {
                        ICloudItemView(note : note).environmentObject(self.data)
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
                                        Button(action: {}) {
                                            Image(systemName: "plus.rectangle.on.folder").font(.title2)
                                            
                                        }
                                        Spacer(minLength: 15)
                                        
                                        NavigationLink(destination: NoteNew(newNote: Note(type: .Note)), label: { Image(systemName: "square.and.pencil").font(.title2) }
                                        ).isDetailLink(true)
                                    }
            )
        }
        // so that we can have an up-to-date list of items when the user brings the app back to the foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification), perform: { _ in
            data.refresh()
        })
    }
    
    func unpin() {
        
        // need to put back the note in the notes[]
        if data.pinned[0].url.deletingLastPathComponent().path == data.getCurrentUrl().path {
            data.notes.append(data.pinned.removeFirst())
        }
        // no need because it doesn't belong to this folder
        else {
            data.pinned.removeFirst()
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        
        for offset in offsets.enumerated() {
            do {
                try FileManager.default.trashItem(at: data.notes[offset.element].url, resultingItemURL: nil)
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
