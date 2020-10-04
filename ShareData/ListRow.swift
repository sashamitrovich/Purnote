//
//  ListRow.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct ListRow: View {
    var book: Book
    

    var body: some View {
        
        VStack(alignment: .leading) {
            Text(dateToString(date: book.date))
                .fontWeight(.light)
                .multilineTextAlignment(.leading)
            Text(book.title)
                .font(.title2)
        }
        .frame(width: 300.0, alignment: .leading)
        
    }
    
    // need to format the date
    func dateToString( date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        let data = Data()
        ListRow(book: data.book[1])
    }
}
