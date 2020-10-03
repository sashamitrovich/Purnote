//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct BookDetail: View {
    @EnvironmentObject var data: Data
    var book: Book
    
    var bookIndex: Int {
        data.book.firstIndex(where: { $0.id == book.id })!
    }
    
    var body: some View {
        TextEditor(text: $data.book[self.bookIndex].title )
    }
}

struct BookDetail_Previews: PreviewProvider {
    static var previews: some View {
        let data = Data()
        BookDetail(book:data.book[0]).environmentObject(data)
    }
}
