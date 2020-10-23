//
//  SearchResultsView.swift
//  purenote
//
//  Created by Saša Mitrović on 22.10.20.
//

import SwiftUI
import Parma


struct SearchResultsView: View {
    @EnvironmentObject var index: SearchIndex
    @EnvironmentObject var data: DataManager
    @State private var showSheetView = false
    var notes: [Note]
    @Binding var searchText: String
    
    var body: some View {
        ForEach(notes) { note in
            
            VStack {
                
                NavigationLink(destination:
                                ScrollView {
                                    Parma(note.content, render: MyRender())
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .padding(.leading, 5.0)
                                        .navigationBarItems(trailing:  Button(action: {
                                            showSheetView.toggle()
                                            
                                        }) {
                                            Text("Edit").font(.title2).foregroundColor(Color(UIColor.systemOrange))
                                            
                                        }.sheet(isPresented: $showSheetView) {
                                            
                                            NoteEdit(note: note, showSheetView: $showSheetView)
                                                .environmentObject(DataManager(searchNotes: notes))
                                            
                                        })
                                        
                                        .environmentObject(DataManager(searchNotes: notes))
                                }) {
                    ListRow(note: note).environmentObject(DataManager(searchNotes: notes))
                }
            }
            
        }
//        .onDelete(perform: deleteItems).padding(.leading, 5.0)
    }
    
    func deleteItems(at offsets: IndexSet) {

        for offset in offsets.enumerated() {
            
            do {
                try FileManager.default.trashItem(at: notes[offset.element].url, resultingItemURL: nil)
            }
            catch {
                // failed
                print("Failed to delete notes: \(error).")
            }
        }

        index.indexall()
        let oldSearchText = searchText
        searchText=""
        searchText = oldSearchText
        
    }
}

//struct SearchResultsView_Previews: PreviewProvider {
//    static var previews: some View {
//        SearchResultsView(data: DataManager.sampleDataManager())
//    }
//}
