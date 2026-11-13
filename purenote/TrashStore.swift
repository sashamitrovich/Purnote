//
//  TrashStore.swift
//  purenote
//
//  The library's own trash, instead of the system Trash.
//
//  Why not the system Trash: `FileManager.trashItem` throws on the iOS
//  simulator (there is no Trash on its volume), throws away where the item went
//  so an Undo cannot find it again, and nothing is known about where an iCloud
//  container's files end up on a device. A folder of our own works the same in
//  the simulator and on a device, makes Undo and Restore exact, and syncs like
//  any other hidden file.
//
//  Layout: every deleted thing gets an item folder of its own,
//
//      .purnote/trash/<yyyyMMddHHmmss>-<uuid>/
//          origin.json        written FIRST, see TrashOrigin
//          <payload>          the note file or the folder, under its own name
//          <note>.assets/     a note's attachments, moved with it
//
//  One folder per item means there is no shared index file for two devices to
//  fight over, and a missing or corrupt origin.json costs the original place
//  but never the content: the item is still listed and restores to the root.
//
//  The rules that keep a user's notes safe here:
//   - Every filesystem change goes through CoordinatedFile.
//   - Nothing is ever overwritten. A restore picks a name that is free (for the
//     note AND its attachments folder, ignoring case) and never replaces.
//   - An item folder is never removed recursively. After a restore, rollback or
//     failed delete, origin.json is deleted and the folder is removed only if
//     that left it empty (rmdir); anything else stays, and stays listed.
//   - Listing reads and deletes nothing and never waits on a download.
//

import Foundation

enum TrashStore {

    /// How a file is moved. The app's own CoordinatedFile.move; tests pass one
    /// that fails on chosen moves.
    typealias Mover = (_ from: URL, _ to: URL) throws -> Void

    /// How a note's rewritten text is saved. Tests pass one that fails.
    typealias Writer = (_ text: String, _ to: URL) throws -> Void

    static let directoryName = "trash"
    static let originFileName = "origin.json"

    /// The default mover.
    static let coordinatedMove: Mover = { try CoordinatedFile.move(from: $0, to: $1) }
    static let coordinatedWrite: Writer = { try CoordinatedFile.write($0, to: $1) }

