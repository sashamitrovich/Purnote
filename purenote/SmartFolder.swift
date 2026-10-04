//
//  SmartFolder.swift
//  purenote
//

import Foundation

/// A saved filter over the library: a name plus a set of tags. A note matches
/// when it contains every one of the tags. (Nothing here touches a note's
/// content — matching is done against the tags already indexed from the `.md`
/// text.)
struct SmartFolder: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var tags: [String]

    func matches(noteTags: Set<String>) -> Bool {
        guard !tags.isEmpty else { return false }
        let note = Set(noteTags.map { $0.lowercased() })
        return tags.allSatisfy { note.contains($0.lowercased()) }
    }
}

/// Loads and saves the smart-folder list. It lives in a single readable JSON
/// sidecar under `.purnote/` in the storage root, so the notes themselves stay
/// plain files and the filters stay portable (and deleteable) without touching
/// anyone's writing.
enum SmartFolderStore {

    static let directoryName = ".purnote"
    static let fileName = "smartfolders.json"

    static func fileURL(in root: URL) -> URL {
        root.appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func load(from root: URL) -> [SmartFolder] {
        guard let data = try? Data(contentsOf: fileURL(in: root)),
              let folders = try? JSONDecoder().decode([SmartFolder].self, from: data) else {
            return []
        }
        return folders
    }

    static func save(_ folders: [SmartFolder], to root: URL) throws {
        let directory = fileURL(in: root).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(folders)
        try data.write(to: fileURL(in: root), options: .atomic)
    }
}
