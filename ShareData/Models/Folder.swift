//
//  Folder.swift
//  ShareData
//
//  Created by Saša Mitrović on 09.10.20.
//

import Foundation

struct Folder: Item, Identifiable {
    var url: URL
    
    var type = ItemType.Folder
    
    var id: String
    
    init (id: String, url: URL) {
        self.id = id
        self.url = url
    }
}
