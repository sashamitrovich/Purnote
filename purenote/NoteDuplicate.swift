//
//  NoteDuplicate.swift
//  purenote
//
//  "Duplicate" on the note screen: "<name> 2.md" beside the note, its pictures
//  copied to "<name> 2.assets", and the copy's image references pointing at its
//  own folder so deleting or editing one note never touches the other's pictures.
//

import Foundation

enum NoteDuplicate {

    /// The file the copy goes to: the first free "<stem> 2.md", "<stem> 3.md",
    /// ... where the matching ".assets" folder is free too (a leftover folder
    /// of that name would otherwise receive this copy's pictures).
    static func destination(for noteURL: URL) -> URL {
        let directory = noteURL.deletingPathExtension().deletingLastPathComponent()
        let stem = noteURL.deletingPathExtension().lastPathComponent
        let fm = FileManager.default

        let first = NoteNaming.availableURL(named: stem, in: directory)
        if !fm.fileExists(atPath: NoteAssets.folderURL(for: first).path) { return first }

        for n in 2...500 {
            let candidate = directory.appendingPathComponent("\(stem) \(n)").appendingPathExtension("md")
            if !fm.fileExists(atPath: candidate.path),
               !fm.fileExists(atPath: NoteAssets.folderURL(for: candidate).path) {
                return candidate
            }
        }
        return NoteNaming.availableURL(named: "\(stem) \(UUID().uuidString)", in: directory)
    }

    /// `content` with every image path under the old assets folder moved to the
    /// new one. Only a reference "<folder>/" is rewritten, so the folder's name
    /// appearing in ordinary prose, or inside a longer folder name, is left
    /// alone (see NoteAssets.rewritingReferences).
    static func rewritingReferences(in content: String, from oldFolder: String, to newFolder: String) -> String {
        NoteAssets.rewritingReferences(in: content, from: oldFolder, to: newFolder)
    }

    typealias AssetsCopier = (_ from: URL, _ to: URL) throws -> Void

    /// Writes the copy and returns its URL. `content` is what the screen holds
    /// (it may be ahead of the file). Nothing is overwritten. If the pictures
    /// cannot be copied the new note file is removed again, so no note is left
    /// pointing at pictures it does not have.
    static func duplicate(noteAt noteURL: URL, content: String,
                          copyAssets: AssetsCopier = { try CoordinatedFile.copy(from: $0, to: $1) }) throws -> URL {
        let target = destination(for: noteURL)
        let oldAssets = NoteAssets.folderURL(for: noteURL)
        let newAssets = NoteAssets.folderURL(for: target)
        let hasAssets = FileManager.default.fileExists(atPath: oldAssets.path)

        let text = hasAssets
            ? rewritingReferences(in: content, from: oldAssets.lastPathComponent, to: newAssets.lastPathComponent)
            : content
        try CoordinatedFile.write(text, to: target)

        if hasAssets {
            do { try copyAssets(oldAssets, newAssets) }
            catch {
                try? CoordinatedFile.remove(target)
                try? CoordinatedFile.remove(newAssets)
                throw error
            }
        }
        return target
    }
}
