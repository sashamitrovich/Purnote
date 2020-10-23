//
//  ShareDataApp.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import SwiftUI

@main
struct PurenoteApp: App {

    
    
    @AppStorage("shownSplashScreen") var shownSplashScreen = false
    @EnvironmentObject var index: SearchIndex
    private let fm = FileManager.default
    var data: DataManager = DataManager(url: URL(fileURLWithPath: ""))

    private var icloudConnection = iCloudConnection()
    @State var connection = iCloudConnection.getConnection()
    
    init() {
        print("starting app")
    }
    
    var body: some Scene {
        
        WindowGroup {
            
            if !shownSplashScreen || !connection.connectionAvailable {
                Splash(shownSplashScreen: $shownSplashScreen, iCloudConnectionNotAvailable: !connection.connectionAvailable)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        icloudConnection.updateConnection(connection: &connection)
                    }
            }
            else if shownSplashScreen && connection.connectionAvailable {
                RootView(data: DataManager(url: connection.rootUrl))
                    .environmentObject(DataManager(url: connection.rootUrl))
                    .environmentObject(SearchIndex(rootUrl: connection.rootUrl))
            }
            

        }
    }
}
