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
