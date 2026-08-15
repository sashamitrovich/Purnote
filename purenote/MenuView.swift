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
    @State var searchText = ""
    // Search lives at the bottom, above the keyboard, where the thumb already
    // is. showSearch swaps the bottom action bar for the search field;
    // searchFieldFocused raises the keyboard with it.
    @State private var showSearch = false
    @FocusState private var searchFieldFocused: Bool

    // because I want to avoid refreshing all the MenuViews that are instantiated
    @State var isViewDisplayed = false

    @ViewBuilder
    var body: some View {
        List {
            // With nothing typed the list is the ordinary folders + notes.
            // As soon as there is a query the same list becomes the results,
            // in place -- no second screen to push onto.
            if searchText.isEmpty {
                FolderView().environmentObject(data)

                NotesList()
                    .environmentObject(data)
                    .environmentObject(index)
            } else {
                searchResults
            }
        }
        // a clean sheet, not a grey grouped list -- edge-to-edge rows on warm
        // paper, the way a writing app looks
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.purnotePaper)
        // the whole bottom bar -- actions, or the search field when searching --
        // rides above the keyboard as a safe-area inset, so everything a thumb
        // needs stays at the bottom of the screen.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
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
    
    // MARK: - Bottom bar

    private var orange: Color { Color(UIColor.systemOrange) }

    /// Either the three actions, or — once search is tapped — the search field.
    /// Both sit at the bottom; the field version rides up over the keyboard.
    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if showSearch {
                searchField
            } else {
                actionBar
            }
        }
        .padding(.horizontal, showSearch ? 14 : 34)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeInOut(duration: 0.18), value: showSearch)
    }

    private var actionBar: some View {
        HStack {
            Button { openSearch() } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search")

            Spacer()

            Button { showingNewFolder.toggle() } label: {
                Image(systemName: "plus.rectangle.on.folder")
            }
            .accessibilityLabel("New folder")

            Spacer()

            Button { isCreatingNewNote.toggle() } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("New note")
        }
        .font(.title3)
        .tint(orange)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search your notes", text: $searchText)
                    .focused($searchFieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 10))

            Button("Cancel") { closeSearch() }
                .foregroundColor(orange)
        }
    }

    private func openSearch() {
        showSearch = true
        // the field has to exist before it can take focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            searchFieldFocused = true
        }
    }

    private func closeSearch() {
        searchFieldFocused = false
        searchText = ""
        showSearch = false
    }

    /// The results rows, shown inline in the main list while a query is
    /// present. Searching is global, so a match can live in another folder;
    /// tapping a row still opens it in the usual NoteView.
    @ViewBuilder
    private var searchResults: some View {
        let results = index.search(phrase: searchText)

        if results.isEmpty {
            HStack {
                Text("No notes match")
                Text("\u{201C}\(searchText)\u{201D}")
            }.placeholderForegroundColor()
        } else {
            ForEach(results) { note in
                NavigationLink(destination:
                    NoteView(note: note)
                        .environmentObject(data)
                        .environmentObject(index)
                ) {
                    ListRow(note: note)
                }
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
        MenuView()
            .environmentObject(DataManager.sampleDataManager())
            .environmentObject(iCloudMonitor())
            .environmentObject(SearchIndex.init(rootUrl: URL(fileURLWithPath: "/notes")))
    }
}

