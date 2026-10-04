//
//  SharedInbox.swift
//  purenote
//

import Foundation

/// The shared hand-off between the share extension and the app, living in the
/// App Group container.
///
/// The extension is a separate process with its own sandbox, so it cannot
/// write into the app's private Documents folder, and it has no view of the
/// app's storage. Everything it needs to know crosses through here:
///
/// - Shared notes arrive as `.md` files under `SharedInbox/`, optionally inside
///   a subfolder matching the folder the user picked at share time.
/// - The app mirrors its folder list into `folders.json` so the extension's
///   picker can offer the same folders.
///
/// The app moves pending notes into its current storage (iCloud Drive or the
/// local Documents folder) on launch/foreground, keeping the chosen folder and
/// creating it if it does not exist yet, and applying the same naming and
/// collision rules it already uses — so a shared post looks like any note the
/// user wrote by hand, whichever storage or folder it ends up in.
enum SharedInbox {

    static let groupIdentifier = "group.com.mitrovic.purenote"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    /// The inbox directory, or nil when the App Group entitlement is missing.
    static var inboxURL: URL? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent("SharedInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Writing a shared note

    /// Writes shared content as a new note inside the given inbox, within the
    /// given folder (empty = the inbox root). Names it from its first line
    /// like any other note.
    @discardableResult
    static func save(_ content: String, to inbox: URL, in folder: String = "") throws -> URL {
        let directory = folder.isEmpty
            ? inbox
            : inbox.appendingPathComponent(folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = NoteNaming.availableURL(named: ShareContent.title(from: content), in: directory)
        try CoordinatedFile.write(content, to: url)
        return url
    }

    // MARK: - Importing into the app

    /// Moves every pending note into the app's current storage root, keeping
    /// the folder each was saved into and creating folders that do not exist
    /// yet. Returns the number of notes moved.
    @discardableResult
    static func importNotes(from inbox: URL, into root: URL) -> Int {
        var moved = 0
        moveNotes(in: inbox, relative: "", into: root, moved: &moved)
        return moved
    }

    private static func moveNotes(in directory: URL, relative: String,
                                  into root: URL, moved: inout Int) {
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(at: directory,
                                                    includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for child in children {
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let rel = relative.isEmpty ? child.lastPathComponent : relative + "/" + child.lastPathComponent
            if isDir {
                moveNotes(in: child, relative: rel, into: root, moved: &moved)
            } else if child.pathExtension == "md" {
                let destinationDir = relative.isEmpty
                    ? root
                    : root.appendingPathComponent(relative, isDirectory: true)
                try? fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
                let stem = child.deletingPathExtension().lastPathComponent
                let destination = NoteNaming.availableURL(named: stem, in: destinationDir)
                do {
                    try CoordinatedFile.move(from: child, to: destination)
                    moved += 1
                } catch {
                    // failed -- leave it for the next launch rather than losing
                    // someone's writing
                    print("Failed to import shared note \(child.lastPathComponent): \(error).")
                }
            }
        }
    }

    // MARK: - Folder catalog

    /// Where the mirrored folder list lives, or nil without the App Group.
    static func catalogURL() -> URL? {
        containerURL?.appendingPathComponent("folders.json")
    }

    /// Writes the folder list to the given location.
    static func writeCatalog(_ folders: [String], to url: URL) {
        let catalog = FolderCatalog(folders: folders.sorted())
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Reads the folder list from the given location, or [] when there is none.
    static func readCatalog(from url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(FolderCatalog.self, from: data) else {
            return []
        }
        return catalog.folders
    }

    /// Every folder under the storage root, as relative paths ("Work",
    /// "Work/Ideas"), skipping hidden folders (`.Trash`, `.purnote`, …) and
    /// everything that is not a folder.
    static func folders(in root: URL) -> [String] {
        var result: [String] = []
        collectFolders(in: root, relative: "", into: &result)
        return result
    }

    /// The direct children of a folder within the catalog, as full relative
    /// paths. An empty `path` means the root of the storage, so its children
    /// are the top-level folders.
    static func childFolders(of path: String, in folders: [String]) -> [String] {
        let prefix = path.isEmpty ? "" : path + "/"
        return folders
            .filter { folder in
                folder.hasPrefix(prefix)
                    && folder.count > prefix.count
                    && !folder.dropFirst(prefix.count).contains("/")
            }
            .sorted()
    }

    private static func collectFolders(in directory: URL, relative: String, into result: inout [String]) {
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(at: directory,
                                                    includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for child in children {
            guard !child.lastPathComponent.hasPrefix("."),
                  !child.lastPathComponent.hasSuffix(".assets") else { continue }
            let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            let rel = relative.isEmpty ? child.lastPathComponent : relative + "/" + child.lastPathComponent
            result.append(rel)
            collectFolders(in: child, relative: rel, into: &result)
        }
    }

    // MARK: - Remembering the last folder

    /// The folder the user shared into last time ("" = never, or top level).
    static func lastSharedFolder() -> String {
        UserDefaults(suiteName: groupIdentifier)?.string(forKey: "lastSharedFolder") ?? ""
    }

    static func rememberSharedFolder(_ folder: String) {
        UserDefaults(suiteName: groupIdentifier)?.set(folder, forKey: "lastSharedFolder")
    }

    /// The folder to suggest as the default: the last one used, when it still
    /// exists in the catalog; otherwise the top level.
    static func suggestedFolder(lastUsed: String, in available: [String]) -> String {
        available.contains(lastUsed) ? lastUsed : ""
    }
}

/// The shape of the mirrored folder list. Kept tiny and Codable so the app and
/// the extension share one format without any third-party dependency.
struct FolderCatalog: Codable, Equatable {
    var folders: [String]
}
