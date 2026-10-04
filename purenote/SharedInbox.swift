//
//  SharedInbox.swift
//  purenote
//

import Foundation

/// The shared drop-box between the share extension and the app.
///
/// The extension is a separate process with its own sandbox, so it cannot
/// write into the app's private Documents folder. The App Group container is
/// the one place both are allowed to reach. Shared notes land here as ordinary
/// `.md` files, and the app moves them into its current storage — iCloud Drive,
/// or the local Documents folder when the user has chosen to stay local — the
/// next time it opens, applying the same naming and collision rules the app
/// already uses. So a shared post looks exactly like a note the user wrote by
/// hand, whichever storage it ends up in.
enum SharedInbox {

    static let groupIdentifier = "group.com.mitrovic.purenote"

    /// The inbox directory inside the App Group container, or nil when the
    /// App Group entitlement is missing (the group not registered for the
    /// development team). Callers treat nil as "no shared storage" and carry
    /// on without it.
    static var inboxURL: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier) else {
            return nil
        }
        let url = container.appendingPathComponent("SharedInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes shared content as a new note file inside the given inbox, named
    /// from its first line like any other note.
    @discardableResult
    static func save(_ content: String, to inbox: URL) throws -> URL {
        let url = NoteNaming.availableURL(named: ShareContent.title(from: content), in: inbox)
        try CoordinatedFile.write(content, to: url)
        return url
    }

    /// The `.md` files currently waiting in the inbox. Subfolders and other
    /// file types are ignored.
    static func pendingNotes(in inbox: URL) -> [URL] {
        let fm = FileManager.default
        return ((try? fm.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.hasDirectoryPath && $0.pathExtension == "md" }
    }

    /// Moves every pending note into the app's current storage root, avoiding
    /// name clashes. Returns the number of notes moved.
    @discardableResult
    static func importNotes(from inbox: URL, into root: URL) -> Int {
        var moved = 0
        for note in pendingNotes(in: inbox) {
            let stem = note.deletingPathExtension().lastPathComponent
            let destination = NoteNaming.availableURL(named: stem, in: root)
            do {
                try CoordinatedFile.move(from: note, to: destination)
                moved += 1
            } catch {
                // failed -- leave it in the inbox for the next launch rather
                // than losing someone's writing
                print("Failed to import shared note \(note.lastPathComponent): \(error).")
            }
        }
        return moved
    }
}
