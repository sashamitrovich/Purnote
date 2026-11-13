//
//  TrashModels.swift
//  purenote
//
//  The pure part of the library's own trash: what is recorded about a deleted
//  item, which recorded paths are believed, how an item folder is named, and
//  how a free name is chosen on restore. No file access here -- TrashStore does
//  that -- so every rule can be tested without a disk.
//

import Foundation

enum TrashKind: String, Codable {
    case note
    case folder
}

/// Where an item is in its sync life. An item whose parts are still arriving
/// from iCloud is listed but cannot be restored yet.
enum TrashSyncState: Equatable {
    case ready
    case downloading
}

/// One deleted note (with its attachments folder) or one deleted folder.
struct TrashedItem: Identifiable, Equatable {
    /// The item folder's name under `.purnote/trash/`: `<yyyyMMddHHmmss>-<uuid>`.
    let id: String
    var kind: TrashKind
    /// Where it was, relative to the library root ("Folder/Note.md"). When
    /// `originKnown` is false this is only the item's own name and a restore
    /// goes to the library root.
    var originalPath: String
    /// False when `origin.json` was missing, unreadable or not believed.
    var originKnown: Bool
    var deletedAt: Date
    /// The name the payload has inside the item folder. Empty while the item
    /// is still downloading and nothing says what it is called.
    var payloadName: String
    /// The attachments folder moved with a note, if there was one.
    var assetsName: String?
    var state: TrashSyncState

    var isRestorable: Bool { state == .ready }

    /// The name to show: the file or folder name, never an iCloud stub name.
    var displayName: String {
        originalPath.split(separator: "/").last.map(String.init) ?? payloadName
    }

    /// The folder it was in, relative to the library root; "" for the root.
    var originalFolder: String {
        let parts = originalPath.split(separator: "/").map(String.init)
        return parts.dropLast().joined(separator: "/")
    }
}

/// `origin.json`, the small readable record kept in each item folder.
struct TrashOrigin: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var path: String
    var kind: TrashKind
    /// ISO 8601, to the second.
    var deletedAt: String
    var payloadName: String
    var assetsName: String?

    init(path: String, kind: TrashKind, deletedAt: Date, payloadName: String, assetsName: String?) {
        self.version = Self.currentVersion
        self.path = path
        self.kind = kind
        self.deletedAt = TrashNaming.isoString(deletedAt)
        self.payloadName = payloadName
        self.assetsName = assetsName
    }

    var deletedDate: Date? { TrashNaming.isoDate(deletedAt) }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// nil when the data is not an origin file this version understands. A
    /// newer version counts as not understood.
    static func decode(_ data: Data) -> TrashOrigin? {
        guard let origin = try? JSONDecoder().decode(TrashOrigin.self, from: data),
              origin.version == currentVersion else { return nil }
        return origin
    }
}

enum TrashError: Error {
    /// The thing to delete is not there.
    case sourceMissing(URL)
    /// Only the iCloud placeholder is on this device; there is no file to move.
    case stillInICloud(URL)
    /// Not inside the library, or the library root itself.
    case outsideLibrary(URL)
    /// Inside a hidden folder (`.purnote`, `.Trash`) or itself hidden.
    case hiddenItem(URL)
    /// The DataManager is not backed by a library.
    case noLibrary
    /// An item id that is not a plain folder name inside the trash.
    case invalidItem(String)
    /// The item folder or its payload is gone (restored or deleted elsewhere).
    case itemGone(String)
    case stillDownloading(String)
    /// The note moved into the trash but its attachments did not, and the note
    /// could not be moved back either. The item stays listed and restorable.
    case rollbackFailed(item: TrashedItem, underlying: Error)
    /// A restore that moved something and could not undo it. `restored` is
    /// where a part that did move now sits (nil if nothing that moved is left in the library).
    case partialRestore(restored: URL?, underlying: Error)
}

extension TrashError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sourceMissing(let url): return "\(url.lastPathComponent) is not there any more."
        case .stillInICloud(let url): return "\(PinPath.realName(ofPlaceholder: url.lastPathComponent)) has not been downloaded from iCloud yet."
        case .outsideLibrary(let url): return "\(url.lastPathComponent) is not inside your notes."
        case .hiddenItem(let url): return "\(url.lastPathComponent) is not a note or a folder of notes."
        case .noLibrary: return "There are no notes to delete from here."
        case .invalidItem: return "That is not an item in Recently Deleted."
        case .itemGone: return "That item is no longer in Recently Deleted."
        case .stillDownloading: return "That item is still downloading from iCloud."
        case .rollbackFailed(_, let error): return "The note was moved to Recently Deleted but its pictures could not be: \(error.localizedDescription)"
        case .partialRestore(_, let error): return "The restore stopped half way: \(error.localizedDescription)"
        }
    }
}

struct TrashFailure {
    /// The url that could not be trashed, or for a delete-forever the item folder.
    let url: URL
    let error: Error
}

/// The result of trashing several things at once: what moved, and what did not.
struct TrashBatch {
    var items: [TrashedItem] = []
    var failures: [TrashFailure] = []
}

