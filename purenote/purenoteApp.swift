//
//  ShareDataApp.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import SwiftUI

@main
struct ShareDataApp: App {
    @AppStorage("shownSplashScreen") var shownSplashScreen = false
    @EnvironmentObject var index: SearchIndex
    private let fm = FileManager.default
    var data: DataManager = DataManager(url: URL(fileURLWithPath: ""))
    
    
    init() {
        data = DataManager(url: getRootPath())
        print("app starting")
        
    }
    
    fileprivate func getRootPath() -> URL {
        
        var tryURL : URL!
        
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
            tryURL = URL(fileURLWithPath: "")
        }
        return tryURL
    }
    
    var body: some Scene {
        
        WindowGroup {
            
            Splash(shownSplashScreen: $shownSplashScreen).showIf(condition: !shownSplashScreen)
            
            RootView(data: data).showIf(condition: shownSplashScreen)
                .environmentObject(data)
                .environmentObject(SearchIndex(rootUrl: getRootPath()))
        }
    }
}
