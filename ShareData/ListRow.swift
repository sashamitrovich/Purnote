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
            Text(book.id.uuidString)
                .fontWeight(.heavy)
                .multilineTextAlignment(.leading)
            Text(book.title)
                .font(.title)
        }
        .frame(width: 300.0, height: 70.0)
        
    }
}

struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        let data = Data()
        ListRow(book: data.book[1])
    }
}
