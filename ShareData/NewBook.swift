//
//  NewBook.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NewBook: View {
    @EnvironmentObject var data: Data

    
    var body: some View {
        VStack {
            Text(data.book[data.book.count-1].id.uuidString)
            TextEditor(text: $data.book[data.book.count-1].title)
        }
        .onAppear(perform: {
            data.book.append(Book())
        }).onDisappear(perform: {
            if data.book[data.book.count-1].title == "" {
                data.book.remove(at: data.book.count-1)
            }
                
        })
    }
}

struct NewBook_Previews: PreviewProvider {
    @State static var newBook = Book()    
    static var previews: some View {
        NewBook().environmentObject(Data())
    }
}