    static func trashDirectory(in root: URL) -> URL {
        root.appendingPathComponent(SmartFolderStore.directoryName, isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static func itemFolder(id: String, in root: URL) -> URL {
        trashDirectory(in: root).appendingPathComponent(id, isDirectory: true)
    }

    // MARK: - Move to trash

    /// Moves a note (with its `.assets` folder) or a folder into the trash.
    ///
    /// Throws, and on a throw leaves things as they were: the source is still
    /// where it was and no item folder is left behind. The one exception is
    /// `TrashError.rollbackFailed`, where the note moved, its attachments did
    /// not, and the note could not be moved back: the item then stays in the
    /// trash, listed and restorable, and the error carries it.
    ///
    /// `now` and `id` exist for tests; `id` must be a plain folder name.
    @discardableResult
    static func moveToTrash(_ url: URL, libraryRoot: URL, now: Date = Date(), id: String? = nil,
                            mover: Mover = coordinatedMove) throws -> TrashedItem {
        let fm = FileManager.default
        let name = url.lastPathComponent

        if PinPath.realName(ofPlaceholder: name) != name { throw TrashError.stillInICloud(url) }
        guard let relative = TrashPath.relativePath(of: url, in: libraryRoot) else {
            throw TrashError.outsideLibrary(url)
        }
        guard TrashPath.components(ofRelativePath: relative) != nil else { throw TrashError.hiddenItem(url) }

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            let placeholder = url.deletingLastPathComponent()
                .appendingPathComponent(PinPath.placeholderName(for: name))
            throw fm.fileExists(atPath: placeholder.path)
                ? TrashError.stillInICloud(placeholder) : TrashError.sourceMissing(url)
        }

        let kind: TrashKind = isDirectory.boolValue ? .folder : .note
        var assetsSource: URL?
        if kind == .note, url.pathExtension.lowercased() == "md" {
            let candidate = NoteAssets.folderURL(for: url)
            var assetsIsDirectory: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &assetsIsDirectory), assetsIsDirectory.boolValue {
                assetsSource = candidate
            }
        }

        let itemID = id ?? TrashNaming.makeID(now: now)
        guard TrashNaming.isSafeID(itemID) else { throw TrashError.invalidItem(itemID) }
        let folder = itemFolder(id: itemID, in: libraryRoot)
        let deletedAt = Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down))
        let origin = TrashOrigin(path: relative, kind: kind, deletedAt: deletedAt,
                                 payloadName: name, assetsName: assetsSource?.lastPathComponent)
        let item = TrashedItem(id: itemID, kind: kind, originalPath: relative, originKnown: true,
                               deletedAt: deletedAt, payloadName: name,
                               assetsName: assetsSource?.lastPathComponent, state: .ready)

        // 1. origin.json first, so a crash after the move still says where it came from
        // The item folder itself is created WITHOUT intermediates, so an id that already
        // exists fails here, before anything of the existing item is touched or tidied.
        try CoordinatedFile.createDirectory(at: trashDirectory(in: libraryRoot), withIntermediateDirectories: true)
        try CoordinatedFile.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
            try CoordinatedFile.write(try origin.encoded(), to: folder.appendingPathComponent(originFileName))
        } catch {
            tidy(folder)
            throw error
        }

        // 2. the note (or the folder)
        let payload = folder.appendingPathComponent(name)
        do { try mover(url, payload) }
        catch {
            tidy(folder)
            throw error
        }

        // 3. its attachments; if they cannot move, the note goes back
        if let assetsSource {
            do { try mover(assetsSource, folder.appendingPathComponent(assetsSource.lastPathComponent)) }
            catch let moveError {
                do { try mover(payload, url) }
                catch { throw TrashError.rollbackFailed(item: item, underlying: moveError) }
                tidy(folder)
                throw moveError
            }
        }
        return item
    }

    /// Moves several things, each on its own: one that cannot be moved does not
    /// stop the others. The result says what moved (in the order given) and
    /// what did not, so a multi-select delete can undo exactly what happened.
    static func moveToTrash(_ urls: [URL], libraryRoot: URL, now: Date = Date(),
                            mover: Mover = coordinatedMove) -> TrashBatch {
        var batch = TrashBatch()
        for url in urls {
            do { batch.items.append(try moveToTrash(url, libraryRoot: libraryRoot, now: now, mover: mover)) }
            catch { batch.failures.append(TrashFailure(url: url, error: error)) }
        }
        return batch
    }

    // MARK: - Restore

    /// Puts an item back and returns where it now is.
    ///
    /// The item is read again from disk, so a stale `TrashedItem` (restored or
    /// deleted on another device meanwhile) throws `itemGone` instead of acting
    /// on what is no longer there. An item still downloading throws
    /// `stillDownloading`.
    ///
    /// Nothing is overwritten: the name must be free for the note and for its
    /// `.assets` folder, ignoring case; otherwise "X 2", "X 3", ... is used for
    /// both, the folder is renamed on the way in, and the note's image
    /// references are rewritten to match. A missing parent folder is recreated.
    /// If a later step fails, the earlier ones are undone.
    @discardableResult
    static func restore(_ item: TrashedItem, libraryRoot: URL, mover: Mover = coordinatedMove,
                        writer: Writer = coordinatedWrite) throws -> URL {
        let fm = FileManager.default
        guard TrashNaming.isSafeID(item.id) else { throw TrashError.invalidItem(item.id) }
        let folder = itemFolder(id: item.id, in: libraryRoot)
        guard let fresh = inspect(folder: folder) else { throw TrashError.itemGone(item.id) }
        guard fresh.state == .ready else { throw TrashError.stillDownloading(item.id) }

        let parentParts = TrashPath.components(ofRelativePath: fresh.originalFolder) ?? []
        let parent = parentParts.reduce(libraryRoot) { $0.appendingPathComponent($1, isDirectory: true) }
        let payload = folder.appendingPathComponent(fresh.payloadName)
        var assets: URL?
        if let assetsName = fresh.assetsName {
            var isDirectory: ObjCBool = false
            let candidate = folder.appendingPathComponent(assetsName)
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue { assets = candidate }
        }

        // names already in the destination, folded; a placeholder holds the name of the file it stands for
        let taken = Set(((try? fm.contentsOfDirectory(atPath: parent.path)) ?? [])
            .map { TrashNaming.fold(PinPath.realName(ofPlaceholder: $0)) })

        let wanted = fresh.displayName
        let destination: URL
        var destinationAssets: URL?
        var rewrite: (from: String, to: String)?

        switch fresh.kind {
        case .folder where wanted.hasSuffix(".assets") && wanted.count > ".assets".count:
            // an attachments folder without its note: its name is "<stem>.assets"
            let stem = String(wanted.dropLast(".assets".count))
            let chosen = TrashNaming.freeStem(stem, taken: taken, names: { [$0 + ".assets"] })
            destination = parent.appendingPathComponent(chosen + ".assets", isDirectory: true)
        case .folder:
            let chosen = TrashNaming.freeStem(wanted, taken: taken, names: { [$0] })
            destination = parent.appendingPathComponent(chosen, isDirectory: true)
        case .note:
            let ext = (wanted as NSString).pathExtension
            let stem = (wanted as NSString).deletingPathExtension
            func fileName(_ s: String) -> String { ext.isEmpty ? s : s + "." + ext }
            func assetsName(_ s: String) -> String { s == stem ? (fresh.assetsName ?? s + ".assets") : s + ".assets" }
            let chosen = TrashNaming.freeStem(stem, taken: taken, names: { candidate in
                // the name must be free for X.md and for X.assets whether or not this note has
                // pictures: an orphan X.assets of another note must not be adopted by this one
                [fileName(candidate), assetsName(candidate)]
            })
            destination = parent.appendingPathComponent(fileName(chosen))
            if assets != nil {
                destinationAssets = parent.appendingPathComponent(assetsName(chosen), isDirectory: true)
                if chosen != stem, let old = fresh.assetsName { rewrite = (old, assetsName(chosen)) }
            }
        }

        // a rename means the note's text changes: read it now, before anything moves
        var newContent: String?
        if let rewrite {
            let original = try CoordinatedFile.read(payload)
            let changed = TrashNaming.rewriteAssetReferences(in: original, from: rewrite.from, to: rewrite.to)
            if changed != original { newContent = changed }
        }

        if !fm.fileExists(atPath: parent.path) {
            try CoordinatedFile.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        var done: [(from: URL, to: URL)] = []
        do {
            try mover(payload, destination)
            done.append((payload, destination))
            if let assets, let destinationAssets {
                try mover(assets, destinationAssets)
                done.append((assets, destinationAssets))
            }
            if let newContent { try writer(newContent, destination) }
        } catch {
            var undone = true
            for step in done.reversed() {
                do { try mover(step.to, step.from) } catch { undone = false }
            }
            if undone { throw error }
            // name a part that is really there: the note or the pictures, whichever did not go back
            let remaining = [destination, destinationAssets].compactMap { $0 }
                .first { fm.fileExists(atPath: $0.path) }
            throw TrashError.partialRestore(restored: remaining, underlying: error)
        }

        tidy(folder)
        return destination
    }

    // MARK: - Delete forever

    /// Permanently deletes exactly these items, nothing else. An item that is
    /// already gone is not a failure. The trash folder itself is never removed.
    /// Returns what could not be deleted (an id that is not a plain folder
    /// name, or a file that would not go); an item with a failure keeps its
    /// origin.json so it stays recognisable.
    @discardableResult
    static func deleteForever(_ items: [TrashedItem], libraryRoot: URL) -> [TrashFailure] {
        let fm = FileManager.default
        var failures: [TrashFailure] = []
        var seen = Set<String>()

        for item in items where seen.insert(item.id).inserted {
            let folder = itemFolder(id: item.id, in: libraryRoot)
            guard TrashNaming.isSafeID(item.id) else {
                failures.append(TrashFailure(url: folder, error: TrashError.invalidItem(item.id)))
                continue
            }
            if isSymbolicLink(folder) {
                // never follow a link out of the trash
                failures.append(TrashFailure(url: folder, error: TrashError.invalidItem(item.id)))
                continue
            }
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue,
                  let children = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }

            var failed = false
            for child in children where child != originFileName {
                do { try CoordinatedFile.remove(folder.appendingPathComponent(child)) }
                catch where isAlreadyGone(error) { }
                catch {
                    failed = true
                    failures.append(TrashFailure(url: folder.appendingPathComponent(child), error: error))
                }
            }
            if !failed, children.contains(originFileName) {
                do { try CoordinatedFile.remove(folder.appendingPathComponent(originFileName)) }
                catch where isAlreadyGone(error) { }
                catch {
                    failed = true
                    failures.append(TrashFailure(url: folder.appendingPathComponent(originFileName), error: error))
                }
            }
            if !failed { try? CoordinatedFile.removeEmptyDirectory(folder) }
        }
        return failures
    }

    // MARK: - List

    /// The trash, newest first. Runs off the main thread and never waits for a
    /// download: an item whose parts are still arriving is listed as
    /// `.downloading` and its download is started.
    static func list(libraryRoot: URL) async -> [TrashedItem] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: listNow(libraryRoot: libraryRoot))
            }
        }
    }

    /// The synchronous listing `list` runs off the main thread. Reads, never
    /// writes or deletes.
    static func listNow(libraryRoot: URL) -> [TrashedItem] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: trashDirectory(in: libraryRoot),
                                                        includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles]) else { return [] }
        var items: [TrashedItem] = []
        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let item = inspect(folder: entry) else { continue }
            items.append(item)
        }
        return items.sorted {
            if $0.deletedAt != $1.deletedAt { return $0.deletedAt > $1.deletedAt }
            return $0.id > $1.id
        }
    }

    // MARK: - Reading an item folder

    /// What one item folder holds, or nil when it holds nothing that can be
    /// shown as an item (empty, ambiguous, or an origin.json whose payload has
    /// not arrived). Reads only; starts downloads for iCloud placeholders.
    ///
    /// The states (rule 5):
    ///  - origin.json is only a placeholder, or the payload is: `.downloading`
    ///  - origin.json is missing, unreadable or not believed, and a single file
    ///    or folder is there: `.ready`, restorable to the library root
    ///  - origin.json is readable and the payload is there: `.ready`
    ///  - origin.json is readable and the payload is not there (yet): not listed
    ///    -- unless exactly one other thing is there, then that is the payload (a
    ///    1.4-era device renamed or edited it inside the trash)
    static func inspect(folder: URL) -> TrashedItem? {
        let fm = FileManager.default
        let id = folder.lastPathComponent
        guard !isSymbolicLink(folder),
              let children = try? fm.contentsOfDirectory(atPath: folder.path) else { return nil }
        let root = rootOfTrashItem(folder)

        var real: [String] = []
        var stubs: [String] = []        // the names the placeholders stand for
        for child in children {
            if child.hasPrefix("."), child.hasSuffix(".icloud"), child.count > ".icloud".count + 1 {
                stubs.append(PinPath.realName(ofPlaceholder: child))
            } else if !child.hasPrefix(".") {
                real.append(child)
            }
        }
        let others = real.filter { $0 != originFileName }
        let fallbackDate = TrashNaming.date(fromID: id)
            ?? ((try? fm.attributesOfItem(atPath: folder.path))?[.creationDate] as? Date)
            ?? .distantPast

        for stub in stubs { startDownload(folder.appendingPathComponent(stub)) }

        func isDirectory(_ name: String) -> Bool {
            var d: ObjCBool = false
            return fm.fileExists(atPath: folder.appendingPathComponent(name).path, isDirectory: &d) && d.boolValue
        }

        /// The one thing in the folder that is not origin.json or an assets folder; or, when
        /// there is nothing but attachments folders, the first of them (an orphan: its note was
        /// restored alone, or went elsewhere). Several orphans come out one after the other, each
        /// listing again once the one before it has been restored or deleted.
        /// `recordedAssets` is the attachments folder origin.json names, which belongs to the
        /// note even when the note's stem no longer matches it.
        func single(recordedAssets: String? = nil) -> (name: String, kind: TrashKind, assets: String?, isStub: Bool)? {
            let assetsFolders = others.filter { $0.hasSuffix(".assets") && isDirectory($0) }.sorted()
            let files = others.filter { !assetsFolders.contains($0) }
            let stubFiles = stubs.filter { $0 != originFileName }
            if files.isEmpty && stubFiles.isEmpty {
                guard let first = assetsFolders.first else { return nil }
                return (first, .folder, nil, false)
            }
            guard files.count + stubFiles.count == 1 else { return nil }
            let name = files.first ?? stubFiles[0]
            let isStub = files.isEmpty
            let kind: TrashKind = (!isStub && isDirectory(name)) ? .folder : .note
            let stem = (name as NSString).deletingPathExtension
            var assets: String?
            if kind == .note {
                if let recordedAssets, assetsFolders.contains(recordedAssets) { assets = recordedAssets }
                else { assets = assetsFolders.first { $0 == stem + ".assets" } }
            }
            return (name, kind, assets, isStub)
        }

        let jsonPresent = real.contains(originFileName)

        if !jsonPresent, stubs.contains(originFileName) {
            // origin.json has not arrived: listed, not restorable yet
            let found = single()
            return TrashedItem(id: id, kind: found?.kind ?? .note, originalPath: found?.name ?? "",
                               originKnown: false, deletedAt: fallbackDate, payloadName: found?.name ?? "",
                               assetsName: found?.assets, state: .downloading)
        }

        if jsonPresent,
           let text = try? CoordinatedFile.read(folder.appendingPathComponent(originFileName)),
           let origin = TrashOrigin.decode(Data(text.utf8)),
           believed(origin, root: root) {
            let date = origin.deletedDate ?? fallbackDate
            if real.contains(origin.payloadName) {
                return TrashedItem(id: id, kind: origin.kind, originalPath: origin.path, originKnown: true,
                                   deletedAt: date, payloadName: origin.payloadName,
                                   assetsName: origin.assetsName, state: .ready)
            }
            if stubs.contains(origin.payloadName) {
                return TrashedItem(id: id, kind: origin.kind, originalPath: origin.path, originKnown: true,
                                   deletedAt: date, payloadName: origin.payloadName,
                                   assetsName: origin.assetsName, state: .downloading)
            }
            // the recorded payload is not there: a single other thing stands in for it
            guard let found = single(recordedAssets: origin.assetsName) else { return nil }
            let parent = origin.path.split(separator: "/").dropLast().joined(separator: "/")
            return TrashedItem(id: id, kind: found.kind, originalPath: parent.isEmpty ? found.name : parent + "/" + found.name,
                               originKnown: true, deletedAt: date, payloadName: found.name,
                               assetsName: found.assets, state: found.isStub ? .downloading : .ready)
        }

        // no origin.json, or one that is not believed: whatever single thing is there, to the root
        guard let found = single() else { return nil }
        return TrashedItem(id: id, kind: found.kind, originalPath: found.name, originKnown: false,
                           deletedAt: fallbackDate, payloadName: found.name, assetsName: found.assets,
                           state: found.isStub ? .downloading : .ready)
    }

    // MARK: - Private

    /// The library root an item folder lives under (`<root>/.purnote/trash/<id>`).
    private static func rootOfTrashItem(_ folder: URL) -> URL {
        folder.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Whether the recorded origin may be acted on: a path that stays inside the
    /// library and plain payload and attachment names.
    private static func believed(_ origin: TrashOrigin, root: URL) -> Bool {
        TrashPath.resolve(origin.path, in: root) != nil
            && TrashPath.isSafeName(origin.payloadName)
            && (origin.assetsName.map(TrashPath.isSafeName) ?? true)
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func startDownload(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    private static func isAlreadyGone(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain { return ns.code == NSFileNoSuchFileError || ns.code == NSFileReadNoSuchFileError }
        if ns.domain == NSPOSIXErrorDomain { return ns.code == Int(ENOENT) }
        return false
    }

    /// After a restore, a rollback or a failed move: delete origin.json, then
    /// remove the item folder only if that left it empty. Never recursive;
    /// failures are ignored because there is nothing safe left to do about them.
    private static func tidy(_ folder: URL) {
        try? CoordinatedFile.remove(folder.appendingPathComponent(originFileName))
        try? CoordinatedFile.removeEmptyDirectory(folder)
    }
}
