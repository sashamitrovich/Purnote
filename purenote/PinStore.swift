//
//  PinStore.swift
//  purenote
//

import Foundation

/// Loads and saves the pin list: one small readable JSON file,
/// `.purnote/pins.json` in the library root beside `smartfolders.json`:
///
///     { "pins": ["Folder/Note.md", "Other.md"], "version": 1 }
///
/// Unlike the smart-folder file this one is read and written through
/// NSFileCoordinator, because in iCloud it is shared with the other devices
/// and the sync daemon replaces it as it arrives.
///
/// Conflict policy, version 1: the last writer wins, and a pin whose note no
/// longer exists is dropped when the list is loaded for display. (Two devices
/// pinning at the same moment can lose one pin. Pins are cheap to redo; a
/// merge of every device's edits is not worth the machinery yet.)
enum PinStore {

    static let fileName = "pins.json"
    static let currentVersion = 1

    static func fileURL(in root: URL) -> URL {
        root.appendingPathComponent(SmartFolderStore.directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private struct FileShape: Codable {
        var version: Int
        var pins: [String]
    }

    // MARK: - encoding

    static func encode(_ list: PinList) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(FileShape(version: currentVersion, pins: list.paths))
    }

    /// nil when the data is not a pin file this version understands. A newer
    /// version counts as not understood: its shape may have changed, and
    /// reading it as version 1 would then overwrite it with less.
    static func decode(_ data: Data) -> PinList? {
        guard let shape = try? JSONDecoder().decode(FileShape.self, from: data),
              shape.version == currentVersion else { return nil }
        return PinList(shape.pins)
    }

    // MARK: - load / save

    /// The saved list. A missing, unreadable or corrupt file is an empty list,
    /// never an error. Loading never writes. `droppingMissing` also drops pins
    /// whose note is not in the library any more (an iCloud placeholder counts
    /// as present).
    static func load(from root: URL, droppingMissing: Bool = false) -> PinList {
        guard let data = readData(fileURL(in: root)), let list = decode(data) else { return PinList() }
        guard droppingMissing else { return list }

        return list.pruned { path in
            let url = root.appendingPathComponent(path)
            let placeholder = url.deletingLastPathComponent()
                .appendingPathComponent(PinPath.placeholderName(for: url.lastPathComponent))
            let fm = FileManager.default
            return fm.fileExists(atPath: url.path) || fm.fileExists(atPath: placeholder.path)
        }
    }

    /// Writes the list. A file already there that cannot be read is moved to
    /// `pins.json.corrupt` (or `.corrupt 2`, ...) first rather than written
    /// over, so whatever was in it can still be looked at.
    static func save(_ list: PinList, to root: URL) throws {
        let file = fileURL(in: root)
        try CoordinatedFile.createDirectory(at: file.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)

        if let existing = readData(file), decode(existing) == nil {
            try CoordinatedFile.move(from: file, to: freeCorruptName(for: file))
        }
        try CoordinatedFile.write(try encode(list), to: file)
    }

    private static func freeCorruptName(for file: URL) -> URL {
        let fm = FileManager.default
        let first = file.appendingPathExtension("corrupt")
        guard fm.fileExists(atPath: first.path) else { return first }
        for n in 2...500 {
            let candidate = file.deletingLastPathComponent()
                .appendingPathComponent("\(file.lastPathComponent).corrupt \(n)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return file.appendingPathExtension("corrupt \(UUID().uuidString)")
    }

    private static func readData(_ url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path),
              let text = try? CoordinatedFile.read(url) else { return nil }
        return Data(text.utf8)
    }

    // MARK: - merging two libraries

    /// The union of two pin files, `existing` first. nil if either side is not
    /// a readable pin file, so the caller can keep both rather than guess.
    static func mergedData(existing: Data, incoming: Data) -> Data? {
        guard let a = decode(existing), let b = decode(incoming) else { return nil }
        return try? encode(a.merged(with: b))
    }

    /// Used when the library moves from this iPhone into iCloud (see
    /// Storage.move). If `source` is a pin file and the destination already has
    /// one, folds the source into the destination and removes the source, and
    /// returns true. Otherwise leaves everything alone and returns false, and
    /// the caller moves the file the usual way.
    static func mergeIncoming(_ source: URL, into destination: URL) -> Bool {
        guard source.lastPathComponent == fileName,
              source.deletingLastPathComponent().lastPathComponent == SmartFolderStore.directoryName,
              let incoming = readData(source),
              let existing = readData(destination),
              let merged = mergedData(existing: existing, incoming: incoming) else { return false }

        do {
            try CoordinatedFile.write(merged, to: destination)
        } catch {
            print("Could not merge pins into iCloud: \(error).")
            return false
        }
        try? FileManager.default.removeItem(at: source)
        return true
    }
}

/// The operations the app performs on the pin list of one library, each a
/// read-modify-write of the file so that several DataManagers (one per open
/// folder) never overwrite each other with a stale copy.
struct PinService {

    let root: URL

    /// A hook after a rename or move: rewrites pins, and writes only when
    /// something changed, so a library that never pins never gets the file.
    func moved(from old: URL, to new: URL) {
        guard let oldPath = PinPath.relative(of: old, in: root) else { return }
        if let newPath = PinPath.relative(of: new, in: root) {
            update { $0.renamed(from: oldPath, to: newPath) }
        } else {
            // moved out of the library: the pin has nothing to point at
            update { $0.removing(prefix: oldPath) }
        }
    }

    /// A hook after a delete (a note or a whole folder).
    func removed(at url: URL) {
        guard let path = PinPath.relative(of: url, in: root) else { return }
        update { $0.removing(prefix: path) }
    }

    /// Toggles the pin on a note; returns whether it is pinned afterwards, or
    /// nil if the note is outside the library or the file could not be written.
    @discardableResult
    func toggle(_ url: URL) -> Bool? {
        guard let path = PinPath.relative(of: url, in: root) else { return nil }
        var list = PinStore.load(from: root)
        let pinned = list.toggle(path)
        do {
            try PinStore.save(list, to: root)
            return pinned
        } catch {
            print("Could not save pins: \(error).")
            return nil
        }
    }

    private func update(_ change: (PinList) -> PinList) {
        let before = PinStore.load(from: root)
        let after = change(before)
        guard after != before else { return }
        do { try PinStore.save(after, to: root) }
        catch { print("Could not save pins: \(error).") }
    }
}
