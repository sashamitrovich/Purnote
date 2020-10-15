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
                Text("Pinned")
                    .font(.largeTitle)
                PinnedView()
                
                Text("Folders").font(.largeTitle)
                FolderView()
        
                
                Text("Notes").font(.largeTitle)
                    NoteView()

            }.pullToRefresh(isShowing: $isShowing) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    data.refresh(url: data.getCurrentUrl())
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
            data.refresh(url: data.getCurrentUrl())
        })
    }
        

}



struct NoteList_Previews: PreviewProvider {
    static var previews: some View {
        NoteList()
            .environmentObject(DataManager())
    }
}
