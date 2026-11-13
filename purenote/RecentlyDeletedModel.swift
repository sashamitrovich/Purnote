//
//  RecentlyDeletedModel.swift
//  purenote
//
//  What the Recently Deleted screen knows and does, without any SwiftUI: the
//  rows, loading them, Restore, Delete Forever, and Delete All. The disk work
//  sits behind `Backend`, so the tests can drive every path (and every failure)
//  with an in-memory one, and one test runs the live one on a real library.
//
//  Delete All is a two-step action on purpose: `requestDeleteAll` takes a
//  snapshot of the items listed at that moment and the confirmation states its
//  count; `confirmDeleteAll` deletes exactly those items, whatever the list
//  has become meanwhile. It never touches the trash folder as a whole.
//

import Foundation

@MainActor
final class RecentlyDeletedModel: ObservableObject {

    /// One line of the list, ready to show.
    struct Row: Identifiable, Equatable {
        let item: TrashedItem
        let title: String
        /// The folder it came from.
        let detail: String
        /// An SF Symbol name.
        let icon: String

        var id: String { item.id }
        var isRestorable: Bool { item.isRestorable }

        /// `firstLine` is the first line of a note's text, when it could be read
        /// cheaply; without it a note is shown under its file name.
        static func make(_ item: TrashedItem, firstLine: String?) -> Row {
            let name = item.displayName
            let title: String
            let icon: String
            if item.kind == .folder, name.hasSuffix(".assets"), name.count > ".assets".count {
                // the pictures of a note that was restored on its own
                title = "Pictures"
                icon = "photo.on.rectangle"
            } else if item.kind == .folder {
                title = name.isEmpty ? "Deleted item" : name
                icon = "folder"
            } else {
                let line = firstLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stem = (name as NSString).deletingPathExtension
                title = !line.isEmpty ? line : (stem.isEmpty ? "Deleted item" : stem)
                icon = "doc.text"
            }
            let folder = item.originalFolder
            let detail = !item.originKnown ? "Original folder unknown" : (folder.isEmpty ? "Purnote" : folder)
            return Row(item: item, title: title, detail: detail, icon: icon)
        }
    }

    /// The disk work. `live` is the real one.
    struct Backend {
        var list: () async -> [Row]
        var restore: (TrashedItem) throws -> Void
        var deleteForever: ([TrashedItem]) async -> [TrashFailure]

        /// `data` is the DataManager of the folder on screen: restoring through it
        /// refreshes the home list when the item comes back into it, and updates
        /// the search index.
        static func live(root: URL, data: DataManager?, index: SearchIndex?) -> Backend {
            Backend(
                list: {
                    let items = await TrashStore.list(libraryRoot: root)
                    // the first lines are read off the main thread too
                    return await Task.detached(priority: .userInitiated) {
                        items.map { Row.make($0, firstLine: RecentlyDeletedModel.firstLine(of: $0, libraryRoot: root)) }
                    }.value
                },
                restore: { item in
                    if let data { _ = try data.restore(item, index: index) }
                    else { _ = try TrashStore.restore(item, libraryRoot: root) }
                },
                deleteForever: { items in
                    await Task.detached(priority: .userInitiated) {
                        TrashStore.deleteForever(items, libraryRoot: root)
                    }.value
                })
        }
    }

    @Published private(set) var rows: [Row] = []
    /// False until the first read has finished, so the screen does not say
    /// "Nothing deleted." while it is still reading.
    @Published private(set) var hasLoaded = false
    @Published var alert: TrashAlert?
    /// What Delete All would delete: the items listed when it was asked for.
    @Published private(set) var deleteAllCandidates: [TrashedItem]?

    private let backend: Backend
    /// Bumped by every change, so a read that was already under way when the
    /// change happened cannot bring back what the change took away.
    private var generation = 0

    init(backend: Backend) {
        self.backend = backend
    }

    func load() async {
        generation += 1
        let mine = generation
        let fresh = await backend.list()
        guard mine == generation else { return }
        rows = fresh
        hasLoaded = true
    }

    func restore(_ row: Row) async {
        guard row.isRestorable else { return }
        generation += 1
        do {
            try backend.restore(row.item)
            rows.removeAll { $0.id == row.id }
        } catch {
            alert = TrashAlert(title: "Could not restore", message: error.localizedDescription)
            await load()        // it may be gone, or half restored; show what is really there
        }
    }

    func deleteForever(_ row: Row) async {
        generation += 1
        let failures = await backend.deleteForever([row.item])
        if failures.isEmpty {
            rows.removeAll { $0.id == row.id }
        } else {
            alert = TrashAlert(title: "Could not delete", message: failures[0].error.localizedDescription)
            await load()
        }
    }

    // MARK: Delete All

    func requestDeleteAll() {
        guard !rows.isEmpty else { return }
        deleteAllCandidates = rows.map(\.item)
    }

    func cancelDeleteAll() {
        deleteAllCandidates = nil
    }

    func confirmDeleteAll() async {
        guard let items = deleteAllCandidates else { return }
        deleteAllCandidates = nil
        generation += 1
        let failures = await backend.deleteForever(items)
        if failures.isEmpty {
            let gone = Set(items.map(\.id))
            rows.removeAll { gone.contains($0.id) }
        } else {
            // a failure names a file inside an item folder; count the items it belongs to
            let failed = items.filter { item in failures.contains { $0.url.pathComponents.contains(item.id) } }
            alert = TrashAlert(title: "Could not delete everything",
                               message: "\(max(failed.count, 1)) of \(items.count) could not be deleted. \(failures[0].error.localizedDescription)")
            await load()
        }
    }

    // MARK: Reading a title

    /// The first line of a deleted note, for the row title; nil when it is not a
    /// note that is here and readable.
    nonisolated static func firstLine(of item: TrashedItem, libraryRoot: URL) -> String? {
        guard item.kind == .note, item.state == .ready,
              TrashNaming.isSafeID(item.id), TrashPath.isSafeName(item.payloadName) else { return nil }
        return firstLine(ofFileAt: TrashStore.itemFolder(id: item.id, in: libraryRoot)
            .appendingPathComponent(item.payloadName))
    }

    /// The first line of a Markdown file, from at most the first 2 KB. Not a
    /// coordinated read of the whole note, and never through a symbolic link:
    /// it is only a label, so it takes the cheap, safe way or gives up.
    nonisolated static func firstLine(ofFileAt url: URL) -> String? {
        guard url.pathExtension.lowercased() == "md",
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isSymbolicLink != true, values.isRegularFile == true,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 2048), !data.isEmpty else { return nil }
        let title = NoteRowText.title(of: String(decoding: data, as: UTF8.self))
        return title.isEmpty ? nil : String(title.prefix(200))
    }
}
