//
//  ShareDataApp.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import SwiftUI

@main
struct ShareDataApp: App {
//    @EnvironmentObject var data : DataManager
    
    var body: some Scene {
        
        WindowGroup {
            NoteList()
                .environmentObject(DataManager())
        }
    }
}
