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
    /// Set when the user chose to carry on without iCloud Drive.
    @AppStorage("useLocalStorage") private var useLocalStorage = false
    @EnvironmentObject var index: SearchIndex
    private let fm = FileManager.default
    var data: DataManager = DataManager(url: URL(fileURLWithPath: ""))

    private var icloudConnection = iCloudConnection()
    @StateObject private var monitor = iCloudMonitor()
    @State var connection = iCloudConnection.getConnection()
    @State private var offerToMove = false

    /// Where the notes actually live. This deliberately does not fall back to
    /// iCloud on its own once it becomes available: switching underneath the
    /// user would leave whatever they wrote locally somewhere they cannot see.
    private var storage: Connection {
        useLocalStorage ? Storage.local() : connection
    }

    private var canStart: Bool {
        useLocalStorage || connection.connectionAvailable
    }
    
    init() {
        print("starting app")
    }

    private func moveToICloud() {
        guard connection.connectionAvailable else { return }
        Storage.move(from: Storage.local().rootUrl, to: connection.rootUrl)
        useLocalStorage = false
    }
    
    var body: some Scene {
        
        WindowGroup {
            
            if !shownSplashScreen || !canStart {
                Splash(shownSplashScreen: $shownSplashScreen,
                       iCloudAvailable: connection.connectionAvailable,
                       tryAgain: { icloudConnection.updateConnection(connection: &connection) },
                       continueWithoutICloud: {
                           useLocalStorage = true
                           shownSplashScreen = true
                       })
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        icloudConnection.updateConnection(connection: &connection)
                    }
            }
            else {
                RootView(data: DataManager(url: storage.rootUrl))
                    .environmentObject(DataManager(url: storage.rootUrl))
                    .environmentObject(SearchIndex(rootUrl: storage.rootUrl))
                    .environmentObject(monitor)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        icloudConnection.updateConnection(connection: &connection)
                        offerToMove = useLocalStorage
                            && connection.connectionAvailable
                            && !Storage.localIsEmpty
                    }
                    .alert("Move your notes to iCloud Drive?", isPresented: $offerToMove) {
                        Button("Move") { moveToICloud() }
                        Button("Not now", role: .cancel) { }
                    } message: {
                        Text("iCloud Drive is available now. Your notes are currently stored on this iPhone only, so they are not on your Mac.")
                    }
            }
            

        }
    }
}
