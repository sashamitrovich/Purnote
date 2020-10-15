//
//  NoteView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI

struct NoteView: View {
    @EnvironmentObject var data: DataManager
    
    var body: some View {
      
            ForEach(data.notes) { note in
                if note.isLocal  {
                    
                    HStack {
                        NavigationLink(destination: NoteEdit(fromPinned: false,  note: note).environmentObject(self.data)) {
                            ListRow(note: note).environmentObject(self.data)
                        }
                        
                        Button(action: { withAnimation  {
                            guard data.pinned.count <= 1 else {
                                print ("Unexpected size of data.pinned")
                                return
                            }
                            
                            if (data.pinned.count == 1) {
                                
                                data.unpin() // this will also add it to the (normal) notes[]
                            }
                            
                            data.notes.removeAll(where: { $0.url.path == note.url.path })                            
data.pinned.append(note)
                            
                        } }, label: {
                            Image(systemName: "pin.fill")
                        }).buttonStyle(PlainButtonStyle())
                    }
                }
                else {
                    ICloudItemView(note : note).environmentObject(self.data)
                }
            }.onDelete(perform: deleteItems).padding(.leading, 5.0)
       
    }
    
    func deleteItems(at offsets: IndexSet) {
        
        for offset in offsets.enumerated() {
            do {
                try FileManager.default.trashItem(at: data.notes[offset.element].url, resultingItemURL: nil)
            }
            catch {
                // failed
                print("Unexpected error: \(error).")
            }
            
        }
        data.notes.remove(atOffsets: offsets)
        
    }
}

struct NoteView_Previews: PreviewProvider {
    static var previews: some View {
        NoteView().environmentObject(DataManager())
    }
}
