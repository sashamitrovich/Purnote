//
//  MenuView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI


// elegant solutino for avoiding nesting views
struct MenuView: View {
    var data: DataManager
    @State private var isShowing = false
    @State var showingNewFolder = false
    @State var isCreatingNewNote = false
   
    
    
    var body: some View {
        List {
            
            FolderView().environmentObject(data).padding(.bottom, 5.0)
            NoteView().environmentObject(data)
        }
        .navigationBarTitle(Text(conditionalNavBarTitle(text: data.getCurrentUrl().lastPathComponent)), displayMode: .automatic)
        .navigationBarItems(leading:
                                        HStack {
                                            Button(action: {
                                                self.showingNewFolder.toggle()
                                            }) {
                                                Image(systemName: "plus.rectangle.on.folder").systemOrange().font(.title)
                                                
                                            }.sheet(isPresented: $showingNewFolder) {
                                               
                                                NewFolderView(showSheetView: $showingNewFolder, url: data.getCurrentUrl())
                                                    .environmentObject(data)
                                       
                                            }
                                            
                                        },
                            trailing:  Button(action: {
                                self.isCreatingNewNote.toggle()
                            }) {
                                Image(systemName: "square.and.pencil").systemOrange().font(.title)
                                
                            }.sheet(isPresented: $isCreatingNewNote) {
                                
                                NoteNew(isEditing: $isCreatingNewNote, newNote: Note(type: .Note))
                                    .environmentObject(data)
                                
                            })
                // because we want to remove the default padding that the navigationBarItems creates
                // https://stackoverflow.com/a/63225776/1393362
                .listStyle(PlainListStyle())
                .pullToRefresh(isShowing: $isShowing) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        data.refresh(url: data.getCurrentUrl())
                        isShowing = false
                    }
                }
        
    }
    
    func conditionalNavBarTitle(text: String) -> String {
        if (text=="Documents") {
            return "Notes"
        }
        else {
            return text
        }
    }
    
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        MenuView(data: DataManager()).environmentObject(DataManager())
    }
}
