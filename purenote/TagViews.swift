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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if notes.isEmpty {
                    HStack {
                        Text("No notes match")
                    }
                    .placeholderForegroundColor()
                    .menuRowStyle()
                } else {
                    ForEach(notes) { note in
                        NavigationLink(destination: NoteView(note: note)
                            .environmentObject(data)
                            .environmentObject(index)
                        ) {
                            ListRow(note: note)
                        }
                        .menuRowStyle()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color.pn.page)
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

/// The note's tags, shown under the text: a caps label, a row of tappable
/// chips and a line saying where tags come from.
struct TagChipsRow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Color.pn.rule).frame(height: 1)
            Text("TAGS")
                .font(PurnoteType.Twin.caps())
                .tracking(PurnoteType.capsTracking)
                .foregroundColor(Color.pn.ink2)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        NavigationLink(destination: TagDestination(tag: tag)) {
                            HStack(spacing: 1) {
                                Text("#").foregroundColor(Color.pn.ink3)
                                Text(tag).foregroundColor(Color.pn.ink2)
                            }
                            .font(PurnoteType.Twin.ui())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(Color.pn.rule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("#\(tag)")
                    }
                }
            }
            Text("Tags are words in the note that start with #. Tap one to see every note that has it.")
                .font(PurnoteType.Twin.meta())
                .foregroundColor(Color.pn.ink2)
        }
    }
}
