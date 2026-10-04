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
            
            
            let newNote: Note = try Note(content: CoordinatedFile.read(url), date: (fm.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date(), path: url.lastPathComponent, isLocal: true, url: url, type: .Note)
            
            
            notes.append(newNote)
            
        }
        catch {
            /* error handling here */
            print("Unexpected error: \(error).")
        }
    }
    
    init(url: URL) {
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
                        try addNote(newNote: Note(content: url.relativeString, date: (fm.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date(), path: url.lastPathComponent, isLocal: false, url: url, type: .Note))
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
        
        notes.sort(by: { lhs, rhs in
            return lhs.date > rhs.date    
        })
    
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

    /// Renames a still-generated file to match its first line. Called when
    /// editing finishes rather than while typing: autosave writes every second,
    /// and renaming on every keystroke would mean an iCloud move per character
    /// and a note whose identity changes under the app.
    func finishEditing(_ note: Note) {
        persist(note)

        // Rename the file to match the note's first line, so the filename on
        // disk (and on the Mac) always mirrors the title the user sees. The
        // first line is the source of truth; a name changed by hand on the Mac
        // is reverted here when the title says something else.
        let currentStem = note.url.deletingPathExtension().lastPathComponent
        guard let name = NoteNaming.name(from: note.content),
              name != currentStem
        else { return }

        let target = NoteNaming.availableURL(named: name,
                                             in: note.url.deletingLastPathComponent())
        guard target != note.url else { return }

        do {
            try CoordinatedFile.move(from: note.url, to: target)
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
