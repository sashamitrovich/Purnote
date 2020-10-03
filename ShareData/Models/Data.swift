//
//  Data.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import Foundation

struct Book: Identifiable  {
    var id = UUID()
    var title: String
    
    init(title:String) {
        self.title = title
    }
}


class Data: ObservableObject {
    @Published var book : [Book]
    
    init() {
        book=[]
        book.append(Book(title: "Great Expectations"))
        book.append(Book(title: "Catcher in the Rye"))
        book.append(Book(title: "The Post Office"))
    }
}
