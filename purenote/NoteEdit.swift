//
//  BookDetail.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct NoteEdit: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @State var note: Note
    @Environment(\.presentationMode) var presentationMode
    
    var noteIndex: Int {
        data.notes.firstIndex(where: { $0.id == note.id })!
    }
    
    var body: some View {
        NavigationView {
            
            TextEditor(text: $data.notes[noteIndex].content)
                
                
                .navigationBarItems(trailing:  Button(action: {
                    updateNote()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done").font(.title2).foregroundColor(Color(UIColor.systemOrange))
                })
            
        }
    }
    
    func updateNote() {
        
        let documentURL = self.data.notes[noteIndex].url
        
        do {
            try self.data.notes[noteIndex].content.write(to: documentURL, atomically:true, encoding:String.Encoding.utf8)
        }
        catch {
            // failed
            print("Unexpected error, failed to update note: \(error).")
        }
        data.refresh(url: data.getCurrentUrl())
        index.indexall()
    }
}

//struct NoteDetail_Previews: PreviewProvider {
//    static var previews: some View {        
//        NoteEdit(note: DataManager.sampleDataManager().notes[0] , showSheetView: .constant(true) ).environmentObject(DataManager.sampleDataManager())
//    }
//}
