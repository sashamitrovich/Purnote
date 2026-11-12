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

    /// Whether the app may rename a note's file to match its first line.
    ///
    /// Only a name the app made itself is the app's to change: a generated
    /// timestamp name, or the name it derived from the first line the note had
    /// before this edit (optionally followed by the duplicate number " 2",
    /// " 3", ... that availableURL adds). Anything else was chosen by the user,
    /// on the phone or on the Mac, and is left alone even when the first line
    /// changes.
    ///
    /// `previousContent` is the text the note had when editing opened. Autosave
    /// overwrites the stored content while typing, so it has to be captured
    /// before the first keystroke.
    static func mayRename(stem: String, previousContent: String?) -> Bool {
        if isGenerated(stem + ".md") { return true }
        guard let previousContent, let derived = name(from: previousContent) else { return false }
        return stem == derived || isNumberedDuplicate(stem, of: derived)
    }

    /// "Shopping 2", "Shopping 17" are duplicates of "Shopping"; "Shopping 1"
    /// and "Shopping 2x" are not.
    private static func isNumberedDuplicate(_ stem: String, of base: String) -> Bool {
        guard stem.hasPrefix(base + " ") else { return false }
        let tail = stem.dropFirst(base.count + 1)
        guard !tail.isEmpty, tail.allSatisfy({ $0.isASCII && $0.isNumber }),
              let n = Int(tail) else { return false }
        return n >= 2
    }

    /// The url to rename to, avoiding a name that is already taken.
    ///
    /// `excluding` is the note's own file: it does not count as taken, so a
    /// note called "Shopping 2" asking for the name "Shopping" gets its own
    /// url back rather than drifting on to "Shopping 3".
    static func availableURL(named name: String, in directory: URL, excluding: URL? = nil) -> URL {
        let fm = FileManager.default

        func isFree(_ url: URL) -> Bool {
            if !fm.fileExists(atPath: url.path) { return true }
            guard let excluding else { return false }
            if url.standardizedFileURL.path == excluding.standardizedFileURL.path { return true }
            // a rename that only changes case names the same file on a
            // case-insensitive volume
            if url.path.caseInsensitiveCompare(excluding.path) == .orderedSame {
                let a = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
                let b = try? excluding.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
                if let a, let b { return a.isEqual(b) }
            }
            return false
        }

        let candidate = directory.appendingPathComponent(name).appendingPathExtension("md")
        if isFree(candidate) { return candidate }

        for suffix in 2...500 {
            let next = directory.appendingPathComponent("\(name) \(suffix)").appendingPathExtension("md")
            if isFree(next) { return next }
        }
        return directory.appendingPathComponent("\(name) \(UUID().uuidString)")
            .appendingPathExtension("md")
    }
}
