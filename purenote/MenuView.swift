//
//  MenuView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI


// elegant solutino for avoiding nesting views
struct MenuView: View {
    var data: DataManager
    @State private var isShowing = false
    
    
    var body: some View {
        List {
     
            FolderView().environmentObject(data).padding(.bottom, 5.0)

            NoteView().environmentObject(data)
        }
        
        .navigationBarTitle(Text(data.getCurrentUrl().lastPathComponent), displayMode: .automatic)
        .navigationBarItems(trailing:
                                HStack {
                                    Button(action: {}) {
                                        Image(systemName: "plus.rectangle.on.folder").font(.title2)
                                        
                                    }
                                    Spacer(minLength: 15)
                                    
                                    NavigationLink(destination: NoteNew(newNote: Note(type: .Note)).environmentObject(self.data), label: { Image(systemName: "square.and.pencil").font(.title2) }
                                    ).isDetailLink(true)
                                }
        )
        .listStyle(PlainListStyle())
        .pullToRefresh(isShowing: $isShowing) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                data.refresh(url: data.getCurrentUrl())
                isShowing = false
            }
        }
    }
    
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(data: DataManager()).environmentObject(DataManager())
    }
}
