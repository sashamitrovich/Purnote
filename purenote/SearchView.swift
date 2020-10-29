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
    @EnvironmentObject var data: DataManager
    @Binding var isSearching: Bool
    
    var body: some View {
        
            Group {
                HStack {
                    SearchBar(text: $searchText, placeholder: "Search your notes here")
                        .frame(maxWidth: 300)
                    Button("Cancel", action: {
                        isSearching.toggle()
                    })
                }
                
                SearchResultsView(notes: index.search(phrase: searchText), searchText: $searchText)
                    .environmentObject(index)
                    .environmentObject(data)
            }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(searchText: .constant("note"), isSearching: .constant(true))
            .environmentObject(SearchIndex(rootUrl: URL(fileURLWithPath: "/")))
            .environmentObject(DataManager.sampleDataManager())
    }
}
