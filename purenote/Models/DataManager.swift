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
    @Published var pinned : [Note]
    private var currentUrl = URL(fileURLWithPath: "")
    private var rootUrl = URL(fileURLWithPath: "")
    
    
    let concurrentQueue = DispatchQueue(label: "purenotes.concurrent.queue", attributes: .concurrent)
    
    
    let fm = FileManager.default
    
    
    func addSaveNote(newNote: inout Note) {
        saveNote(note: &newNote)
        notes.append(newNote)            
    }
    
    func addNote(newNote: Note) {
        notes.append(newNote)
    }
    
    func delayWithSeconds(trseconds: Double, completion: @escaping () -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + trseconds) {
            completion()
        }
    }
    
    func getRootPath() -> URL {
        
        var tryURL : URL!
        
        // First get the URL for the default ubiquity container for this app
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            tryURL = containerURL.appendingPathComponent("Documents")
            
            do {
                if (fm.fileExists(atPath: tryURL.path, isDirectory: nil) == false) {
                    try  fm.createDirectory(at: tryURL, withIntermediateDirectories: true, attributes: nil)
                }
                
                
            } catch {
                print("ERROR: Cannot create /Documents on iCloud")
            }
        } else {
            print("ERROR: Cannot get ubiquity container")
        }
        return tryURL
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
    
    init() {
        notes=[]
        folders=[]
        pinned = []
        rootUrl = getRootPath()
        currentUrl = rootUrl
        refresh(url: self.currentUrl)
    }
    
    func refresh(url: URL? = nil) {
        notes=[]
        folders=[]
        
        
        if (url != nil) {
            currentUrl = url ?? currentUrl
        }
        
        if (currentUrl.path != rootUrl.path) {
            folders.append(Folder(id: "..", url: currentUrl.deletingLastPathComponent()))
        }
        
        var urls:[URL] = []
        
        urls = listFiles()
        
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
                // we don't want pinned notes to appear in the list of other notes
                else if pinned.count == 1 && pinned[0].url.path == url.path {
                    print("we're skipping this one, it's pinned")
                }
                else {
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
    }
    
    
    private func saveNote(note: inout Note) {
        
        let documentURL = currentUrl.appendingPathComponent(String(note.id))
            .appendingPathExtension("txt")
        
        do {
            try note.content.write(to: documentURL, atomically:true, encoding:String.Encoding.utf8)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }
        note.url=documentURL
    }
    
    func updateNote(index : Int) {
        let documentURL = notes[index].url
        
        do {
            try notes[index].content.write(to: documentURL, atomically:true, encoding:String.Encoding.utf8)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }
    }
    
    func listFiles () -> [URL] {
        var urls:[URL]=[]
        
        
        do {
            try urls=fm.contentsOfDirectory(at: currentUrl, includingPropertiesForKeys:nil)
            print(urls.count)
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
