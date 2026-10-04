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
}
