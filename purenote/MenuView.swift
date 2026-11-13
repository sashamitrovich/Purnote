//
//  MenuView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI
import StoreKit

// elegant solutino for avoiding nesting views
struct MenuView: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @EnvironmentObject var monitor: iCloudMonitor
    @EnvironmentObject var folders: SmartFolderList
    /// One toast for this screen: the Undo after a delete, and the alert when a delete fails.
    @StateObject private var toast = UndoToastModel()
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
    @State private var showingAbout = false
    /// Set when the user chose to carry on without iCloud; says where the notes are.
    @AppStorage("useLocalStorage") private var useLocalStorage = false
    @State private var showingRecentlyDeleted = false
    @Environment(\.requestReview) private var requestReview

    // because I want to avoid refreshing all the MenuViews that are instantiated
    @State var isViewDisplayed = false

    /// The "..." menu: sort, and at the root Recently Deleted and About.
    @ViewBuilder
    private var moreMenu: some View {
        Menu {
            Section("Sort") {
                ForEach(NoteSort.allCases, id: \.self) { sort in
                    SortChoice(sort: sort, current: data.sort, idPrefix: "menu.sort") {
                        data.setSort(sort)
                    }
                }
            }

            if isRoot {
                Section {
                    Button {
                        showingRecentlyDeleted = true
                    } label: {
                        Label("Recently Deleted", systemImage: "trash")
                    }
                    .accessibilityIdentifier("menu.recentlyDeleted")

                    Button {
                        showingAbout = true
                    } label: {
                        Label("About Purnote", systemImage: "info.circle")
                    }
                    .accessibilityIdentifier("menu.about")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("menu.more")
    }

    @ViewBuilder
    var body: some View {
        let model = homeModel
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // With nothing typed the list is the ordinary folders + notes.
                // As soon as there is a query the same list becomes the results,
                // in place -- no second screen to push onto.
                if searchText.isEmpty {
                    HomeMasthead(model: model, onSort: { data.setSort($0) })
                        .overlay(alignment: .topTrailing) {
                            if isRoot { moreMenu }
                        }

                    if isRoot {
                        SmartFoldersView()
                    }

                    FolderView().environmentObject(data)

                    if let empty = model.emptyState {
                        HomeEmptyState(state: empty,
                                       onNewNote: { isCreatingNewNote.toggle() },
                                       onNewFolder: { showingNewFolder.toggle() })
                    }

                    NotesList(model: model)
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
        .background(Color.pn.page)
        // The actions are the system's own bottom toolbar (see `.toolbar` below),
        // which is Liquid Glass on iOS 26 and a plain bar on iOS 18. The toast
        // and, while searching, the search field ride in a safe-area inset: that
        // inset sits above the bar, and above the keyboard.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                UndoToastHost(model: toast)
                if showSearch {
                    searchBar
                }
            }
        }
        .environmentObject(toast)
        .alert(toast.alert?.title ?? "",
               isPresented: Binding(get: { toast.alert != nil }, set: { if !$0 { toast.alert = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(toast.alert?.message ?? "")
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") { createFolder() }
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(notesLocation.newFolderMessage)
        }
        .fullScreenCover(isPresented: $isCreatingNewNote) {
            NoteNew(isEditing: $isCreatingNewNote, newNote: Note(type: .Note))
                .environmentObject(data)
                .environmentObject(index)
        }
        .sheet(isPresented: $showingNewSmartFolder) {
            SmartFolderEditor(folders: folders, index: index)
        }

        // The masthead is the title. The navigation title stays (it names this
        // screen on the back button of the one pushed from it) but is not drawn
        // twice: the bar's own title is replaced by an empty principal item.
        .navigationTitle(isRoot ? "Purnote" : conditionalNavBarTitle(text: data.getCurrentUrl().lastPathComponent))
        .navigationBarTitleDisplayMode(.inline)
        
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
            askForRatingIfDue()
        }
        // the editor for a new note covers this screen without removing it, so
        // coming back from it is not an onAppear
        .onChange(of: isCreatingNewNote) {
            if !isCreatingNewNote { askForRatingIfDue() }
        }
        .onDisappear() {
            self.isViewDisplayed = false
        }
        .toolbar {
            bottomActions
            ToolbarItem(placement: .principal) {
                Text("").accessibilityHidden(true)
            }
            // In a folder the "..." sits in the bar beside the back button. At the
            // root the bar is hidden and the "..." rides on the masthead's row.
            if !isRoot {
                ToolbarItem(placement: .topBarTrailing) {
                    moreMenu
                }
            }
        }
        // the search field takes the bottom edge while it is open
        .toolbar(showSearch ? .hidden : .automatic, for: .bottomBar)
        .toolbar(isRoot ? .hidden : .automatic, for: .navigationBar)
        .navigationDestination(isPresented: $showingAbout) {
            AboutView(location: notesLocation)
        }
        .navigationDestination(isPresented: $showingRecentlyDeleted) {
            RecentlyDeletedView(root: index.rootUrl, data: data, index: index)
        }
        // the screen behind it is where things are restored from, so a toast that
        // offers to undo one of them would only be stale there
        .onChange(of: showingRecentlyDeleted) {
            if showingRecentlyDeleted { toast.dismiss() }
        }
    }
    
    // MARK: - Rating

    /// Asks for an App Store rating when RatingPrompt says it is due. Only here,
    /// on the home list, never while an editor or the search field is up. A
    /// moment's wait lets the screen settle after the transition back to it;
    /// everything is checked again after it, and the ask is only used up then.
    private func askForRatingIfDue() {
        guard !Storage.isUITestFixture,
              RatingPrompt().shouldAsk(version: RatingPrompt.currentVersion) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard canAskForRating else { return }
            if RatingPrompt().takeAsk(version: RatingPrompt.currentVersion) {
                requestReview()
            }
        }
    }

    private var canAskForRating: Bool {
        isViewDisplayed && !isCreatingNewNote && !showSearch && !searchFieldFocused
            && !showingRecentlyDeleted && !showingAbout
    }

    // MARK: - Bottom bar

    private var ribbon: Color { Color.pn.ribbon }

    /// True when the current list is the storage root — the only place smart
    /// folders and the "..." menu's Recently Deleted and Help belong.
    private var isRoot: Bool {
        data.getCurrentUrl().standardizedFileURL.path == index.rootUrl.standardizedFileURL.path
    }

    /// Whether there is a Folders section to show: real subfolders, or (at the
    /// root) the saved smart folders.
    private var hasFolders: Bool {
        !data.folders.isEmpty || (isRoot && !folders.folders.isEmpty)
    }

    /// Where the notes are: iCloud Drive, or this device when the user carried on without iCloud.
    private var notesLocation: NotesLocation {
        NotesLocation.current(useLocalStorage: useLocalStorage)
    }

    /// What the list shows. Pins are read only at the root, where they are shown.
    private var homeModel: HomeListModel {
        HomeListModel(notes: data.notes,
                      pinned: isRoot ? data.pinnedNotes() : [],
                      sort: data.sort,
                      isRoot: isRoot,
                      folderName: conditionalNavBarTitle(text: data.getCurrentUrl().lastPathComponent),
                      hasFolders: hasFolders,
                      now: Date(), calendar: .current)
    }

    /// The three actions in the system's bottom toolbar: search, new folder,
    /// compose. The system draws the bar (glass on iOS 26, plain on iOS 18).
    @ToolbarContentBuilder
    private var bottomActions: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button { openSearch() } label: {
                Image(systemName: "magnifyingglass")
            }
            .tint(ribbon)
            .accessibilityLabel("Search")
        }
        ToolbarItem(placement: .bottomBar) { Spacer() }
        ToolbarItem(placement: .bottomBar) {
            Menu {
                Button("New Folder") { showingNewFolder.toggle() }
                Button("New Smart Folder") { showingNewSmartFolder = true }
            } label: {
                Image(systemName: "plus.rectangle.on.folder")
            }
            .tint(ribbon)
            .accessibilityLabel("New folder")
        }
        ToolbarItem(placement: .bottomBar) { Spacer() }
        ToolbarItem(placement: .bottomBar) {
            Button { isCreatingNewNote.toggle() } label: {
                Image(systemName: "square.and.pencil")
            }
            .modifier(ComposeButtonStyle())
            .accessibilityLabel("New note")
        }
    }

    /// The search field, with its Cancel, in a bar of its own while searching.
    private var searchBar: some View {
        searchField
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.pn.ink2)
                TextField("Search your notes", text: $searchText)
                    .focused($searchFieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.pn.ink2)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.pn.fill,
                        in: RoundedRectangle(cornerRadius: 10))

            Button("Cancel") { closeSearch() }
                .foregroundColor(Color.pn.ribbonText)
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
        let results = index.search(phrase: searchText, scope: .all)

        if results.isEmpty {
            HStack {
                Text("No notes match")
                Text("\u{201C}\(searchText)\u{201D}")
            }.placeholderForegroundColor()
        } else {
            // the result count, and the fact that search spans every folder
            Text(results.count == 1 ? "1 result · all folders" : "\(results.count) results · all folders")
                .font(.caption)
                .foregroundColor(Color.pn.ink2)
                .padding(.bottom, 2)

            ForEach(results) { result in
                let note = result.note
                NavigationLink(destination:
                    NoteView(note: note, toast: toast)
                        .environmentObject(data)
                        .environmentObject(index)
                ) {
                    ListRow(note: note, location: location(for: note), snippet: result.snippet?.text)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        deleteFromSearch(note)
                    } label: {
                        Text("Delete Note")
                        Image(systemName: "trash")
                    }
                }
                .menuRowStyle()
            }
        }
    }

    /// Deletes a search result. A result may live in any folder, so it is the
    /// library root (the index's `rootUrl`) that says where it is trashed from;
    /// the folder on screen is used when it knows that root itself, so its own
    /// list drops the row too.
    private func deleteFromSearch(_ note: Note) {
        let source = data.libraryRoot == nil
            ? DataManager(searchNotes: [note], libraryRoot: index.rootUrl)
            : data
        toast.delete(note: note, from: source, index: index)
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

/// The compose button: amber-prominent glass on iOS 26, an amber icon in the
/// plain bar before that.
private struct ComposeButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(Color.pn.ribbon)
        } else {
            content.tint(Color.pn.ribbon)
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

