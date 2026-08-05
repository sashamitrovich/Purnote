//
//  Storage.swift
//  purenote
//

import Foundation

/// Where the notes live when iCloud Drive is not available.
///
/// The app is plain files in a directory, and a directory does not have to be
/// an iCloud one. Without this the app refused to start at all when iCloud
/// Drive was switched off, not signed in, out of space, or restricted -- none
/// of which is necessarily the user's to fix at that moment.
enum Storage {

    private static let fm = FileManager.default

    /// The app's own Documents directory. Private to the app and not synced,
    /// but the notes are still ordinary .md files.
    static func local() -> Connection {
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return Connection(rootUrl: root, connectionAvailable: true, isLocal: true)
    }

    static var localIsEmpty: Bool {
        let contents = (try? fm.contentsOfDirectory(atPath: local().rootUrl.path)) ?? []
        return contents.filter { $0 != ".Trash" }.isEmpty
    }

    /// Moves everything from one root into another, recursively.
    ///
    /// Nothing is overwritten and nothing is left behind. A note whose name is
    /// already taken at the destination is moved under a free name instead --
    /// skipping it would leave it in a directory the app has stopped looking
    /// at, which is a quieter way to lose someone's writing than overwriting
    /// it. Folders of the same name are merged.
    @discardableResult
    static func move(from source: URL, to destination: URL) -> (moved: Int, renamed: Int, failed: Int) {
        var moved = 0, renamed = 0, failed = 0

        let items = (try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent != ".Trash" {
            let taken = destination.appendingPathComponent(item.lastPathComponent)

            if item.hasDirectoryPath && fm.fileExists(atPath: taken.path) {
                let result = move(from: item, to: taken)
                moved += result.moved
                renamed += result.renamed
                failed += result.failed
                // the folder itself is gone once it has been emptied
                try? fm.removeItem(at: item)
                continue
            }

            let target = freeName(for: item, in: destination)
            do {
                try CoordinatedFile.move(from: item, to: target)
                if target != taken { renamed += 1 } else { moved += 1 }
            }
            catch {
                // failed
                print("Failed to move \(item.lastPathComponent) to iCloud: \(error).")
                failed += 1
            }
        }

        return (moved, renamed, failed)
    }

    /// `note.md` -> `note (from iPhone).md`, then `note (from iPhone 2).md`.
    private static func freeName(for item: URL, in destination: URL) -> URL {
        let target = destination.appendingPathComponent(item.lastPathComponent)
        guard fm.fileExists(atPath: target.path) else { return target }

        let ext = item.pathExtension
        let stem = item.deletingPathExtension().lastPathComponent

        for suffix in 1...500 {
            let name = suffix == 1 ? "\(stem) (from iPhone)" : "\(stem) (from iPhone \(suffix))"
            let candidate = destination.appendingPathComponent(name).appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return destination.appendingPathComponent("\(stem) (from iPhone \(UUID().uuidString))")
            .appendingPathExtension(ext)
    }
}
