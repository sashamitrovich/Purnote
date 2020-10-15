//
//  PinnedView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI

struct PinnedView: View {
    @EnvironmentObject var data: DataManager
    
    var body: some View {
     
            ForEach(data.pinned) { pinnedNote in
                HStack {
                    NavigationLink(destination: NoteEdit(fromPinned: true, note: pinnedNote)) {
                        ListRow(note: pinnedNote).environmentObject(self.data)
                    }
                    
                    Button(action: {
                        withAnimation {
                            data.unpin()
                        }
                        
                    }, label: {
                        Image(systemName: "star.fill").foregroundColor(.accentColor)
                    }).buttonStyle(PlainButtonStyle())
                }
            }.frame(alignment: .leading).padding(.leading, 5.0)
    }

}

struct PinnedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
        PinnedView().environmentObject(DataManager())
        }
    }
}
