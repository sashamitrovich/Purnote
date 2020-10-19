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
        notes.append(Note(content:
"""
# News swagger and the crazy nightkfkfkfkf

## my list
* one
* bullet

Just some plain text

""", date: Date(), path: "/notes/sample-note.txt", isLocal: true, url: URL(fileURLWithPath: "/notes/sample-note.txt")))
        notes.append(Note(content: "This is a sample iCloud note", date: Date(), path: "/notes/icloud-note.txt", isLocal: false, url: URL(fileURLWithPath: "/notes/.icloud-note.txt.icloud")))
        notes.append(Note(content: "My notes about our meeting on 27.07.2020", date: Date(), path: "/notes/meeting-note.txt", isLocal: true, url: URL(fileURLWithPath: "/notes/meeting-note.txt")))
        notes.append(Note(content:
                            """
# T

## my list
* one
* bullet

Justa plain text.

Some *italic* and **bold text**

[Here's a link](http://www.apple.com)

Image:
![Image](http://url/a.png)

> Blockquote

1. One
2. Two
3. Three

---
`inline code` with backtics

```
# code block
print '3 backticks or'
print 'indent 4 spaces'
```

""", date: Date(), path: "/notes/trips/sample-trip-note.txt", isLocal: true, url: URL(fileURLWithPath: "/notes/trips/sample-note.txt")))
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
    static func sampleDataManager() -> DataManager {
        let dataManager = DataManager()
        dataManager.notes = DataManager.sampleNotes
        dataManager.folders = DataManager.sampleFolders
        
        return dataManager
    }
}
