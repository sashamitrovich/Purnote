//
//  Note.swift
//  ShareData
//
//  Created by Saša Mitrović on 08.10.20.
//

import Foundation


struct Note: Identifiable, Equatable {
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.content == rhs.content
    }
    
    var id: String
    var content: String
    var date: Date
    var isLocal: Bool = true
    var url: URL
    var isDownloading = false
    
    init() {
        self.id=""
        self.content=""
        self.date=Date()
        self.isLocal=true
        self.url=URL(fileURLWithPath: "")
    }
    
    init(content:String, date:Date, path:String, isLocal:Bool?, url: URL) {
        self.id=path
        self.content=content
        self.date=date
        self.isLocal=isLocal ?? true
        self.url = url
    }
    
}
