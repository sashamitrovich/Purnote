//
//  ContentView.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var data: Data
    @State var title: String
    
    var body: some View {
        TextField("Title", text: $title)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(title: "some title").environmentObject(Data())
    }
}
