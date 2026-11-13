//
//  PinList.swift
//  purenote
//

import Foundation

/// The pinned notes, as an ordered list of paths relative to the library root
/// ("Folder/Note.md"). A pure value: no file access, so every rule about how a
/// pin follows a rename, move or delete is tested without a disk.
///
/// A pin names a path, not a file identity, so the app has to rewrite it when
/// it renames or moves a note itself (`renamed(from:to:)`) and drop it when it
/// deletes one (`removing(prefix:)`). A change made outside the app (on the
/// Mac) is caught later, when `pruned` drops what no longer exists.
struct PinList: Equatable {

    private(set) var paths: [String]

    /// Duplicates and unusable paths are dropped; the first of a duplicate wins.
    init(_ paths: [String] = []) {
        self.paths = PinList.cleaned(paths)
    }

    var isEmpty: Bool { paths.isEmpty }
    var count: Int { paths.count }

    func contains(_ path: String) -> Bool {
        paths.contains(path)
    }

    // MARK: - editing

    /// Pins go to the end, so the list stays in the order they were pinned.
    mutating func add(_ path: String) {
        guard PinList.isUsable(path), !paths.contains(path) else { return }
        paths.append(path)
    }

    mutating func remove(_ path: String) {
        paths.removeAll { $0 == path }
    }

    /// Pins the path if it is not pinned, unpins it if it is. Returns whether
    /// it is pinned afterwards.
    @discardableResult
    mutating func toggle(_ path: String) -> Bool {
        if contains(path) {
            remove(path)
            return false
        }
        add(path)
        return contains(path)
    }

    // MARK: - following changes

    /// A note renamed or moved (`old` is its path), or a folder renamed or
    /// moved (`old` is the folder path, and every pin under it follows).
    /// Matches whole path components only: renaming "Notes" leaves "Notes 2"
    /// alone. Position in the list is kept. If the new path is already pinned
    /// the two collapse into one.
    func renamed(from old: String, to new: String) -> PinList {
        let old = PinList.trimmed(old), new = PinList.trimmed(new)
        guard !old.isEmpty, !new.isEmpty else { return self }

        let rewritten = paths.map { path -> String in
            if path == old { return new }
            if path.hasPrefix(old + "/") { return new + path.dropFirst(old.count) }
            return path
        }
        return PinList(rewritten)
    }

    /// A note deleted (`prefix` is its path) or a folder deleted (everything
    /// under it goes). Whole components only.
    func removing(prefix: String) -> PinList {
        let prefix = PinList.trimmed(prefix)
        guard !prefix.isEmpty else { return self }
        return PinList(paths.filter { $0 != prefix && !$0.hasPrefix(prefix + "/") })
    }

    // MARK: - pruning and merging

    /// Drops pins whose file is gone.
    func pruned(existingPaths: Set<String>) -> PinList {
        pruned(where: { existingPaths.contains($0) })
    }

    func pruned(where exists: (String) -> Bool) -> PinList {
        PinList(paths.filter(exists))
    }

    /// The union of two lists: this list's order first, then whatever the other
    /// one has that this one lacks. Used when two libraries become one.
    func merged(with other: PinList) -> PinList {
        PinList(paths + other.paths)
    }

    // MARK: - paths

    /// A path that stays inside the library: relative, no empty or ".."
    /// components.
    static func isUsable(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/") else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return !parts.contains { $0.isEmpty || $0 == ".." }
    }

    private static func cleaned(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { isUsable($0) && seen.insert($0).inserted }
    }

    private static func trimmed(_ path: String) -> String {
        var path = path
        while path.hasSuffix("/") { path.removeLast() }
        return path
    }
}

/// Turning a file URL into the library-relative path a pin stores.
enum PinPath {

    /// "Folder/Note.md" for a note inside `root`, nil for anything outside it
    /// (or the root itself). Works on a URL whose file is already gone, which
    /// is the case in the hooks that run after a move.
    ///
    /// An iCloud placeholder (".Note.md.icloud") maps to the real note name, so
    /// a pin taken while a note is still downloading stays right once it has.
    static func relative(of url: URL, in root: URL) -> String? {
        let rootPath = normalized(root)
        let path = normalized(url)
        guard path.hasPrefix(rootPath + "/") else { return nil }

        var parts = path.dropFirst(rootPath.count + 1).split(separator: "/").map(String.init)
        guard let last = parts.last else { return nil }
        parts[parts.count - 1] = realName(ofPlaceholder: last)
        return parts.joined(separator: "/")
    }

    /// ".Note.md.icloud" -> "Note.md"; any other name unchanged.
    static func realName(ofPlaceholder name: String) -> String {
        guard name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > ".icloud".count + 1 else { return name }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    /// The placeholder name iCloud uses for a note that is not downloaded.
    static func placeholderName(for name: String) -> String { ".\(name).icloud" }

    /// Standardized, without a trailing slash, and without the "/private"
    /// prefix the simulator and temp directories sometimes carry, so the same
    /// folder always compares equal to itself.
    private static func normalized(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        if path.hasPrefix("/private/") { path.removeFirst("/private".count) }
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}
