//
//  RecentSearches.swift
//  purenote
//
//  The last few things searched for, newest first. Pure: the store is passed in.
//

import Foundation

struct RecentSearches {
    static let limit = 8

    private(set) var items: [String]
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "recentSearches") {
        self.defaults = defaults
        self.key = key
        // a value of the wrong type is ignored rather than trusted
        let stored = defaults.array(forKey: key) as? [String] ?? []
        items = Array(stored.prefix(Self.limit))
    }

    /// Puts a search first. Blank searches are ignored, and a search that is
    /// already there (any capitalisation) moves up under its new spelling.
    mutating func add(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        items.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
        items.insert(q, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        save()
    }

    mutating func remove(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        items.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
        save()
    }

    mutating func clear() {
        items = []
        save()
    }

    private func save() { defaults.set(items, forKey: key) }
}
