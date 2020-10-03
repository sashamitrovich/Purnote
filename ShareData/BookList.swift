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
//                        Text(book.title)
                        ListRow(book: book)
                    }
                    
                    
                }
            }.navigationBarTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button(action: {
                        print("Edit button was tapped")
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

struct BookList_Previews: PreviewProvider {
    static var previews: some View {
        BookList().environmentObject(Data())
    }
}
