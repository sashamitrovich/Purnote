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
    /// When set, shown in place of the relative date — used by search results
    /// for a note living in another folder, so it is clear where it lives.
    var location: String? = nil
    /// When set, shown in place of the second-line preview: the line of the
    /// note that matched a search.
    var snippet: String? = nil
    /// False on the home list, where the date lives in the margin column.
    var showsDate: Bool = true
    /// How many lines of preview to allow (pinned notes get two).
    var previewLines: Int = 1

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.isEmpty ? "New note" : title)
                .font(PurnoteType.Twin.rowTitle())
                .foregroundColor(title.isEmpty ? Color.pn.ink2 : Color.pn.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)

            if showsDate {
                HStack(spacing: 5) {
                    Text(location ?? dateText)
                        .font(PurnoteType.Twin.meta())
                        .foregroundColor(Color.pn.ink2)

                    if !preview.isEmpty {
                        Text("·")
                            .foregroundColor(Color.pn.ink3)
                            .accessibilityHidden(true)
                        previewText
                    }
                }
            } else if !preview.isEmpty {
                previewText
            }
        }
        // title, date and preview read as one element
        .accessibilityElement(children: .combine)
    }

    private var previewText: some View {
        Text(preview)
            .font(PurnoteType.Twin.rowPreview())
            .foregroundColor(Color.pn.ink2)
            .lineLimit(typeSize.isAccessibilitySize ? 3 : previewLines)
    }

    // Derived text lives in NoteRowText so it can be unit-tested.
    private var title: String { NoteRowText.title(of: note.content) }
    private var preview: String { snippet ?? NoteRowText.preview(of: note.content) }
    private var dateText: String { NoteRowText.relativeDate(note.date) }
}


struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ListRow(note: Note.sampleNote1)
        }
    }
}
