//
//  iCloudMonitor.swift
//  purenote
//

import Foundation

/// Watches the app's iCloud Drive folder and reports when anything inside it
/// changes, so a note written on the Mac turns up on the phone by itself.
///
/// The app used to find out about changes only when asked -- onAppear, coming
/// back to the foreground, or pull to refresh -- which meant editing on the
/// Mac and then looking at the phone showed stale content until you knew to
/// pull down. That is the one thing the app promises, so it should not be the
/// user's job.
final class iCloudMonitor: ObservableObject {

    /// Bumped whenever something in the container changes. Views watch this
    /// rather than the query itself.
    @Published private(set) var changeCount = 0

    /// iCloud reports a burst of updates while it writes or downloads a file.
    /// Reacting to each one would re-read and re-index the whole tree several
    /// times over for what the user did once.
    private static let coalesceWindow: TimeInterval = 0.6

    private let query = NSMetadataQuery()
    private var observers: [NSObjectProtocol] = []
    private var coalescing: Timer?

    init() {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")

        // deliver on the main queue: everything this wakes up is view state
        query.operationQueue = .main

        for name in [Notification.Name.NSMetadataQueryDidFinishGathering,
                     Notification.Name.NSMetadataQueryDidUpdate] {
            let observer = NotificationCenter.default.addObserver(
                forName: name, object: query, queue: .main
            ) { [weak self] _ in
                self?.changed()
            }
            observers.append(observer)
        }

        // does nothing useful when there is no ubiquity container -- the
        // simulator, or iCloud Drive switched off -- and the existing refresh
        // paths still cover that case
        query.start()
        query.enableUpdates()
    }

    deinit {
        coalescing?.invalidate()
        query.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func changed() {
        coalescing?.invalidate()
        coalescing = Timer.scheduledTimer(withTimeInterval: Self.coalesceWindow,
                                          repeats: false) { [weak self] _ in
            self?.changeCount += 1
        }
    }
}
