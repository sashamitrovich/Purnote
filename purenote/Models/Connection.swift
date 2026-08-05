//
//  Connection.swift
//  purenote
//
//  Created by Saša Mitrović on 23.10.20.
//

import Foundation

struct Connection {
    var rootUrl: URL = URL(fileURLWithPath: "")
    var connectionAvailable: Bool = false
    /// True when rootUrl is the app's own Documents directory rather than
    /// iCloud Drive, so the app can say so instead of pretending to sync.
    var isLocal: Bool = false
}
