//
//  Index.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import Foundation

/// One search hit, ready to show: the note, and the line that matched.
struct SearchResult: Identifiable {
    let note: Note
    /// The first body line with a match, markers stripped; nil when only the
    /// title matched.
    let snippet: SearchSnippet?
    /// Notes in different folders can share a file name, so the path is the id.
    var id: String { note.url.path }
}

/// The library's search index.
///
/// All changes go through one serial queue, off the main thread: reading a
/// file and re-indexing it never blocks typing. Views never touch that working
/// copy. They read `snapshot`, an immutable `SearchData` value that the queue
/// swaps in under a lock after each batch of changes, and `objectWillChange`
/// is sent on the main thread afterwards so views re-read it.
///
/// Saving one note is `update(path:)`: one file read, and only that note's
/// entries change. `rebuild()` (also `indexall()`) rescans the whole library,
/// for launch and refresh, and is queued rather than run on the caller.
class SearchIndex : ObservableObject {
    var rootUrl: URL

    private let queue = DispatchQueue(label: "purnote.search-index", qos: .utility)
    /// Only touched on `queue`.
    private var working = SearchData()

    /// Guards everything below.
    private let lock = NSLock()
    private var published = SearchData()
    /// Operations queued or running. The snapshot is published when it hits
    /// zero, so a burst of saves costs one copy, not one per save.
    private var pending = 0
    private var rebuildQueued = false
    private var notifyQueued = false

    init(rootUrl: URL) {
        self.rootUrl = rootUrl
        rebuild()
    }

    // MARK: Reading

    /// An immutable copy of the index as of the last published change. Safe to
    /// read from a view body or any thread.
    public var snapshot: SearchData {
        lock.lock(); defer { lock.unlock() }
        return published
    }

    /// Term -> the paths of every note that contains it (folded: lowercase,
    /// no accents). Prefix-matched by search.
    public var dict: [String: Set<String>] { snapshot.terms }

    /// Tag (lowercased) -> the paths of every note that contains it.
    public var tagDict: [String: Set<String>] { snapshot.tags }

    /// Blocks until every change queued so far has been applied and
    /// published. For tests and shutdown, not for the main thread of the app.
    public func waitUntilIdle() {
        queue.sync {}
    }

    // MARK: Changing

    /// Re-reads one note and replaces what the index holds for it. A path that
    /// is gone is removed; one that is not an indexable note is ignored.
    public func update(path: String) {
        guard !path.isEmpty else { return }   // "" would normalise to the working directory
        let root = SearchIndexPath.normalise(rootUrl.path)
        let path = SearchIndexPath.normalise(path)
        enqueue { data in
            guard SearchIndexer.isIndexable(path: path, root: root) else {
                data.remove(path: path)
                return
            }
            let url = URL(fileURLWithPath: path)
            do {
                let content = try CoordinatedFile.read(url)
                data.upsert(path: path, content: content, date: NoteDates.modified(of: url))
            } catch {
                // a file that is there but cannot be read right now (iCloud
                // busy) keeps what the index already knows; one that is gone goes
                if !FileManager.default.fileExists(atPath: path) { data.remove(path: path) }
            }
        }
    }

    public func remove(path: String) {
        guard !path.isEmpty else { return }
        let path = SearchIndexPath.normalise(path)
        enqueue { $0.remove(path: path) }
    }

    /// A note, or a folder with its notes, was moved on disk. Nothing is re-read.
    public func rename(from old: String, to new: String) {
        guard !old.isEmpty, !new.isEmpty else { return }
        let old = SearchIndexPath.normalise(old)
        let new = SearchIndexPath.normalise(new)
        enqueue { $0.rename(from: old, to: new) }
    }

    /// Rescans the whole library. Asking again while a rescan is still waiting
    /// to start is a no-op: that rescan will see the newer files anyway.
    public func rebuild() {
        let root = SearchIndexPath.normalise(rootUrl.path)
        lock.lock()
        if rebuildQueued { lock.unlock(); return }
        rebuildQueued = true
        pending += 1
        lock.unlock()

        queue.async { [self] in
            lock.lock(); rebuildQueued = false; lock.unlock()
            var fresh = SearchData()
            Self.scan(folder: URL(fileURLWithPath: root), root: root, into: &fresh)
            working = fresh
            finishOperation()
        }
    }

