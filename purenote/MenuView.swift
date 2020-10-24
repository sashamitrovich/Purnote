//
//  MenuView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI


// elegant solutino for avoiding nesting views
struct MenuView: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @State private var isShowing = false
    @State var showingNewFolder = false
    @State var isCreatingNewNote = false
    @State var isSearching = false
    @State var searchText = ""
    
    // because I want to avoid refreshing all the MenuViews that are instantiated
    @State var isViewDisplayed = false
    
    
    var body: some View {
        List {
            SearchView(searchText: $searchText, isSearching: $isSearching).showIf(condition: isSearching)
                .environmentObject(data)
                .environmentObject(index)
            FolderView().environmentObject(data).padding(.bottom, 5.0)
                .showIf(condition: !isSearching)
            NoteView().environmentObject(data)
                .showIf(condition: !isSearching)
            
        }
        .navigationBarTitle(Text(conditionalNavBarTitle(text: data.getCurrentUrl().lastPathComponent)), displayMode: .automatic)
        .navigationBarItems(trailing:
                                HStack {
                                    Button(action: {
                                        searchText = ""
                                        data.refresh(url: data.getCurrentUrl())
                                        self.isSearching.toggle()
                                        
                                    }) {
                                        Image(systemName: "magnifyingglass").systemOrange().font(.title)
                                    }
                                        
                                    Spacer(minLength: 10)
                                    
                                    Button(action: {
                                        self.showingNewFolder.toggle()
                                    }) {
                                        Image(systemName: "plus.rectangle.on.folder").systemOrange().font(.title)
                                        
                                    }.sheet(isPresented: $showingNewFolder) {
                                        
                                        NewFolderView(showSheetView: $showingNewFolder, url: data.getCurrentUrl())
                                            .environmentObject(data)
                                        
                                    }
                                    Spacer(minLength: 10)
                                    Button(action: {
                                        self.isCreatingNewNote.toggle()
                                    }) {
                                        Image(systemName: "square.and.pencil").systemOrange().font(.title)
                                        
                                    }.sheet(isPresented: $isCreatingNewNote) {
                                        
                                        NoteNew(isEditing: $isCreatingNewNote, newNote: Note(type: .Note))
                                            .environmentObject(data)
                                            .environmentObject(index)
                                        
                                    }
                                    
                                }
        )
        // because we want to remove the default padding that the navigationBarItems creates
        // https://stackoverflow.com/a/63225776/1393362
        .listStyle(PlainListStyle())
        .pullToRefresh(isShowing: $isShowing) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                data.refresh(url: data.getCurrentUrl())
                index.indexall()
                isShowing = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if isViewDisplayed {
                    data.refresh(url: data.getCurrentUrl())
                    index.indexall()
                    isShowing = false
                }

            }
        }
        .onAppear() {
            self.isViewDisplayed = true
        }
        .onDisappear() {
            self.isViewDisplayed = false
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
        MenuView()
            .environmentObject(DataManager.sampleDataManager())
    }
}
