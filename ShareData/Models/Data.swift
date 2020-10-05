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
    
    var id: String
    var title: String
    var date: Date
    
    fileprivate init(title:String) {        
        self.init()
        self.title = title
    }
    
    init() {
        self.id=UUID().uuidString
        self.title = ""
        self.date = Date()
    }
    
    init(id:String, title:String) {
        self.id=id
        self.title=title
        self.date = Date()
    }
}


class Data: ObservableObject {
    @Published var book : [Book]
    
    let fm = FileManager.default
    
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
        
        let urls:[URL] = listFiles()
        
        urls.forEach { url in
            
            do {
                try book.append(Book(id: url.relativeString, title: String(contentsOf: url, encoding: .utf8) ))
            }
            catch {
                /* error handling here */
                print("Unexpected error: \(error).")
                
            }
        }
    }
    
    func getDocumentsPath() -> URL {
        var tryURL: URL!
        
        
        // First get the URL for the default ubiquity container for this app
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            tryURL = containerURL.appendingPathComponent("Documents")
            do {
                if (fm.fileExists(atPath: tryURL.path, isDirectory: nil) == false) {
                    try  fm.createDirectory(at: tryURL, withIntermediateDirectories: true, attributes: nil)
                }
                
                
            } catch {
                print("ERROR: Cannot create /Documents on iCloud")
            }
        } else {
            print("ERROR: Cannot get ubiquity container")
        }
        return tryURL
    }
    
    func listFiles () -> [URL] {
        var files:[String]=[]
        var urls:[URL]=[]
        
        let keys:[URLResourceKey]=[ URLResourceKey.nameKey, URLResourceKey.creationDateKey, URLResourceKey.contentModificationDateKey, URLResourceKey.fileSizeKey]
        
        
        do {
            //            try  files=fm.contentsOfDirectory(atPath: getDocumentsPath().path)
            try urls=fm.contentsOfDirectory(at: getDocumentsPath(), includingPropertiesForKeys: keys)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }

        
        return urls
    }
    
}
