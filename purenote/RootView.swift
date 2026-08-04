//
//  RootView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI

struct RootView: View {
    var  data: DataManager
    @EnvironmentObject var index:SearchIndex
    
    var body: some View {
        NavigationStack {

                MenuView()
                    .environmentObject(index)
                    .environmentObject(data)
        }
        .tint(.accentColor)
    }
    
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(data: DataManager.sampleDataManager())
            .environmentObject(SearchIndex(rootUrl: URL(fileURLWithPath: "/notes")))
        
    }
}

