//
//  ShareContent.swift
//  purenote
//

import Foundation

/// Turns whatever the user shared into the body of a note.
///
/// The share sheet can hand over text, a URL, or both. A social post is
/// usually the post's words plus a link back to it, while "copy link" gives
/// only a URL. Both belong in the note: the words the user read, and the way
/// back to where they read them.
///
/// This is pure logic with no UIKit on purpose, so the app's unit tests can
/// cover it directly and the share extension compiles the same file.
enum ShareContent {

    /// Builds a note body from the pieces a share extension receives.
    ///
    /// A URL is appended on its own line rather than inlined, so the note keeps
    /// a way back to the original post without the link crowding the words.
    static func note(text: String?, url: String?) -> String {
        let body = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let link = (url ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch (body.isEmpty, link.isEmpty) {
        case (true, true):
            return ""
        case (false, true):
            return body
        case (true, false):
            return link
        case (false, false):
            return body + "\n\n" + link
        }
    }

    /// A filename stem for the note. Prefer a name taken from the first line —
    /// what the app itself does — and fall back to a clearly-generated name
    /// when the shared content has nothing readable to take one from (a bare
    /// URL of punctuation, or nothing at all).
    static func title(from content: String) -> String {
        if let name = NoteNaming.name(from: content) {
            return name
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }

    /// Where a shared note will land and what its file will be called, for
    /// the line under the title in the share sheet.
    ///
    /// `fileName` is the name `save` will give the file in the inbox (the same
    /// `NoteNaming` rule as `title(from:)`). It is nil when the content has
    /// nothing readable to name a file from: the fallback is a timestamp taken
    /// at the moment of saving, so it cannot be shown before. The app may still
    /// add a " 2" when it files the note into storage that already holds a note
    /// of that name; the extension cannot see that storage.
    struct SaveTarget: Equatable {
        /// "Notes" for the top level, otherwise the folder's own name.
        let folderName: String
        let fileName: String?

        /// "Travel \u{00B7} saves as Tile museum.md", or "Travel \u{00B7} named when saved".
        var line: String {
            if let fileName {
                return "\(folderName) \u{00B7} saves as \(fileName)"
            }
            return "\(folderName) \u{00B7} named when saved"
        }
    }

    static func saveTarget(folder: String, content: String) -> SaveTarget {
        let folderName = folder.isEmpty ? "Notes" : (folder as NSString).lastPathComponent
        let fileName = NoteNaming.name(from: content).map { $0 + ".md" }
        return SaveTarget(folderName: folderName, fileName: fileName)
    }
}
