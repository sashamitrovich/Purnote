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
    @EnvironmentObject var folders: SmartFolderList
    @State private var isShowing = false
    @State var showingNewFolder = false
    @State var isCreatingNewNote = false
    @State private var showingNewSmartFolder = false
    @State private var newFolderName = ""
    @State var searchText = ""
    // Search lives at the bottom, above the keyboard, where the thumb already
    // is. showSearch swaps the bottom action bar for the search field;
    // searchFieldFocused raises the keyboard with it.
    @State private var showSearch = false
    @FocusState private var searchFieldFocused: Bool
    @State private var showingHelp = false

    // because I want to avoid refreshing all the MenuViews that are instantiated
    @State var isViewDisplayed = false

    @ViewBuilder
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // With nothing typed the list is the ordinary folders + notes.
                // As soon as there is a query the same list becomes the results,
                // in place -- no second screen to push onto.
                if searchText.isEmpty {
                    if hasFolders {
                        // where the smart folders (saved filters) and the real
                        // physical folders begin
                        HStack {
                            Text("Folders")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.top, 18)
                        .padding(.leading, 4)

                        if isRoot {
                            SmartFoldersView()
                        }

                        FolderView().environmentObject(data)

                        // where the folders end and the notes begin
                        HStack {
                            Text("Notes")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.top, 18)
                        .padding(.leading, 4)
                    }

                    NotesList()
                        .environmentObject(data)
                        .environmentObject(index)
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        // a clean sheet, not a grey grouped list -- edge-to-edge rows on warm
        // paper, the way a writing app looks
        .background(Color.purnotePaper)
        // the whole bottom bar -- actions, or the search field when searching --
        // rides above the keyboard as a safe-area inset, so everything a thumb
        // needs stays at the bottom of the screen.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") { createFolder() }
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("It will appear in iCloud Drive › Purnote.")
        }
        .fullScreenCover(isPresented: $isCreatingNewNote) {
            NoteNew(isEditing: $isCreatingNewNote, newNote: Note(type: .Note))
                .environmentObject(data)
                .environmentObject(index)
        }
        .sheet(isPresented: $showingNewSmartFolder) {
            SmartFolderEditor(folders: folders, index: index)
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
        .toolbar {
            if isRoot {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help")
                }
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
    
    // MARK: - Bottom bar

    private var orange: Color { Color.accentColor }

    /// True when the current list is the storage root — the only place smart
    /// folders and the Help button belong.
    private var isRoot: Bool {
        data.getCurrentUrl().standardizedFileURL.path == index.rootUrl.standardizedFileURL.path
    }

    /// Whether there is a Folders section to show: real subfolders, or (at the
    /// root) the saved smart folders.
    private var hasFolders: Bool {
        !data.folders.isEmpty || (isRoot && !folders.folders.isEmpty)
    }

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

            Menu {
                Button("New Folder") { showingNewFolder.toggle() }
                Button("New Smart Folder") { showingNewSmartFolder = true }
            } label: {
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

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { newFolderName = "" }
        guard !name.isEmpty else { return }

        let url = data.getCurrentUrl()
        do {
            try CoordinatedFile.createDirectory(at: url.appendingPathComponent(name))
        } catch {
            print("Failed to create directory: \(error).")
            return
        }
        data.refresh(url: url)
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
            // the result count, and the fact that search spans every folder
            Text(results.count == 1 ? "1 result · all folders" : "\(results.count) results · all folders")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            ForEach(results) { note in
                NavigationLink(destination:
                    NoteView(note: note)
                        .environmentObject(data)
                        .environmentObject(index)
                ) {
                    ListRow(note: note, location: location(for: note))
                }
                .menuRowStyle()
            }
        }
    }

    /// For a search result, the folder it lives in — but only when that is not
    /// the folder being viewed, where the row already reads as "here".
    private func location(for note: Note) -> String? {
        let here = note.url.deletingLastPathComponent().standardizedFileURL.path
            == data.getCurrentUrl().standardizedFileURL.path
        return here ? nil : folderLabel(for: note)
    }

    /// The folder a note lives in, relative to the storage root. Root notes are
    /// just "Purnote".
    private func folderLabel(for note: Note) -> String {
        let root = index.rootUrl.standardizedFileURL.path
        let folder = note.url.deletingLastPathComponent().standardizedFileURL.path
        guard folder != root else { return "Purnote" }
        if folder.hasPrefix(root + "/") {
            return String(folder.dropFirst(root.count + 1))
        }
        return (folder as NSString).lastPathComponent
    }

    func conditionalNavBarTitle(text: String) -> String {
        if (text=="Documents") {
            return "Purnote"
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

