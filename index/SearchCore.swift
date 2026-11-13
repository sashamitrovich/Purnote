//
//  SearchCore.swift
//  purenote
//
//  The pure part of search: how text is folded and split into words, the
//  in-memory index data (word -> notes, note -> its words), matching, ranking,
//  scope, and the matching-line snippet. No file access and no threads here --
//  SearchIndex owns those and publishes copies of `SearchData`, which is a
//  value type, so a copy handed to a view can never change under it.
//

import Foundation

// MARK: - Text

enum SearchText {

    /// Lowercase with diacritics removed, so "cafe" finds "Café". Only the
    /// accent is dropped: "ü" does not become "ue".
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static let separators = CharacterSet.punctuationCharacters
        .union(.whitespacesAndNewlines)

    /// The folded words of a text, in order. Punctuation separates words; the
    /// same rule is used for notes and for queries, so they always agree.
    static func tokens(_ s: String) -> [String] {
        fold(s).components(separatedBy: separators).filter { !$0.isEmpty }
    }

    // MARK: Snippet

    /// The first line *after the title* that has a word starting with one of
    /// the query words, with Markdown syntax removed, and where in that text
    /// the match is. Nil when there is no such line -- the match is only in
    /// the title -- or the query has no words.
    static func snippet(in content: String, query: String) -> SearchSnippet? {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return nil }

        let lines = content.components(separatedBy: .newlines)
        guard let titleIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }) else { return nil }

        for raw in lines.dropFirst(titleIndex + 1) {
            let lineTokens = tokens(raw)
            let hit = queryTokens.contains { q in lineTokens.contains { $0.hasPrefix(q) } }
            guard hit else { continue }

            let text = stripMarkdown(raw)
            guard !text.isEmpty else { continue }
            return SearchSnippet(text: text, matchRange: matchRange(of: queryTokens, in: text))
        }
        return nil
    }

    /// The Markdown a person should not have to read in a result row: a
    /// leading heading / checkbox / bullet / quote / number, and bold, strike
    /// and code marks. A lone `*` or `_` is left alone -- it may be part of a
    /// word.
    static func stripMarkdown(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespaces)

        var stripped = false
        for marker in ["- [ ] ", "- [x] ", "- [X] ", "> ", "- ", "* ", "+ "] where t.hasPrefix(marker) {
            t.removeFirst(marker.count)
            stripped = true
            break
        }
        if !stripped {
            if let heading = t.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                t.removeSubrange(heading)
            } else if let ordered = t.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                t.removeSubrange(ordered)
            }
        }
        for mark in ["**", "__", "~~", "`"] {
            t = t.replacingOccurrences(of: mark, with: "")
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// The earliest place in `text` where a word starts with a query word.
    /// Falls back to an empty range at the start, which highlights nothing.
    private static func matchRange(of queryTokens: [String], in text: String) -> Range<String.Index> {
        var best: Range<String.Index>?
        for token in queryTokens {
            var from = text.startIndex
            while from < text.endIndex,
                  let r = text.range(of: token,
                                     options: [.caseInsensitive, .diacriticInsensitive],
                                     range: from..<text.endIndex) {
                let atWordStart = r.lowerBound == text.startIndex
                    || !(text[text.index(before: r.lowerBound)].isLetter
                         || text[text.index(before: r.lowerBound)].isNumber)
                if atWordStart {
                    if best == nil || r.lowerBound < best!.lowerBound { best = r }
                    break
                }
                from = r.upperBound
            }
        }
        return best ?? text.startIndex..<text.startIndex
    }
}

struct SearchSnippet: Equatable {
    /// The matching line, without Markdown syntax.
    let text: String
    /// Where the matched word is in `text`, for highlighting. Empty when it
    /// could not be located.
    let matchRange: Range<String.Index>
}

// MARK: - Scope

enum SearchScope: Equatable {
    case all
    /// A folder and everything below it. Compared by whole path components, so
    /// "/root/Travel" does not take in "/root/Travelogue".
    case folder(String)

    func contains(path: String) -> Bool {
        switch self {
        case .all:
            return true
        case .folder(let folder):
            var f = folder
            while f.count > 1 && f.hasSuffix("/") { f.removeLast() }
            return path.hasPrefix(f == "/" ? "/" : f + "/")
        }
    }
}

// MARK: - Ranking

/// Best first. A title that starts with what was typed beats any other title
/// match, which beats a match only in the body.
enum SearchTier: Int, Comparable {
    case body = 0, title = 1, titlePrefix = 2
    static func < (a: SearchTier, b: SearchTier) -> Bool { a.rawValue < b.rawValue }
}

struct SearchHit: Equatable {
    let path: String
    let tier: SearchTier
    let date: Date
}

// MARK: - Data

/// What the index knows about one note: its words (so an update can take the
/// old ones out), its tags, the words of its title (for ranking) and its date.
struct SearchEntry: Equatable {
    var titleTokens: [String]
    var date: Date
    var terms: Set<String>
    var tags: Set<String>
}

/// The whole index as a value. Mutating it is cheap per note; copying it is
/// cheap too (copy-on-write), which is what lets views read an immutable copy
/// while the index keeps changing.
struct SearchData: Equatable {
    /// Folded word -> the paths of every note that has it.
    private(set) var terms: [String: Set<String>] = [:]
    /// Lowercased tag -> the paths of every note that has it.
    private(set) var tags: [String: Set<String>] = [:]
    /// Path -> that note's entry. This is the path-to-terms map.
    private(set) var entries: [String: SearchEntry] = [:]

