//
//  NoteSort.swift
//  purenote
//
//  How a folder's notes and sub-folders are ordered, as pure functions, and
//  where the per-folder choice is remembered. "Date created" is deliberately
//  not an option: see NoteDates.
//

import Foundation

enum NoteSort: String, CaseIterable {
    case dateEdited
    case title

    /// `dateEdited`: newest first. `title`: case- and diacritic-insensitive,
    /// numbers in natural order ("Note 2" before "Note 10"). Ties never depend
    /// on input order: date ties fall back to title then file name, title ties
    /// to newest first then file name.
    static func sorted(_ notes: [Note], by sort: NoteSort) -> [Note] {
        let keyed = notes.map { (note: $0, title: sortTitle(of: $0)) }
        let ordered = keyed.sorted { lhs, rhs in
            switch sort {
            case .dateEdited:
                if lhs.note.date != rhs.note.date { return lhs.note.date > rhs.note.date }
                let t = compareTitles(lhs.title, rhs.title)
                if t != .orderedSame { return t == .orderedAscending }
                return lhs.note.id < rhs.note.id
            case .title:
                let t = compareTitles(lhs.title, rhs.title)
                if t != .orderedSame { return t == .orderedAscending }
                if lhs.note.date != rhs.note.date { return lhs.note.date > rhs.note.date }
                return lhs.note.id < rhs.note.id
            }
        }
        return ordered.map(\.note)
    }

    /// The first line, as the list shows it. A note still in iCloud has no
    /// readable content yet, so its file name stands in.
    private static func sortTitle(of note: Note) -> String {
        let title = note.isLocal ? NoteRowText.title(of: note.content) : ""
        return title.isEmpty ? note.label : title
    }

    fileprivate static func compareTitles(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive, .numeric],
                  range: nil, locale: Locale(identifier: "en"))
    }
}

enum FolderSort {
    /// Case-insensitive by name, ties by exact name so the order is stable.
    static func sorted(_ folders: [Folder]) -> [Folder] {
        folders.sorted { lhs, rhs in
            let c = NoteSort.compareTitles(lhs.id, rhs.id)
            if c != .orderedSame { return c == .orderedAscending }
            return lhs.id < rhs.id
        }
    }
}

/// The sort chosen for each folder, kept in UserDefaults under the folder's
/// path relative to the library root (the root itself has its own key).
struct SortPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = SortPreferences.defaultStore) {
        self.defaults = defaults
    }

    /// The app's own defaults. A UI-test launch (`-UITestFixture`) gets a store
    /// of its own that lives only as long as the process, so a test that picks
    /// "Title" does not leave the next launch sorted by title.
    static let defaultStore: UserDefaults = {
        guard Storage.isUITestFixture,
              let store = UserDefaults(suiteName: "purnote.uitest.\(UUID().uuidString)") else { return .standard }
        return store
    }()

    static func key(forRelativePath path: String) -> String {
        "noteSort:" + path
    }

    /// `folder` relative to `root`, "" for the root itself. A folder that is
    /// not inside `root` falls back to its full path.
    static func relativePath(of folder: URL, root: URL) -> String {
        let f = folder.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let r = root.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard f.count >= r.count, Array(f.prefix(r.count)) == r else {
            return f.joined(separator: "/")
        }
        return f.dropFirst(r.count).joined(separator: "/")
    }

    func sort(forFolder folder: URL, root: URL) -> NoteSort {
        let key = Self.key(forRelativePath: Self.relativePath(of: folder, root: root))
        return defaults.string(forKey: key).flatMap(NoteSort.init(rawValue:)) ?? .dateEdited
    }

    mutating func set(_ sort: NoteSort, forFolder folder: URL, root: URL) {
        let key = Self.key(forRelativePath: Self.relativePath(of: folder, root: root))
        defaults.set(sort.rawValue, forKey: key)
    }
}
