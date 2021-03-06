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
            
            
            let newNote: Note = try Note(content: String(contentsOf: url, encoding: String.Encoding.utf8), date: fm.attributesOfItem(atPath: url.path)[.creationDate] as! Date, path: url.lastPathComponent, isLocal: true, url: url, type: .Note)
            
            
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
                        try addNote(newNote: Note(content: url.relativeString, date: fm.attributesOfItem(atPath: url.path)[.creationDate] as! Date, path: url.lastPathComponent, isLocal: false, url: url, type: .Note))
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
                // also add folders
                if url.lastPathComponent != ".Trash" {
                    addFolder(id: url.lastPathComponent, url: url)
                }
                
            }
        }
        
        notes.sort(by: { lhs, rhs in
            return lhs.date > rhs.date    
        })
    
    }
    
    
    private func saveNote(note: inout Note) {
        
        let documentURL = currentUrl.appendingPathComponent(String(note.id))
            .appendingPathExtension("md")
        
        do {
            try note.content.write(to: documentURL, atomically:true, encoding:String.Encoding.utf8)
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
