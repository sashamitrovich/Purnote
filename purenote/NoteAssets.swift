//
//  NoteAssets.swift
//  purenote
//

import Foundation

/// The sibling-folder layout that keeps attachments as ordinary files.
///
/// A note `My Note.md` with an image stores it as `My Note.assets/photo.jpg`
/// and references it from Markdown with a relative path, so the note plus its
/// images are just files: they sync to the Mac, open in any viewer, and
/// survive abandoning Purnote. The folder name is fixed at first attachment
/// and never renames — that keeps the relative reference valid even when the
/// note itself is renamed (on the Mac, where nothing rewrites the Markdown).
enum NoteAssets {

    /// The folder beside a note that holds its attachments.
    static func folderURL(for noteURL: URL) -> URL {
        let stem = noteURL.deletingPathExtension().lastPathComponent
        return noteURL.deletingLastPathComponent()
            .appendingPathComponent(stem + ".assets", isDirectory: true)
    }

    /// Writes image data into the note's assets folder and returns the
    /// relative path to reference from Markdown (e.g. `My Note.assets/photo.jpg`).
    @discardableResult
    static func addImage(_ data: Data, fileExtension: String, to noteURL: URL) throws -> String {
        let folder = folderURL(for: noteURL)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = uniqueName(in: folder, fileExtension: fileExtension)
        try CoordinatedFile.write(data, to: folder.appendingPathComponent(name))
        return folder.lastPathComponent + "/" + name
    }

    /// The Markdown image reference for a relative path. Angle-bracketed so
    /// spaces and punctuation in the folder/file names stay valid CommonMark
    /// (and render on the Mac, not just in Purnote).
    static func imageMarkdown(relativePath: String) -> String {
        "![](<\(relativePath)>)"
    }

    /// Moves the note's assets folder to the note's new location, keeping the
    /// folder's existing name so references stay valid. Call this whenever a
    /// note file is moved between directories (never on a plain rename, where
    /// the folder should stay put). No-op when there is no assets folder.
    static func moveAssetsFolder(forNoteAt oldNoteURL: URL, to newNoteURL: URL) throws {
        let source = folderURL(for: oldNoteURL)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let target = newNoteURL.deletingLastPathComponent()
            .appendingPathComponent(source.lastPathComponent)
        guard source.path != target.path else { return }
        try CoordinatedFile.move(from: source, to: target)
    }

    /// Moves the note's assets folder to the Trash alongside the note.
    static func trashAssetsFolder(forNoteAt noteURL: URL) throws {
        let folder = folderURL(for: noteURL)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        try CoordinatedFile.trash(folder)
    }

    private static func uniqueName(in folder: URL, fileExtension: String) -> String {
        let fm = FileManager.default
        var name = "image." + fileExtension
        var suffix = 2
        while fm.fileExists(atPath: folder.appendingPathComponent(name).path) {
            name = "image \(suffix)." + fileExtension
            suffix += 1
        }
        return name
    }
}
