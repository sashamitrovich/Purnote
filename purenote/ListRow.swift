//
//  ListRow.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

/// A single note in the list: a serif title taken from the note's first line,
/// then one quiet line of "date · preview". The raw file name and the Markdown
/// syntax stay out of the way -- you scan what the note *says*, the way Notes
/// does, but set in a serif that is Purnote's own.
struct ListRow: View {
    var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.isEmpty ? "New note" : title)
                .font(.system(size: 21, weight: .semibold, design: .serif))
                .foregroundColor(title.isEmpty ? .secondary : .primary)
                .lineLimit(1)

            HStack(spacing: 5) {
                Text(dateText)
                    .foregroundColor(.secondary)

                if !preview.isEmpty {
                    Text("·")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                    Text(preview)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 15))
        }
        .padding(.vertical, 5)
    }

    // MARK: - Derived title & preview

    private var lines: [String] {
        note.content.components(separatedBy: .newlines)
    }

    /// The first line with any text on it, as the note's title.
    private var title: String {
        let first = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        return Self.plain(first)
    }

    /// The next line with text after the title, as a one-line preview.
    private var preview: String {
        guard let titleIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }) else { return "" }

        return lines
            .dropFirst(titleIndex + 1)
            .map(Self.plain)
            .first { !$0.isEmpty } ?? ""
    }

    /// Strips the Markdown a person shouldn't have to read in a list: a leading
    /// heading / bullet / checkbox / quote / numbered marker, then the inline
    /// emphasis characters.
    private static func plain(_ raw: String) -> String {
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

    // MARK: - Relative date, Notes style

    private var dateText: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(note.date) {
            return note.date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(note.date) {
            return "Yesterday"
        }
        if let days = calendar.dateComponents([.day], from: note.date, to: Date()).day,
           days < 7 {
            return note.date.formatted(.dateTime.weekday(.wide))
        }
        return note.date.formatted(date: .abbreviated, time: .omitted)
    }
}


struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ListRow(note: Note.sampleNote1)
        }
    }
}
