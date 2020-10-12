//
//  Item.swift
//  ShareData
//
//  Created by Saša Mitrović on 09.10.20.
//

import Foundation

enum ItemType {
    case Folder
    case Note
}

protocol Item {
    var type: ItemType { get set}
    var id: String { get set}
    var url: URL { get set }
    
}
