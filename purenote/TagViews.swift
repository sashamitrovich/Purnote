//
//  TagViews.swift
//  purenote
//

import SwiftUI

/// A list of the notes matching a filter, used as the destination for tags and
/// smart folders. Mirrors the search-results rendering in MenuView.
struct FilteredNotesView: View {
    let notes: [Note]
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex

    var body: some View {
        List {
            if notes.isEmpty {
                HStack {
                    Text("No notes match")
                }
                .placeholderForegroundColor()
            } else {
                ForEach(notes) { note in
                    NavigationLink(destination: NoteView(note: note)
                        .environmentObject(data)
                        .environmentObject(index)
                    ) {
                        ListRow(note: note)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.purnotePaper)
    }
}

/// Every note containing a single tag.
struct TagDestination: View {
    let tag: String
    @EnvironmentObject var index: SearchIndex

    var body: some View {
        FilteredNotesView(notes: index.searchByTags([tag]))
            .navigationTitle("#\(tag)")
    }
}

/// A horizontal row of tappable tag chips, shown at the top of a note.
struct TagChipsRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    NavigationLink(destination: TagDestination(tag: tag)) {
                        Text("#\(tag)")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(Color(UIColor.systemOrange))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemOrange).opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
