//
//  ListRow.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct ListRow: View {
    @EnvironmentObject var data: DataManager
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
//                    .frame(alignment: .leading)
                    .lineLimit(1)
            }                        
        }
    }
    
}



struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        
        ListRow(note: Note.sampleNote1)
    
    }
}
