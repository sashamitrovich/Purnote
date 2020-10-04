//
//  Data.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import Foundation

struct Book: Identifiable, Equatable {
    static func == (lhs: Book, rhs: Book) -> Bool {
        return lhs.title == rhs.title
    }
    
    var id = UUID()
    var title: String=""
    
    fileprivate init(title:String) {
        self.id=UUID()
        self.title = title
    }
    
    init() {
        self.id=UUID()
        self.title = ""
    }
}


class Data: ObservableObject {
    @Published var book : [Book]
    
    func addBook(title: String) ->  Book {
        let newBook = Book (title: title)
        book.append(newBook)
        return newBook
    }
    
    func addBook(newBook: Book) {
        book.append(newBook)
    }
    
    init() {
        book=[]
        book.append(Book(title: "Great Expectations"))
        book.append(Book(title: "Catcher in the Rye"))
        book.append(Book(title: "The Post Office"))
    }
}
