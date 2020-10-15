//
//  SampleData.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import Foundation

extension DataManager {
    static var sampleNotes : [Note] {
        
        var notes : [Note] = []
        notes.append(Note(content: "This is a sample note", date: Date(), path: "/notes/sample-note.txt", isLocal: true, url: URL(fileURLWithPath: "/notes/sample-note.txt")))
        notes.append(Note(content: "This is a sample iCloud note", date: Date(), path: "/notes/icloud-note.txt", isLocal: false, url: URL(fileURLWithPath: "/notes/.icloud-note.txt.icloud")))
        notes.append(Note(content: "My notes about our meeting on 27.07.2020", date: Date(), path: "/notes/meeting-note.txt", isLocal: true, url: URL(fileURLWithPath: "/notes/meeting-note.txt")))
        return notes
    }
}

extension DataManager {
    static var sampleFolders : [Folder] {
        var folders : [Folder] = []
        
        folders.append(Folder(id: "Trips", url: URL(fileURLWithPath: "/notes/trips") ))
        folders.append(Folder(id: "Meetings", url: URL(fileURLWithPath: "/notes/meetings")))
        
        return folders
    }
}

extension DataManager {
    static var samplePinned : [Note] {
        var pinned: [Note] = []
        
        pinned.append(Note(content: "I have pinned this note", date: Date(), path: "/notes/sample-pinned-note.txt", isLocal: true, url: URL(fileURLWithPath: "/notes/sample-pinned-note.txt")))
        
        return pinned
        
    }
}