    // MARK: change

    /// Adds a note, or replaces everything the index knew about it.
    mutating func upsert(path: String, content: String, date: Date) {
        detach(path)
        let entry = SearchEntry(
            titleTokens: SearchText.tokens(NoteRowText.title(of: content)),
            date: date,
            terms: Set(SearchText.tokens(content)),
            tags: Set(TagScanner.tags(in: content).map { $0.lowercased() }))
        attach(path, entry)
    }

    mutating func remove(path: String) {
        detach(path)
    }

    /// Moves a note, or a folder with every note under it, to a new path
    /// without reading anything.
    mutating func rename(from old: String, to new: String) {
        guard old != new else { return }
        let moving = entries.keys.filter { $0 == old || $0.hasPrefix(old + "/") }
        var moved: [(String, SearchEntry)] = []
        for path in moving {
            let entry = entries[path]!
            detach(path)
            moved.append((new + path.dropFirst(old.count), entry))
        }
        for (path, entry) in moved {
            detach(path) // a note already at the destination is replaced
            attach(path, entry)
        }
    }

    /// Adds one word to a note. For tests and hand-built indexes.
    mutating func addTerm(_ term: String, path: String) {
        var entry = entries[path] ?? SearchEntry(titleTokens: [], date: .distantPast, terms: [], tags: [])
        let folded = SearchText.fold(term)
        entry.terms.insert(folded)
        terms[folded, default: []].insert(path)
        entries[path] = entry
    }

    private mutating func attach(_ path: String, _ entry: SearchEntry) {
        for term in entry.terms { terms[term, default: []].insert(path) }
        for tag in entry.tags { tags[tag, default: []].insert(path) }
        entries[path] = entry
    }

    private mutating func detach(_ path: String) {
        guard let entry = entries.removeValue(forKey: path) else { return }
        for term in entry.terms {
            terms[term]?.remove(path)
            if terms[term]?.isEmpty == true { terms[term] = nil }
        }
        for tag in entry.tags {
            tags[tag]?.remove(path)
            if tags[tag]?.isEmpty == true { tags[tag] = nil }
        }
    }

    // MARK: search

    /// Notes in which every query word starts some word, best first: tier,
    /// then newest, then path (so equal dates have a fixed order).
    func search(query: String, scope: SearchScope = .all) -> [SearchHit] {
        let queryTokens = SearchText.tokens(query)
        guard !queryTokens.isEmpty else { return [] }

        var candidates: Set<String>?
        for token in queryTokens {
            var matching: Set<String> = []
            for (term, paths) in terms where term.hasPrefix(token) { matching.formUnion(paths) }
            candidates = candidates.map { $0.intersection(matching) } ?? matching
            if candidates!.isEmpty { return [] }
        }

        let wholeQuery = queryTokens.joined(separator: " ")
        var hits: [SearchHit] = []
        for path in candidates ?? [] where scope.contains(path: path) {
            guard let entry = entries[path] else { continue }
            let tier: SearchTier
            if entry.titleTokens.joined(separator: " ").hasPrefix(wholeQuery) {
                tier = .titlePrefix
            } else if queryTokens.allSatisfy({ q in entry.titleTokens.contains { $0.hasPrefix(q) } }) {
                tier = .title
            } else {
                tier = .body
            }
            hits.append(SearchHit(path: path, tier: tier, date: entry.date))
        }
        hits.sort {
            if $0.tier != $1.tier { return $0.tier > $1.tier }
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.path < $1.path
        }
        return hits
    }

    /// The notes that carry every one of the tags.
    func paths(taggedWithAll wanted: [String]) -> Set<String> {
        let lowered = wanted.map { $0.lowercased() }
        guard !lowered.isEmpty else { return [] }
        var result: Set<String>?
        for tag in lowered {
            let hits = tags[tag] ?? []
            result = result.map { $0.intersection(hits) } ?? hits
        }
        return result ?? []
    }
}

// MARK: - What gets indexed

enum SearchIndexer {

    /// Hidden folders (`.Trash`, `.purnote`, ...) and a note's `<note>.assets`
    /// folder hold nothing a person wrote as a note.
    static func shouldDescend(intoDirectoryNamed name: String) -> Bool {
        !name.hasPrefix(".") && !name.hasSuffix(".assets")
    }

    /// A visible `.md` file. iCloud placeholders (`.Note.md.icloud`) are
    /// hidden and end in `.icloud`, so they are out too.
    static func isIndexableFile(named name: String) -> Bool {
        !name.hasPrefix(".") && name.lowercased().hasSuffix(".md")
    }

    /// Whether a note at `path` is one the index should hold: under the
    /// library root, with no hidden or `.assets` folder between the two.
    static func isIndexable(path: String, root: String) -> Bool {
        guard path.hasPrefix(root + "/") else { return false }
        let parts = path.dropFirst(root.count + 1).split(separator: "/").map(String.init)
        guard let file = parts.last else { return false }
        return parts.dropLast().allSatisfy { shouldDescend(intoDirectoryNamed: $0) }
            && isIndexableFile(named: file)
    }
}

enum SearchIndexPath {
    /// One spelling per file, so an update finds the entry it replaces.
    static func normalise(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
