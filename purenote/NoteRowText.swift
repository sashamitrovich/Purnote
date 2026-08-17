//
//  NoteRowText.swift
//  purenote
//
//  The pure text derivation behind a note row -- title, one-line preview, the
//  Markdown stripping that keeps syntax out of the list, and the Notes-style
//  relative date. Kept out of the SwiftUI view so it can be unit-tested.
//

import Foundation

enum NoteRowText {

    /// The first non-empty line of a note, stripped of Markdown, as its title.
    static func title(of content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let first = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        return plain(first)
    }

    /// The next non-empty line after the title, stripped, as a one-line preview.
    static func preview(of content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        guard let titleIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }) else { return "" }

        return lines
            .dropFirst(titleIndex + 1)
            .map(plain)
            .first { !$0.isEmpty } ?? ""
    }

    /// Strips the Markdown a person shouldn't have to read in a list: a leading
    /// heading / bullet / checkbox / quote / numbered marker, then the inline
    /// emphasis characters.
    static func plain(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespaces)

        for marker in ["- [ ] ", "- [x] ", "- [X] ", "### ", "## ", "# ", "> ", "- ", "* ", "+ "] {
            if t.hasPrefix(marker) { t.removeFirst(marker.count); break }
        }
        if let ordered = t.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
            t.removeSubrange(ordered)
        }

        t = String(t.filter { !"*_`~".contains($0) })
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Notes-style relative date: the time today, "Yesterday", a weekday within
    /// the last week, otherwise the date. `now`/`calendar` are injectable so the
    /// branch selection can be tested deterministically.
    static func relativeDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
