//
//  SearchView.swift
//  purenote
//
//  Created by Saša Mitrović on 21.10.20.
//

import SwiftUI

struct SearchView: View {
    @Binding var searchText: String
    @EnvironmentObject var index: SearchIndex
    @State var notes: [Note] = []
    
    var body: some View {
        
        Group {
            SearchBar(text: $searchText, placeholder: "Search your notes here")
            SearchResultsView(notes: index.search(phrase: searchText), searchText: $searchText)
                .environmentObject(index)
        }
    }
}

//struct SearchView_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchView(searchText: .constant("text"))
//            .environmentObject(DataManager.sampleDataManager())
//            .environmentObject(SearchIndex(rootUrl: URL(fileURLWithPath: "/")))
//    }
//}