    /// Kept for the call sites that refresh after something changed on disk.
    public func indexall() {
        rebuild()
    }

    /// Adds one word to a note. For tests.
    func addTerm(term: String, path: String) {
        enqueue { $0.addTerm(term, path: path) }
        waitUntilIdle()
    }

    private func enqueue(_ change: @escaping (inout SearchData) -> Void) {
        lock.lock(); pending += 1; lock.unlock()
        queue.async { [self] in
            change(&working)
            finishOperation()
        }
    }

    /// On `queue`, after a change: publish when nothing else is waiting.
    private func finishOperation() {
        lock.lock()
        pending -= 1
        let idle = pending == 0
        if idle { published = working }
        let notify = idle && !notifyQueued
        if notify { notifyQueued = true }
        lock.unlock()

        if notify {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.lock.lock(); self.notifyQueued = false; self.lock.unlock()
                self.objectWillChange.send()
            }
        }
    }

    private static func scan(folder: URL, root: String, into data: inout SearchData) {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey])
        } catch {
            print("Error getting directory content while indexing: \(error).")
            return
        }

        for url in urls {
            let name = url.lastPathComponent
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if isDirectory {
                if SearchIndexer.shouldDescend(intoDirectoryNamed: name) {
                    scan(folder: url, root: root, into: &data)
                }
            } else if SearchIndexer.isIndexableFile(named: name) {
                do {
                    let content = try CoordinatedFile.read(url)
                    data.upsert(path: SearchIndexPath.normalise(url.path), content: content,
                                date: NoteDates.modified(of: url))
                } catch {
                    print("Failed to get file content while indexing: \(error).")
                }
            }
        }
    }

    // MARK: Searching

    public func searchPhrase(phrase: String) -> Set<String> {
        Set(snapshot.search(query: phrase).map(\.path))
    }

    public func getSearchResultsAsUrls(phrase: String) -> [URL] {
        if phrase == "" { return [] }
        return snapshot.search(query: phrase).map { URL(fileURLWithPath: $0.path) }
    }

    /// Every note that has a word *beginning with* `word`.
    public func searchWord(word: String) -> Set<String> {
        searchPhrase(phrase: word)
    }

    /// The notes matching every word of `phrase`, best first, each with the
    /// line that matched. Reads only the matching files.
    public func search(phrase: String, scope: SearchScope) -> [SearchResult] {
        var results: [SearchResult] = []
        for hit in snapshot.search(query: phrase, scope: scope) {
            let url = URL(fileURLWithPath: hit.path)
            do {
                let content = try CoordinatedFile.read(url)
                let note = Note(content: content, date: hit.date, path: url.lastPathComponent,
                                isLocal: true, url: url, type: .Note)
                results.append(SearchResult(note: note, snippet: SearchText.snippet(in: content, query: phrase)))
            } catch {
                print("Unexpected error adding note to search results: \(error).")
            }
        }
        return results
    }

    public func search(phrase: String) -> [Note] {
        search(phrase: phrase, scope: .all).map(\.note)
    }

    /// Every tag present across the library, sorted.
    public func allTags() -> [String] {
        snapshot.tags.keys.sorted()
    }

    /// The notes containing every one of the given tags, newest first.
    public func searchByTags(_ tags: [String]) -> [Note] {
        let snap = snapshot
        var notes: [Note] = []
        for path in snap.paths(taggedWithAll: tags) {
            let url = URL(fileURLWithPath: path)
            do {
                try notes.append(Note(content: CoordinatedFile.read(url),
                                      date: snap.entries[path]?.date ?? NoteDates.modified(of: url),
                                      path: url.lastPathComponent, isLocal: true, url: url, type: .Note))
            }
            catch {
                print("Unexpected error adding note to tag results: \(error).")
            }
        }
        notes.sort { $0.date > $1.date }
        return notes
    }
}
