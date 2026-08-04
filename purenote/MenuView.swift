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
    @EnvironmentObject var monitor: iCloudMonitor
    @State private var isShowing = false
    @State var showingNewFolder = false
    @State var isCreatingNewNote = false
    @State var isSearching = false
    @State var searchText = ""
    
    // because I want to avoid refreshing all the MenuViews that are instantiated
    @State var isViewDisplayed = false
    
    @ViewBuilder
    var body: some View {
        VStack {
            
            if isSearching {
                SearchView(searchText: $searchText, isSearching: $isSearching).showIf(condition: isSearching)
                    .environmentObject(data)
                    .environmentObject(index)
            }
           
            else {
                List {
                    FolderView().environmentObject(data)
                    
                    NotesList()
                        .environmentObject(data)
                        .environmentObject(index)
                    
                }
                // the actions live in the bottom bar, within reach of a
                // thumb, rather than in the top right corner. The icons are
                // left at their system size and take their colour from the
                // accent colour -- forcing .font(.title) and a hand-applied
                // orange fought the toolbar's own styling and looked it
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            searchText = ""
                            data.refresh(url: data.getCurrentUrl())
                            self.isSearching.toggle()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .accessibilityLabel("Search")

                        Spacer()

                        Button {
                            self.showingNewFolder.toggle()
                        } label: {
                            Image(systemName: "plus.rectangle.on.folder")
                        }
                        .accessibilityLabel("New folder")

                        Button {
                            self.isCreatingNewNote.toggle()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("New note")
                    }
                }
                .fullScreenCover(isPresented: $showingNewFolder) {
                    FolderNew(showSheetView: $showingNewFolder, url: data.getCurrentUrl())
                        .environmentObject(data)
                }
                .fullScreenCover(isPresented: $isCreatingNewNote) {
                    NoteNew(isEditing: $isCreatingNewNote, newNote: Note(type: .Note))
                        .environmentObject(data)
                        .environmentObject(index)
                }
            }

                
        }

        .navigationTitle(conditionalNavBarTitle(text: data.getCurrentUrl().lastPathComponent))
        
        // because we want to remove the default padding that the navigationBarItems creates
        // https://stackoverflow.com/a/63225776/1393362
        .refreshable {
            if isViewDisplayed {
                data.refresh(url: data.getCurrentUrl())
                index.indexall()
            }
        }
        // iCloud told us something under the container changed
        .onChange(of: monitor.changeCount) {
            if isViewDisplayed {
                data.refresh(url: data.getCurrentUrl())
                index.indexall()
            }
        }
        // kept as the fallback for when there is no ubiquity container to
        // watch: iCloud Drive switched off, or the simulator
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
            data.refresh(url: data.getCurrentUrl())
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
            .environmentObject(iCloudMonitor())
            .environmentObject(SearchIndex.init(rootUrl: URL(fileURLWithPath: "/notes")))
    }
}

