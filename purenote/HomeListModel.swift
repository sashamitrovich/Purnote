//
//  HomeListModel.swift
//  purenote
//
//  What the home / folder screen shows, as a pure function of the notes in the
//  folder, the pinned notes, the sort and whether this is the library root.
//  The views only draw it; every rule (pins only at the root, a pinned note not
//  repeated in the months, Title sort being a plain list, the empty states, the
//  count and sort wording) lives here so it can be tested without a screen.
//

import Foundation

extension NoteSort {
    /// How the sort is named in the menu and under the masthead.
    var displayName: String {
        switch self {
        case .dateEdited: return "Date Edited"
        case .title: return "Title"
        }
    }
}

struct HomeListModel {

    /// What the left margin of a row holds.
    enum Margin: Equatable {
        /// A pinned note: the amber ribbon instead of a date.
        case ribbon
        /// The day of the month and the short weekday ("12", "Thu").
        case day(number: Int, weekday: String)
        /// Nothing (the Title sort has no dates).
        case none
    }

    struct Entry: Identifiable {
        let note: Note
        let margin: Margin
        /// The note's place on disk, not its file name: two folders can each
        /// hold an "Untitled.md", and a pinned note from another folder sits
        /// next to the notes of this one.
        var id: String { HomeListModel.key(of: note) }
    }

    struct Section: Identifiable {
        enum Kind { case pinned, month, flat }
        let id: String
        let kind: Kind
        /// "Pinned", "November 2026", or nil for the plain list.
        let title: String?
        let entries: [Entry]
    }

    enum EmptyState: Equatable {
        /// The library root with no notes, no folders and no pins: the big "clean sheet".
        case library
        /// A folder with nothing in it.
        case folder
        /// No notes here, but there are folders (or smart folders) to go into.
        case noNotes
    }

    let sections: [Section]
    let title: String
    let titleIsLong: Bool
    let isRoot: Bool
    let sort: NoteSort
    let noteCount: Int
    let emptyState: EmptyState?

    /// Names longer than this use the smaller masthead (38 instead of 44 pt).
    static let longTitleLength = 14

    /// - Parameters:
    ///   - notes: the notes in this folder (any order).
    ///   - pinned: every pinned note in the library, in pin order. Only used at the root.
    ///   - hasFolders: whether there are folders or smart folders to show above the notes.
    init(notes: [Note], pinned: [Note], sort: NoteSort, isRoot: Bool, folderName: String,
         hasFolders: Bool, now: Date, calendar: Calendar) {
        self.isRoot = isRoot
        self.sort = sort
        self.noteCount = notes.count
        self.title = isRoot ? "Purnote" : folderName
        self.titleIsLong = self.title.count > HomeListModel.longTitleLength

        let pins = isRoot ? pinned : []
        let pinnedKeys = Set(pins.map(HomeListModel.key(of:)))
        let rest = NoteSort.sorted(notes, by: sort).filter { !pinnedKeys.contains(HomeListModel.key(of: $0)) }

        var built: [Section] = []
        if !pins.isEmpty {
            built.append(Section(id: "pinned", kind: .pinned, title: "Pinned",
                                 entries: pins.map { Entry(note: $0, margin: .ribbon) }))
        }
        switch sort {
        case .dateEdited:
            for group in NoteGrouping.byMonth(rest, now: now, calendar: calendar) {
                built.append(Section(
                    id: "month-" + group.title, kind: .month, title: group.title,
                    entries: group.notes.map {
                        Entry(note: $0, margin: .day(number: group.day(of: $0), weekday: group.weekday(of: $0)))
                    }))
            }
        case .title:
            if !rest.isEmpty {
                built.append(Section(id: "flat", kind: .flat, title: nil,
                                     entries: rest.map { Entry(note: $0, margin: .none) }))
            }
        }
        self.sections = built

        if notes.isEmpty && pins.isEmpty {
            emptyState = hasFolders ? .noNotes : (isRoot ? .library : .folder)
        } else {
            emptyState = nil
        }
    }

    // MARK: Masthead text

    /// "No notes yet", "1 note", "2 notes".
    var countText: String {
        switch noteCount {
        case 0: return "No notes yet"
        case 1: return "1 note"
        default: return "\(noteCount) notes"
        }
    }

    var sortName: String { sort.displayName }

    /// The root shows the count (and where the notes live, when that is known);
    /// a folder shows the count and its sort, which is tappable.
    var showsSort: Bool { !isRoot }

    func metaLine(location: String?) -> String {
        var parts = [countText]
        if showsSort { parts.append(sortName) }
        if isRoot, let location, !location.isEmpty { parts.append(location) }
        return parts.joined(separator: " · ")
    }

    // MARK: Identity

    /// Folder path plus the real file name, so a not-downloaded note
    /// (".Note.md.icloud") and the note itself are the same note.
    static func key(of note: Note) -> String {
        let url = note.url.standardizedFileURL
        let folder = url.deletingLastPathComponent().path
        return folder + "/" + PinPath.realName(ofPlaceholder: url.lastPathComponent)
    }
}
