//
//  BookList.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct BookList: View {
    @EnvironmentObject var data: Data
    
    var body: some View {
        NavigationView {
            List {
                ForEach(data.book) { book in
                    NavigationLink(destination: BookDetail(book: book)) {
                        ListRow(book: book)
                    }
                }.onDelete(perform: deleteItems)
            }
            .navigationBarTitle("Notes")
            .navigationBarItems(trailing: NavigationLink(destination: NewBook(), label: { Image(systemName: "square.and.pencil") }
            ).isDetailLink(true)
            )
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        data.book.remove(atOffsets: offsets)
    }
}



struct BookList_Previews: PreviewProvider {
    static var previews: some View {
        BookList().environmentObject(Data())
    }
}
