//
//  ShareDataApp.swift
//  ShareData
//
//  Created by Saša Mitrović on 02.10.20.
//

import SwiftUI
import UIKit

@main
struct PurenoteApp: App {

    
    
    @AppStorage("shownSplashScreen") var shownSplashScreen = false
    /// Set when the user chose to carry on without iCloud Drive.
    @AppStorage("useLocalStorage") private var useLocalStorage = false
    /// Whether the one-time welcome note has been offered. Kept as a flag rather
    /// than "is the folder empty?" so that a user who deletes every note is left
    /// with an empty library, not one that quietly refills itself.
    @AppStorage("didSeedWelcome") private var didSeedWelcome = false
    @EnvironmentObject var index: SearchIndex
    private let fm = FileManager.default
    var data: DataManager = DataManager(url: URL(fileURLWithPath: ""))

    private var icloudConnection = iCloudConnection()
    @StateObject private var monitor = iCloudMonitor()
    /// Starts empty (unavailable) on purpose: resolving the iCloud connection
    /// calls url(forUbiquityContainerIdentifier:), which blocks and can take
    /// seconds on a fresh install. Doing that synchronously here ran it on the
    /// main thread at launch and let the watchdog kill the app before it drew a
    /// frame. refreshConnection() fills this in from a background task instead.
    @State var connection = Connection()
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
        Self.useSerifNavigationTitles()
    }

    /// Sets navigation-bar titles in a serif, so "Notes", folder names and the
    /// like share the voice of the note titles in the list. Done through the
    /// UINavigationBar appearance proxy because SwiftUI has no serif hook for
    /// the large title itself.
    private static func useSerifNavigationTitles() {
        func serif(_ base: UIFont) -> UIFont {
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: descriptor, size: base.pointSize)
        }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .purnotePaper
        appearance.shadowColor = .clear
        appearance.largeTitleTextAttributes = [.font: serif(.systemFont(ofSize: 34, weight: .bold))]
        appearance.titleTextAttributes = [.font: serif(.systemFont(ofSize: 17, weight: .semibold))]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
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

    /// Writes the sample notes the first time the app runs, so a fresh install
    /// is never a blank screen. Only ever touches an empty library, and only
    /// once, so it can never overwrite or resurrect a user's own notes.
    private func seedSampleLibraryIfNeeded() {
        guard !didSeedWelcome else { return }
        didSeedWelcome = true

        let root = storage.rootUrl
        let monitor = self.monitor

        // The writes are coordinated file I/O (and, on device, iCloud), which is
        // slow and must never run on the main thread at launch. Do it in the
        // background and only hop back to the main actor to refresh the views.
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            let existing = (try? fm.contentsOfDirectory(atPath: root.path))?
                .filter { $0 != ".Trash" } ?? []
            guard existing.isEmpty else { return }

            for note in SampleNotes.all {
                let url = root.appendingPathComponent(note.path)
                let folder = url.deletingLastPathComponent()
                if folder.path != root.path, !fm.fileExists(atPath: folder.path) {
                    try? CoordinatedFile.createDirectory(at: folder, withIntermediateDirectories: true)
                }
                try? CoordinatedFile.write(note.content, to: url)
            }
            await MainActor.run { monitor.bump() }
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
                    .task { seedSampleLibraryIfNeeded() }
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
