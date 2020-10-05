//
//  NotesList.swift
//  ShareData
//
//  Created by Saša Mitrović on 05.10.20.
//

import SwiftUI

struct NotesList: View {
    
    func listFiles () -> [String] {
        var ret: [String] = []
        
        
        let fm = FileManager.default
        
        // First get the URL for the default ubiquity container for this app
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            let tryURL = containerURL.appendingPathComponent("Documents")
            do {
                if (fm.fileExists(atPath: tryURL.path, isDirectory: nil) == false) {
                    try fm.createDirectory(at: tryURL, withIntermediateDirectories: true, attributes: nil)
                }
                let fileName = UUID().uuidString;
                let documentURL = tryURL.appendingPathComponent(fileName)
                    .appendingPathExtension(".txt")
                
                do {
                    try  ret=fm.contentsOfDirectory(atPath: tryURL.path)
                }
                catch {
                    // failed
                    print("Unexpected error: \(error).")
                }
                
            } catch {
                print("ERROR: Cannot create /Documents on iCloud")
            }
        } else {
            print("ERROR: Cannot get ubiquity container")
        }
        return ret
    }
    
    var containerUrl: URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.mitrovic.purenote")?.appendingPathComponent("Documents")
    }
    
    var body: some View {
        NavigationView{
            List {
                ForEach(listFiles(), id: \.self) { item in
                    Text(item)
                }
            }.navigationTitle("Notes")
        }
        
    }
}

struct NotesList_Previews: PreviewProvider {
    static var previews: some View {
        NotesList()
    }
}
