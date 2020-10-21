//
//  SearchView.swift
//  purenote
//
//  Created by Saša Mitrović on 21.10.20.
//

import SwiftUI

struct SearchView: View {
    @Binding var searchText: String
    var data: DataManager = DataManager()
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText, placeholder: "Search your notes here")
            NoteView().environmentObject(data.search(searchText: searchText))
                .showIf(condition: searchText != "")
            
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(searchText: .constant("note")).environmentObject(DataManager.sampleDataManager())
    }
}
