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

    // Derived text lives in NoteRowText so it can be unit-tested.
    private var title: String { NoteRowText.title(of: note.content) }
    private var preview: String { NoteRowText.preview(of: note.content) }
    private var dateText: String { NoteRowText.relativeDate(note.date) }
}


struct ListRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ListRow(note: Note.sampleNote1)
        }
    }
}
