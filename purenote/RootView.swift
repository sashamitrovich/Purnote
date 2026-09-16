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
        // warm paper behind the bar too, so the title area reads as one sheet
        // with the list instead of the system grey/white
        .toolbarBackground(Color.purnotePaper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(data: DataManager.sampleDataManager())
            .environmentObject(SearchIndex(rootUrl: URL(fileURLWithPath: "/notes")))
        
    }
}

