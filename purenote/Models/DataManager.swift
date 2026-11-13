//
//  Data.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import Foundation

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
    
    func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}



class DataManager: ObservableObject {
    @Published  var notes : [Note]
    @Published var folders : [Folder]
    private var currentUrl = URL(fileURLWithPath: "")
    private var rootUrl = URL(fileURLWithPath: "")
    private var sortPreferences = SortPreferences()
    /// nil for a DataManager that is not backed by a library (search results,
    /// the demo library), which then has no pins.
    private var pinService: PinService?
    /// The pinned notes' paths, relative to the library root, as last loaded.
    @Published private(set) var pins = PinList()
    
    let concurrentQueue = DispatchQueue(label: "purenotes.concurrent.queue", attributes: .concurrent)
    
    
    let fm = FileManager.default
    
    
    func addSaveNote(newNote: inout Note) {
        saveNote(note: &newNote)
//        notes.append(newNote)
        notes.insert(newNote, at: 0)
    }
    
    func addNote(newNote: Note) {
        notes.append(newNote)
    }
    
    public static func delayWithSeconds(trseconds: Double, completion: @escaping () -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + trseconds) {
            completion()
        }
    }
    

    
    func addNote(url: URL) {
        do {
            
            
            let newNote: Note = try Note(content: CoordinatedFile.read(url), date: NoteDates.modified(of: url), path: url.lastPathComponent, isLocal: true, url: url, type: .Note)
            
            
            notes.append(newNote)
            
        }
        catch {
            /* error handling here */
            print("Unexpected error: \(error).")
        }
    }
    
    /// `libraryRoot` is the top of the whole library, which pins are relative
    /// to. A DataManager for a subfolder is created with `url` set to that
    /// folder, so it has to be told where the library starts; it defaults to
    /// `url` for the root level.
    init(url: URL, sortPreferences: SortPreferences = SortPreferences(), libraryRoot: URL? = nil) {
        self.sortPreferences = sortPreferences
        self.rootUrl = url
        let root = libraryRoot ?? url
        self.pinService = root.path == "/" ? nil : PinService(root: root)
        notes=[]
        folders=[]

        self.currentUrl = url

        refresh(url: self.currentUrl)
    }
    
    init(searchNotes: [Note]) {
        notes=searchNotes
        folders = []            
    }
    

    
    func refresh(url: URL) {
        self.currentUrl = url
        
        // because we don't have access to iCLoud
        // demo mode
        if (url.path=="/") {
            notes = DataManager.sampleNotes
            folders = DataManager.sampleFolders
            return
        }
        
        
        notes=[]
        folders=[]
           
        let urls:[URL] = listFiles()
        
        for (_,url) in urls.enumerated() {
            
            if !url.hasDirectoryPath {
                
                if url.absoluteString.contains(".icloud") {
                    // we want the iCloud item to download in the background
                    // so let's do this in a Thread
                    
                    
                    do {
                        try addNote(newNote: Note(content: url.relativeString, date: NoteDates.modified(of: url), path: url.lastPathComponent, isLocal: false, url: url, type: .Note))
                    }
                    catch {
                        /* error handling here */
                        print("Unexpected error: \(error).")
                    }
                    
                }
                else if !url.absoluteString.contains(".icloud") && url.absoluteString.contains(".md") {
                    // it's a local file
                    
                    addNote(url: url)
                }
            }
            
            else {
                // add folders, skipping hidden ones (`.Trash`, `.purnote`) and
                // a note's attachment folder (`<note>.assets`)
                if !url.lastPathComponent.hasPrefix("."),
                   !url.lastPathComponent.hasSuffix(".assets") {
                    addFolder(id: url.lastPathComponent, url: url)
                }
                
            }
        }
        
        notes = NoteSort.sorted(notes, by: sortPreferences.sort(forFolder: currentUrl, root: rootUrl))
        folders = FolderSort.sorted(folders)
        reloadPins()
    }
    
    
    /// Writes a note's content to its file, giving it one first if it does not
    /// have one yet, and adding it to the list the first time.
    ///
    /// Safe to call repeatedly with the same note, which is what autosave
    /// needs. A note whose file was deleted elsewhere is written back out
    /// rather than throwing the edit away.
    func persist(_ note: Note) {
        // a new Note starts out as URL(fileURLWithPath: ""), which is not an
        // empty path -- it resolves against the working directory -- so the
        // test is whether this looks like one of our note files at all
        if note.url.pathExtension != "md" {
            note.url = currentUrl.appendingPathComponent(note.id).appendingPathExtension("md")
        }

        do {
            try CoordinatedFile.write(note.content, to: note.url)
        }
        catch {
            // failed
            print("Failed to save note: \(error).")
            return
        }

        if !notes.contains(where: { $0.id == note.id }) {
            notes.insert(note, at: 0)
        }
    }

    /// Renames a note's file to match its first line, when the file name is the
    /// app's to change (see NoteNaming.mayRename). Called when editing finishes
    /// rather than while typing: autosave writes every second, and renaming on
    /// every keystroke would mean an iCloud move per character and a note whose
    /// identity changes under the app.
    ///
    /// `previousContent` is the text the note had when editing opened (or when
    /// it was last finished), which is what the current file name was derived
    /// from. A file name given by hand on the Mac is left alone.
    func finishEditing(_ note: Note, previousContent: String? = nil) {
        persist(note)

        let currentStem = note.url.deletingPathExtension().lastPathComponent
        guard NoteNaming.mayRename(stem: currentStem, previousContent: previousContent),
              let name = NoteNaming.name(from: note.content),
              name != currentStem
        else { return }

        let target = NoteNaming.availableURL(named: name,
                                             in: note.url.deletingLastPathComponent(),
                                             excluding: note.url)
        guard target != note.url else { return }

        do {
            try CoordinatedFile.move(from: note.url, to: target)
            pinsFollowMove(from: note.url, to: target)
            // keep the assets folder beside the note under the new name, and
            // point the references at it
            let rewritten = NoteAssets.renameAssetsFolder(from: note.url, to: target, content: note.content)
            if rewritten != note.content {
                note.content = rewritten
                try CoordinatedFile.write(rewritten, to: target)
            }
        }
        catch {
            // failed -- the note keeps the name it has, which is not worth
            // bothering the user about
            print("Could not rename note to \(target.lastPathComponent): \(error).")
            return
        }

        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes.remove(at: index)
        }
        note.url = target
        note.id = target.lastPathComponent
        note.label = note.id
        notes.insert(note, at: 0)
    }

    /// Moves a note (and its attachments folder, if any) into another folder.
    /// The same move the "Move Note" picker makes, driven here by a drop.
    func move(note: Note, to folderURL: URL) {
        let destination = folderURL.appendingPathComponent(note.id)
        guard destination.path != note.url.path else { return }

        do {
            try CoordinatedFile.move(from: note.url, to: destination)
            pinsFollowMove(from: note.url, to: destination)
            try NoteAssets.moveAssetsFolder(forNoteAt: note.url, to: destination)
        } catch {
            print("Failed to move note to \(folderURL.lastPathComponent): \(error).")
        }
        refresh(url: getCurrentUrl())
    }

    // MARK: - Pins

    private func pinPath(of note: Note) -> String? {
        pinService.flatMap { PinPath.relative(of: note.url, in: $0.root) }
    }

    func isPinned(_ note: Note) -> Bool {
        pinPath(of: note).map { pins.contains($0) } ?? false
    }

    func togglePin(_ note: Note) {
        guard let pinService else { return }
        pinService.toggle(note.url)
        reloadPins()
    }

    /// Re-reads the pins from disk, dropping any whose note no longer exists.
    func reloadPins() {
        guard let pinService else { return }
        let loaded = PinStore.load(from: pinService.root, droppingMissing: true)
        if loaded != pins { pins = loaded }
    }

    /// The pinned notes that exist, in pin order, wherever in the library they
    /// are (not just in the folder this DataManager is showing).
    func pinnedNotes() -> [Note] {
        guard let pinService else { return [] }
        return PinStore.load(from: pinService.root).paths.compactMap { path in
            let url = pinService.root.appendingPathComponent(path)
            let placeholder = url.deletingLastPathComponent()
                .appendingPathComponent(PinPath.placeholderName(for: url.lastPathComponent))
            if fm.fileExists(atPath: url.path),
               let content = try? CoordinatedFile.read(url) {
                return Note(content: content, date: NoteDates.modified(of: url),
                            path: url.lastPathComponent, isLocal: true, url: url, type: .Note)
            }
            if fm.fileExists(atPath: placeholder.path) {
                // still in iCloud, shown the way the folder listing shows it
                return Note(content: placeholder.relativeString, date: NoteDates.modified(of: placeholder),
                            path: placeholder.lastPathComponent, isLocal: false, url: placeholder, type: .Note)
            }
            return nil
        }
    }

    /// Call after a note or a folder has been renamed or moved, so its pins
    /// follow it.
    func pinsFollowMove(from old: URL, to new: URL) {
        pinService?.moved(from: old, to: new)
        reloadPins()
    }

    /// Call after a note or a folder has been deleted, so its pins go.
    func pinsDrop(at url: URL) {
        pinService?.removed(at: url)
        reloadPins()
    }

    // MARK: - Trash

    /// The top of the library, or nil for a DataManager with no library behind
    /// it (search results, the demo library).
    var libraryRoot: URL? { pinService?.root }

    /// Moves a note (and its attachments) into the library's trash, then drops
    /// its pin, forgets it in the search index and takes it out of `notes`.
    /// Throws without changing any of those when the move did not happen.
    @discardableResult
    func trash(note: Note, index: SearchIndex? = nil) throws -> TrashedItem {
        guard let root = libraryRoot else { throw TrashError.noLibrary }
        do {
            let item = try TrashStore.moveToTrash(note.url, libraryRoot: root)
            didTrash(url: note.url, isFolder: false, index: index)
            return item
        } catch TrashError.rollbackFailed(let item, let underlying) {
            // the note did move (only its pictures stayed behind), so it is gone from here
            didTrash(url: note.url, isFolder: false, index: index)
            throw TrashError.rollbackFailed(item: item, underlying: underlying)
        }
    }

    /// Several notes, each on its own: one that fails does not stop the rest.
    func trash(notes toTrash: [Note], index: SearchIndex? = nil) -> TrashBatch {
        var batch = TrashBatch()
        for note in toTrash {
            do { batch.items.append(try trash(note: note, index: index)) }
            catch { batch.failures.append(TrashFailure(url: note.url, error: error)) }
        }
        return batch
    }

    /// Moves a whole folder into the trash; pins and index entries under it go.
    @discardableResult
    func trash(folder: Folder, index: SearchIndex? = nil) throws -> TrashedItem {
        guard let root = libraryRoot else { throw TrashError.noLibrary }
        let item = try TrashStore.moveToTrash(folder.url, libraryRoot: root)
        didTrash(url: folder.url, isFolder: true, index: index)
        return item
    }

    /// Puts a trashed item back (see TrashStore.restore), then makes the index
    /// know the note, or every note under the folder, at the place it came back
    /// to, and shows it if that is the folder on screen. Pins are not restored.
    @discardableResult
    func restore(_ item: TrashedItem, index: SearchIndex? = nil) throws -> URL {
        guard let root = libraryRoot else { throw TrashError.noLibrary }
        do {
            let url = try TrashStore.restore(item, libraryRoot: root)
            didRestore(at: url, index: index)
            return url
        } catch TrashError.partialRestore(let restored, let underlying) {
            if let restored { didRestore(at: restored, index: index) }
            throw TrashError.partialRestore(restored: restored, underlying: underlying)
        }
    }

    private func didTrash(url: URL, isFolder: Bool, index: SearchIndex?) {
        pinsDrop(at: url)
        if isFolder {
            index?.remove(folder: url.path)
            folders.removeAll { $0.url == url }
        } else {
            index?.remove(path: url.path)
            notes.removeAll { $0.url == url }
        }
    }

    private func didRestore(at url: URL, index: SearchIndex?) {
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return }
        if isDirectory.boolValue { index?.reindex(folder: url.path) } else { index?.update(path: url.path) }
        // Anywhere under the folder on screen: the item may be in it, or may have brought back
        // a folder (a recreated parent) that is a new row in it.
        let current = TrashPath.normalized(currentUrl)
        if TrashPath.normalized(url).hasPrefix(current == "/" ? "/" : current + "/") {
            refresh(url: currentUrl)
        }
    }

    private func saveNote(note: inout Note) {
        
        let documentURL = currentUrl.appendingPathComponent(String(note.id))
            .appendingPathExtension("md")
        
        do {
            try CoordinatedFile.write(note.content, to: documentURL)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }
        note.url=documentURL
    }
    
    
    func listFiles () -> [URL] {
        var urls:[URL]=[]
        
        
        do {
            try urls=fm.contentsOfDirectory(at: currentUrl, includingPropertiesForKeys:nil)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }
        
        return urls
    }
    
    func addFolder(id: String, url: URL) {
        folders.append(Folder(id: id, url: url))
    }
    
    func getCurrentUrl() -> URL {
        return currentUrl
    }

}
