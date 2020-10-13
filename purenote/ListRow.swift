//
//  ListRow.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct ListRow: View {
    var note: Note
    
    
    var body: some View {
        
        HStack {
            VStack(alignment: .leading) {
                
                Text(note.date.toString())
                    .fontWeight(.light)
                    .multilineTextAlignment(.leading)
                Text(note.url.lastPathComponent).fontWeight(.thin)
                    .multilineTextAlignment(.trailing)
                
                Text(note.content)
                    .font(.title2)
                    .frame(alignment: .leading)
                    .lineLimit(1)
                
            }
            .frame(width: 300.0, alignment: .leading)
        }
    }
    
}

struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        //        let data = DataManager()
        ListRow(note: Note(content: "This is a nice looking note. Always wanted to write one like it.", date: Date(), path: "/notes/trips", isLocal: true, url: URL(fileURLWithPath: "/notes/trips/mynote.txt"), type: .Note))
    }
}
