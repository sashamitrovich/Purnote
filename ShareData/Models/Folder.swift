//
//  Folder.swift
//  ShareData
//
//  Created by Saša Mitrović on 09.10.20.
//

import Foundation

struct Folder: Item {
    var type = ItemType.Folder
    
    var id: String
    
    init (id: String) {
        self.id = id
    }
}
