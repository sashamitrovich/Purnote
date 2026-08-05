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

    /// Re-checks iCloud and decides whether to offer the move.
    ///
    /// url(forUbiquityContainerIdentifier:) blocks, and it keeps returning nil
    /// for a while after iCloud Drive is switched back on, so this asks off the
    /// main thread and gives it a few tries rather than deciding on the first
    /// answer. It also works from the freshly read value rather than reading
    /// the @State back immediately after writing it, which returned the old
    /// connection and was why the prompt never appeared.
    private func refreshConnection() async {
        for delay in [0.0, 1.0, 3.0, 6.0] {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }

            let updated = await Task.detached(priority: .utility) {
                iCloudConnection.getConnection()
            }.value

            connection = updated
            offerToMove = useLocalStorage && updated.connectionAvailable && !Storage.localIsEmpty

            print("iCloud available: \(updated.connectionAvailable), "
                  + "local storage: \(useLocalStorage), "
                  + "local notes: \(!Storage.localIsEmpty) -> offer move: \(offerToMove)")

            if updated.connectionAvailable { return }
        }
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
                       tryAgain: { Task { await refreshConnection() } },
                       continueWithoutICloud: {
                           useLocalStorage = true
                           shownSplashScreen = true
                       })
                    .task { await refreshConnection() }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        Task { await refreshConnection() }
                    }
            }
            else {
                RootView(data: DataManager(url: storage.rootUrl))
                    .environmentObject(DataManager(url: storage.rootUrl))
                    .environmentObject(SearchIndex(rootUrl: storage.rootUrl))
                    .environmentObject(monitor)
                    .task { await refreshConnection() }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        Task { await refreshConnection() }
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
