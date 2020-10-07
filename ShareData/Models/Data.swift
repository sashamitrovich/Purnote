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


struct Note: Identifiable, Equatable {
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.content == rhs.content
    }
    
    var id: Int64
    var content: String
    var date: Date
    var isLocal: Bool = true
    
    fileprivate init(title:String) {        
        self.init()
        self.content = title
    }
    
    init() {
        let currentDate: Date = Date()
        self.id=currentDate.currentTimeMillis()
        self.content = ""
        self.date = currentDate
    }
    
    fileprivate init(content:String, date:Date, path:String, isLocal:Bool?) {
        self.id=Int64(path.hash)
        self.content=content
        self.date=date
        self.isLocal=isLocal ?? true
    }
    
}


class Data: ObservableObject {
    @Published var note : [Note]
    
    let concurrentQueue = DispatchQueue(label: "mitrovic.concurrent.queue", attributes: .concurrent)
    
    
    let fm = FileManager.default
    
    private func addNote(title: String) ->  Note {
        let newNote = Note (title: title)
        note.append(newNote)
        return newNote
    }
    
    func addSaveNote(newNote: Note) {
        saveNote(note: newNote)
        note.append(newNote)            
    }
    
    func addNote(newNote: Note) {
        note.append(newNote)
    }
    
    func delayWithSeconds(trseconds: Double, completion: @escaping () -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + trseconds) {
            completion()
        }
    }
    
    func getDocumentsPath() -> URL {
        var tryURL: URL!
        
        
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
            
            let newNote: Note = try Note(content: String(contentsOf: url, encoding: String.Encoding.utf8), date: fm.attributesOfItem(atPath: url.path)[.creationDate] as! Date, path: url.absoluteString, isLocal: true)
            
            note.append(newNote)
        }
        catch {
            /* error handling here */
            print("Unexpected error: \(error).")
        }
    }
    
    init() {
        var urls:[URL] = []
        
        note=[]
        //        note.append(Note(title: "Great Expectations"))
        //        note.append(Note(title: "Catcher in the Rye"))
        //        note.append(Note(title: "The Post Office"))
        //        note.append(Note(title: "99m Habits of Mildly Successaful People Who Strive For More"))
        
        urls = listFiles()
        
        for (index,url) in urls.enumerated() {
            
            if !url.hasDirectoryPath {
                
                if url.absoluteString.contains(".icloud") {
                    // we want the iCloud item to download in the background
                    // so let's do this in a Thread
                    
                    
                    do {
                        try addNote(newNote: Note(content: url.relativeString, date: fm.attributesOfItem(atPath: url.path)[.creationDate] as! Date, path: url.absoluteString, isLocal: false))
                    }
                    catch {
                        /* error handling here */
                        print("Unexpected error: \(error).")
                    }
                    
                    //                    concurrentQueue.async { [self] in
                    //
                    //                        // start downloading item
                    ////                        do
                    ////                        {
                    ////                            try fm.startDownloadingUbiquitousItem(at: url)
                    ////                        }
                    ////                        catch {
                    ////                            /* error handling here */
                    ////                            print("Unexpected error: \(error).")
                    ////                        }
                    //
                    //                        // wait for item to download
                    //
                    ////                        while fm.value(forKey: NSMetadataUbiquitousItemDownloadingStatusKey) as! String != NSMetadataUbiquitousItemDownloadingStatusDownloaded {
                    ////                            delayWithSeconds(trseconds: 1) {
                    ////                                print("still downloading")
                    ////                            }
                    ////                        }
                    ////
                    ////                        self.note[index].isLocal=true
                    //                    }
                }
                
                else {
                    // it's a local file
                    addNote(url: url)
                }
            }
            
        }
        
    }
    
    
    
    private func saveNote(note: Note) {
        let tryUrl = getDocumentsPath()
        
        let documentURL = tryUrl.appendingPathComponent(String(note.id))
            .appendingPathExtension("txt")
        
        do {
            try note.content.write(to: documentURL, atomically:true, encoding:String.Encoding.utf8)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }
    }
    
    
    func listFiles () -> [URL] {
        var urls:[URL]=[]
        
        
        do {
            try urls=fm.contentsOfDirectory(at: getDocumentsPath(), includingPropertiesForKeys:nil)
            print(urls.count)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
        }
        
        return urls
    }
    
}