// MARK: - Paths

enum TrashPath {

    /// The components of a relative path that may be believed: not empty, not
    /// absolute, no `.`/`..`/empty component, nothing hidden (so nothing can
    /// point into `.purnote`), no NUL. nil otherwise.
    static func components(ofRelativePath path: String) -> [String]? {
        guard !path.isEmpty, !path.hasPrefix("/") else { return nil }
        let parts = path.components(separatedBy: "/")
        return parts.allSatisfy(isSafeName) ? parts : nil
    }

    /// One file or folder name that may be believed. A leading dot is refused:
    /// it is how `.`, `..`, `.purnote` and every hidden name are caught at once.
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty
            && !name.hasPrefix(".")
            && !name.contains("/")
            && !name.contains("\u{0}")
    }

    /// "Folder/Note.md" for something strictly inside `root`, else nil.
    static func relativePath(of url: URL, in root: URL) -> String? {
        let rootPath = normalized(root)
        let path = normalized(url)
        let prefix = rootPath == "/" ? "/" : rootPath + "/"
        guard path.hasPrefix(prefix), path.count > prefix.count else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    /// The url a recorded relative path leads to, only if it passes
    /// `components(ofRelativePath:)` and resolves inside `root`.
    static func resolve(_ path: String, in root: URL) -> URL? {
        guard let parts = components(ofRelativePath: path) else { return nil }
        let url = parts.reduce(root) { $0.appendingPathComponent($1) }
        return relativePath(of: url, in: root) == nil ? nil : url
    }

    /// Standardized, without a trailing slash, and without the "/private"
    /// prefix the simulator and temp directories sometimes carry.
    static func normalized(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        if path.hasPrefix("/private/") { path.removeFirst("/private".count) }
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }
}

// MARK: - Naming

enum TrashNaming {

    private static func idFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMddHHmmss"
        return f
    }

    /// `yyyyMMddHHmmss-<uuid>`, in UTC, so folders sort by date and the date
    /// survives a missing origin.json.
    static func makeID(now: Date, uuid: UUID = UUID()) -> String {
        idFormatter().string(from: now) + "-" + uuid.uuidString
    }

    /// The date an item folder's name starts with; nil for any other name.
    static func date(fromID id: String) -> Date? {
        let chars = Array(id)
        guard chars.count > 15, chars[14] == "-",
              chars[0..<14].allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return idFormatter().date(from: String(chars[0..<14]))
    }

    /// An item folder name that stays inside the trash folder.
    static func isSafeID(_ id: String) -> Bool {
        TrashPath.isSafeName(id)
    }

    static func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    static func isoDate(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }

    /// One spelling per name, so "trip.md" and "Trip.md" compare equal, and so
    /// do a composed and a decomposed "\u{00E9}".
    static func fold(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: nil)
    }

    /// The first of `stem`, "stem 2", "stem 3", ... for which none of
    /// `names(candidate)` is in `taken` (a set of folded names).
    static func freeStem(_ stem: String, taken: Set<String>, names: (String) -> [String]) -> String {
        func isFree(_ candidate: String) -> Bool {
            names(candidate).allSatisfy { !taken.contains(fold($0)) }
        }
        if isFree(stem) { return stem }
        for n in 2...500 {
            let candidate = "\(stem) \(n)"
            if isFree(candidate) { return candidate }
        }
        return "\(stem) \(UUID().uuidString)"
    }

    /// Rewrites the attachment references of a note from one assets folder name
    /// to another. Only a reference is touched -- the name right after `(`,
    /// `<`, `"`, `'` or `./` and followed by `/` -- never the same words in
    /// ordinary text or inside a longer folder name. The percent-encoded
    /// spelling ("Trip%20Photos.assets/") is handled too.
    static func rewriteAssetReferences(in content: String, from old: String, to new: String) -> String {
        guard old != new, !old.isEmpty else { return content }
        var result = rewrite(content, old: old, new: new)
        let oldEncoded = old.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? old
        let newEncoded = new.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? new
        if oldEncoded != old { result = rewrite(result, old: oldEncoded, new: newEncoded) }
        return result
    }

    private static func rewrite(_ text: String, old: String, new: String) -> String {
        let needle = old + "/"
        guard text.contains(needle) else { return text }
        let openers: Set<Character> = ["(", "<", "\"", "'"]

        func startsAReference(_ head: Substring) -> Bool {
            if let last = head.last, openers.contains(last) { return true }
            if head.hasSuffix("./") {
                let before = head.dropLast(2)
                return before.last.map { openers.contains($0) } ?? false
            }
            return false
        }

        var result = ""
        var from = text.startIndex
        while let hit = text.range(of: needle, range: from..<text.endIndex) {
            if startsAReference(text[..<hit.lowerBound]) {
                result += text[from..<hit.lowerBound] + new + "/"
            } else {
                result += text[from..<hit.upperBound]
            }
            from = hit.upperBound
        }
        result += text[from...]
        return result
    }
}
