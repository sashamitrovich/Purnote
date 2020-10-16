//
//  RootView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI
import SwiftUIRefresh

struct RootView: View {
//    @EnvironmentObject var data: DataManager
    var  data: DataManager
    @State private var isShowing = false
    
    var body: some View {
        NavigationView {
            MenuView(data: data)
//                .environmentObject(data)
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
        }.pullToRefresh(isShowing: $isShowing) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                data.refresh(url: data.getCurrentUrl())
                isShowing = false
            }
        }
    }
    
    private var profileButton: some View {
        Button(action: { }) {
            Image(systemName: "person.crop.circle")
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(data: DataManager()).environmentObject(DataManager())
    }
}
