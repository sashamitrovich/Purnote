//
//  NoteNaming.swift
//  purenote
//

import Foundation

/// Gives a note a filename taken from its first line.
///
/// New notes used to be named with the epoch time in milliseconds, so a folder
/// of them read as 1603814400000.md, 1603814511971.md and so on. The whole
/// point of this app is that the files are yours and are meant to be opened on
/// the Mac, and that is where the naming showed: a directory that looked like
/// a cache rather than a set of notes.
enum NoteNaming {

    /// Characters that cannot go in a filename, plus the leading dot that
    /// would hide the file.
    private static let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")

    private static let maxLength = 60

    /// A filename taken from the first non-empty line, or nil when there is
    /// nothing usable to take.
    static func name(from content: String) -> String? {
        guard let firstLine = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return nil }

        var name = String(firstLine)

        // strip the markdown that marks it up as a heading or a list item,
        // since the user means the words, not the syntax
        name = name.replacingOccurrences(of: "^\\s*(#{1,6}\\s+|[-*+]\\s+(\\[[ xX]\\]\\s*)?|>\\s*)",
                                         with: "", options: .regularExpression)
        name = name.replacingOccurrences(of: "[*_`~]", with: "", options: .regularExpression)

        name = name.components(separatedBy: illegal).joined(separator: "-")
        name = name.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // a name of only dots would be invisible, or worse, "." or ".."
        while name.hasPrefix(".") { name.removeFirst() }
        while name.hasSuffix(".") { name.removeLast() }
        name = name.trimmingCharacters(in: .whitespaces)

        if name.count > maxLength {
            name = String(name.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }

        // a line of nothing but punctuation -- a bare "#", a "---" rule -- is
        // not a title. Emoji count as symbols rather than punctuation, so a
        // note titled with one still gets its name.
        guard name.contains(where: { $0.isLetter || $0.isNumber || $0.isSymbol }) else {
            return nil
        }

        return name.isEmpty ? nil : name
    }

    /// True when this file still carries a generated name, which is the only
    /// case it is safe to rename. A name chosen by the user, or given to the
    /// file on the Mac, is left alone.
    static func isGenerated(_ filename: String) -> Bool {
        let stem = (filename as NSString).deletingPathExtension
        return stem.count >= 12 && stem.allSatisfy(\.isNumber)
    }

    /// The url to rename to, avoiding a name that is already taken.
    static func availableURL(named name: String, in directory: URL) -> URL {
        let fm = FileManager.default
        let candidate = directory.appendingPathComponent(name).appendingPathExtension("md")
        if !fm.fileExists(atPath: candidate.path) { return candidate }

        for suffix in 2...500 {
            let next = directory.appendingPathComponent("\(name) \(suffix)").appendingPathExtension("md")
            if !fm.fileExists(atPath: next.path) { return next }
        }
        return directory.appendingPathComponent("\(name) \(UUID().uuidString)")
            .appendingPathExtension("md")
    }
}
