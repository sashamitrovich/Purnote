//
//  MenuView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI


// elegant solutino for avoiding nesting views
struct MenuView: View {
    @EnvironmentObject var data: DataManager
    
    var body: some View {
        List {
            PinnedView()
            FolderView()
            NoteView()
        }.navigationBarTitle(Text("Purenote"), displayMode: .automatic)
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView().environmentObject(DataManager())
    }
}
