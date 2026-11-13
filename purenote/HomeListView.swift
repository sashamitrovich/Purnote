//
//  HomeListView.swift
//  purenote
//
//  The pieces of the 1.5 home / folder screen that only draw: the masthead, the
//  section headings, the margin column of a note row, the ribbon, the empty
//  states and the Sort entries of the "..." menu. What they show is decided in
//  HomeListModel. Colours come only from `Color.pn`; type only from PurnoteType.
//

import SwiftUI

// MARK: - Masthead

/// The folder name in large New York, the count line under it, and the heavy
/// ink rule. In a folder the sort name in the count line opens the sort choice.
struct HomeMasthead: View {
    let model: HomeListModel
    /// "iCloud Drive" / "On this iPhone" at the root, when the screen knows it.
    var location: String? = nil
    let onSort: (NoteSort) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.title)
                .font(PurnoteType.Twin.masthead(long: model.titleIsLong))
                .tracking(PurnoteType.mastheadTracking)
                .foregroundColor(Color.pn.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("home.masthead")

            meta

            Rectangle()
                .fill(Color.pn.ink)
                .frame(height: 1.5)
                .padding(.top, 6)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var meta: some View {
        if model.showsSort {
            HStack(spacing: 6) {
                Text(model.countText)
                    .accessibilityIdentifier("home.meta")
                Text("·").foregroundColor(Color.pn.ink3).accessibilityHidden(true)
                Menu {
                    ForEach(NoteSort.allCases, id: \.self) { sort in
                        SortChoice(sort: sort, current: model.sort, idPrefix: "home.sort") { onSort(sort) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(model.sortName)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(Color.pn.ribbonText)
                }
                .accessibilityLabel("Sort: \(model.sortName)")
                .accessibilityIdentifier("home.sortButton")
            }
            .font(PurnoteType.Twin.meta())
            .foregroundColor(Color.pn.ink2)
        } else {
            Text(model.metaLine(location: location))
                .font(PurnoteType.Twin.meta())
                .foregroundColor(Color.pn.ink2)
                .accessibilityIdentifier("home.meta")
        }
    }
}

/// One sort entry: its name, with a checkmark when it is the current one.
struct SortChoice: View {
    let sort: NoteSort
    let current: NoteSort
    /// "menu.sort" gives menu.sort.dateEdited / menu.sort.title.
    let idPrefix: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if sort == current {
                Label(sort.displayName, systemImage: "checkmark")
            } else {
                Text(sort.displayName)
            }
        }
        .accessibilityIdentifier("\(idPrefix).\(sort.rawValue)")
    }
}

// MARK: - Section heading

/// "PINNED" / "NOVEMBER 2026": small SF capitals and a hairline that runs to the edge.
struct HomeSectionHeader: View {
    let title: String
    let identifier: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title.uppercased())
                .font(PurnoteType.Twin.caps())
                .tracking(PurnoteType.capsTracking)
                .foregroundColor(Color.pn.ink2)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
            Rectangle()
                .fill(Color.pn.rule)
                .frame(height: 1)
        }
        .padding(.top, 22)
        .padding(.bottom, 4)
    }
}

// MARK: - The margin

/// A small bookmark ribbon with a notch, in amber.
struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.28))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The left margin of a row: the day and weekday, the ribbon, or nothing.
private struct MarginColumn: View {
    let margin: HomeListModel.Margin

    var body: some View {
        switch margin {
        case .ribbon:
            RibbonShape()
                .fill(Color.pn.ribbon)
                .frame(width: 11, height: 17)
                .padding(.top, 4)
        case .day(let number, let weekday):
            VStack(alignment: .leading, spacing: 0) {
                Text("\(number)")
                    .font(PurnoteType.Twin.marginDay())
                    .foregroundColor(Color.pn.ink)
                Text(weekday.uppercased())
                    .font(PurnoteType.Twin.caps())
                    .tracking(PurnoteType.capsTracking)
                    .foregroundColor(Color.pn.ink2)
            }
        case .none:
            Color.clear
        }
    }
}

// MARK: - A note row

/// A note in the list: the margin on the left, title and preview on the right.
///
/// Dynamic Type: the margin column is sized with `ScaledMetric`, so it grows
/// with the text. From the accessibility sizes up there is no room for a column
/// beside the title, so the margin is dropped and the date goes on a line of
/// its own above the title ("THU 12").
struct HomeNoteRow: View {
    let entry: HomeListModel.Entry
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var marginWidth: CGFloat = 36

    private var isPinned: Bool { entry.margin == .ribbon }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                if case .day(let number, let weekday) = entry.margin {
                    Text("\(weekday.uppercased()) \(number)")
                        .font(PurnoteType.Twin.caps())
                        .tracking(PurnoteType.capsTracking)
                        .foregroundColor(Color.pn.ink2)
                        .accessibilityHidden(true)
                }
                ListRow(note: entry.note, showsDate: false, previewLines: isPinned ? 2 : 1)
            }
            .padding(.vertical, 5)
        } else {
            HStack(alignment: .top, spacing: 0) {
                MarginColumn(margin: entry.margin)
                    .frame(width: marginWidth, alignment: .leading)
                    .accessibilityHidden(true)
                ListRow(note: entry.note, showsDate: false, previewLines: isPinned ? 2 : 1)
            }
            .padding(.vertical, 5)
        }
    }
}

// MARK: - Empty states

/// What the screen says when there is nothing to list. Plain words, set in the
/// note typeface; no promise about where the files live beyond what is always true.
struct HomeEmptyState: View {
    let state: HomeListModel.EmptyState
    let onNewNote: () -> Void
    let onNewFolder: () -> Void

    var body: some View {
        switch state {
        case .library:
            block(heading: "A clean sheet.",
                  text: "Each note you write becomes a plain .md file. Folders you make here are real folders.",
                  showsNewFolder: true)
        case .folder:
            block(heading: "Nothing here yet.",
                  text: "Write a note, or drop .md files into this folder from the Files app. They show up here as they are.",
                  showsNewFolder: false)
        case .noNotes:
            HStack(spacing: 4) {
                Text("Tap the")
                Image(systemName: "square.and.pencil")
                Text("button to create a new note")
            }
            .font(PurnoteType.Twin.meta())
            .placeholderForegroundColor()
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func block(heading: String, text: String, showsNewFolder: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(heading)
                .font(PurnoteType.Twin.h2())
                .foregroundColor(Color.pn.ink)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(PurnoteType.Twin.body())
                .foregroundColor(Color.pn.ink2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(action: onNewNote) {
                    Text("Write a note")
                        .font(PurnoteType.Twin.ui(weight: .semibold))
                        .foregroundColor(Color.pn.page)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .background(Color.pn.ribbon, in: Capsule())
                }
                .accessibilityIdentifier("home.empty.newNote")
                if showsNewFolder {
                    Button(action: onNewFolder) {
                        Text("New folder")
                            .font(PurnoteType.Twin.ui(weight: .semibold))
                            .foregroundColor(Color.pn.ink)
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(Color.pn.fill, in: Capsule())
                    }
                    .accessibilityIdentifier("home.empty.newFolder")
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
