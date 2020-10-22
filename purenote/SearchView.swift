//
//  SearchView.swift
//  purenote
//
//  Created by Saša Mitrović on 21.10.20.
//

import SwiftUI

struct SearchView: View {
    @Binding var searchText: String
    var data: DataManager
//        = DataManager()
    
    var body: some View {
        
        Group {
            SearchBar(text: $searchText, placeholder: "Search your notes here")
                                    
            NoteView(isSearching: true).environmentObject(data.search(searchText: searchText))
                .showIf(condition: searchText != "")
        }
    }
}


struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(searchText: .constant(""), data: DataManager.sampleDataManager()).environmentObject(DataManager.sampleDataManager())
    }
}
