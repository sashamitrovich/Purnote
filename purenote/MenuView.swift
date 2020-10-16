//
//  MenuView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI


// elegant solutino for avoiding nesting views
struct MenuView: View {
//    @EnvironmentObject var data: DataManager
    var data: DataManager
    
    
    
    var body: some View {
        List {
            FolderView().environmentObject(data)
            NoteView().environmentObject(data)
        }.navigationBarTitle(Text("Purenote"), displayMode: .automatic)
       
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(data: DataManager()).environmentObject(DataManager())
    }
}
