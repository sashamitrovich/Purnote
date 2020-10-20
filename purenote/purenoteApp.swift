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
    
    var body: some Scene {
        WindowGroup {
            Splash(shownSplashScreen: $shownSplashScreen).showIf(condition: !shownSplashScreen)
            
            RootView(data: DataManager()).showIf(condition: shownSplashScreen)
                .environmentObject(DataManager())
        }
    }
}
