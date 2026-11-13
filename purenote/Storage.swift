//
//  Storage.swift
//  purenote
//

import Foundation

/// Where the notes live when iCloud Drive is not available.
///
/// The app is plain files in a directory, and a directory does not have to be
/// an iCloud one. Without this the app refused to start at all when iCloud
/// Drive was switched off, not signed in, out of space, or restricted -- none
/// of which is necessarily the user's to fix at that moment.
enum Storage {

    private static let fm = FileManager.default

    /// The app's own Documents directory. Private to the app and not synced,
    /// but the notes are still ordinary .md files.
    static func local() -> Connection {
        let root = isUITestFixture
            ? uiTestFixtureRoot
            : fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return Connection(rootUrl: root, connectionAvailable: true, isLocal: true)
    }

    // MARK: - UI test fixture

    /// Launch argument the UI tests pass. It makes the app use local storage in
    /// a fresh, empty folder created for that launch, holding a fixed set of
    /// notes, so the tests never depend on what an earlier run (or the
    /// first-run sample library) left behind. A normal launch never sees it.
    static let uiTestFixtureArgument = "-UITestFixture"

    static var isUITestFixture: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestFixtureArgument)
    }

    /// Notes the fixture library contains, taken from SampleNotes.all by path.
    private static let uiTestFixturePaths = [
        "Marathon training.md",
        "Journal/Morning pages.md",
        "Recipes/Sourdough.md",
    ]

    /// Created once per process: a new empty folder, filled with the fixture
    /// notes before anything reads it.
    private static let uiTestFixtureRoot: URL = {
        let root = fm.temporaryDirectory
            .appendingPathComponent("purnote-uitest-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        for note in SampleNotes.all where uiTestFixturePaths.contains(note.path) {
            let url = root.appendingPathComponent(note.path)
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? note.content.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }()

    static var localIsEmpty: Bool {
        let contents = (try? fm.contentsOfDirectory(atPath: local().rootUrl.path)) ?? []
        return contents.filter { !$0.hasPrefix(".") }.isEmpty
    }

    /// Moves everything from one root into another, recursively.
    ///
    /// Nothing is overwritten and nothing is left behind. A note whose name is
    /// already taken at the destination is moved under a free name instead --
    /// skipping it would leave it in a directory the app has stopped looking
    /// at, which is a quieter way to lose someone's writing than overwriting
    /// it. Folders of the same name are merged.
    @discardableResult
    static func move(from source: URL, to destination: URL,
                     mover: (_ from: URL, _ to: URL) throws -> Void = { try CoordinatedFile.move(from: $0, to: $1) })
        -> (moved: Int, renamed: Int, failed: Int) {
        var moved = 0, renamed = 0, failed = 0

        let items = (try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)) ?? []

        // A note that has to take a new name because its name is taken here
        // brings its OWN pictures along under the matching new name. Merging
        // "X.assets" into the other note's "X.assets" would leave the renamed
        // note pointing at the other note's pictures.
        var ownAssets: [String: String] = [:]      // old stem -> new stem
        for item in items where item.pathExtension == "md" && !item.hasDirectoryPath {
            let stem = item.deletingPathExtension().lastPathComponent
            let hasPictures = fm.fileExists(atPath: source.appendingPathComponent(stem + ".assets").path)
            guard hasPictures, fm.fileExists(atPath: destination.appendingPathComponent(item.lastPathComponent).path)
            else { continue }
            ownAssets[stem] = freeStem(for: item, in: destination)
        }

        for item in items where item.lastPathComponent != ".Trash" {
            let taken = destination.appendingPathComponent(item.lastPathComponent)

            // handled together with its note, below
            if item.hasDirectoryPath, item.pathExtension == "assets",
               ownAssets[item.deletingPathExtension().lastPathComponent] != nil {
                continue
            }

            if item.pathExtension == "md", !item.hasDirectoryPath,
               let newStem = ownAssets[item.deletingPathExtension().lastPathComponent] {
                let stem = item.deletingPathExtension().lastPathComponent
                let oldAssets = source.appendingPathComponent(stem + ".assets")
                let newAssets = destination.appendingPathComponent(newStem + ".assets")
                let target = destination.appendingPathComponent(newStem).appendingPathExtension("md")
                do {
                    try mover(oldAssets, newAssets)
                    do { try mover(item, target) }
                    catch {
                        // note and pictures stay together: put the pictures back
                        try? mover(newAssets, oldAssets)
                        throw error
                    }
                    renamed += 1
                    // the copy of the note now says where its pictures went
                    if let text = try? CoordinatedFile.read(target) {
                        let fixed = NoteAssets.rewritingReferences(in: text, from: stem + ".assets",
                                                                   to: newStem + ".assets")
                        if fixed != text { try CoordinatedFile.write(fixed, to: target) }
                    }
                } catch {
                    print("Failed to move \(item.lastPathComponent) to iCloud: \(error).")
                    failed += 1
                }
                continue
            }

            if item.hasDirectoryPath && fm.fileExists(atPath: taken.path) {
                let result = move(from: item, to: taken, mover: mover)
                moved += result.moved
                renamed += result.renamed
                failed += result.failed
                // The folder is gone once it has been emptied. Only then: if anything
                // failed, or anything is left (a skipped .Trash, a file that could not
                // move), the folder and what is in it stay. This is rmdir, never a
                // recursive remove -- `.purnote` is on both sides and holds the trash.
                if result.failed == 0 { try? CoordinatedFile.removeEmptyDirectory(item) }
                continue
            }

            // the pin list is one shared file: fold it into the destination's
            // rather than letting it become "pins (from iPhone).json"
            if PinStore.mergeIncoming(item, into: taken) { moved += 1; continue }

            let target = freeName(for: item, in: destination)
            do {
                try mover(item, target)
                if target != taken { renamed += 1 } else { moved += 1 }
            }
            catch {
                // failed
                print("Failed to move \(item.lastPathComponent) to iCloud: \(error).")
                failed += 1
            }
        }

        return (moved, renamed, failed)
    }

    /// The stem for an incoming note that clashes: `note` -> `note (from iPhone)`,
    /// then `note (from iPhone 2)`, where neither the note nor its `.assets`
    /// folder is taken in `destination`.
    private static func freeStem(for item: URL, in destination: URL) -> String {
        let stem = item.deletingPathExtension().lastPathComponent
        for suffix in 1...500 {
            let name = suffix == 1 ? "\(stem) (from iPhone)" : "\(stem) (from iPhone \(suffix))"
            if !fm.fileExists(atPath: destination.appendingPathComponent(name + ".md").path),
               !fm.fileExists(atPath: destination.appendingPathComponent(name + ".assets").path) {
                return name
            }
        }
        return "\(stem) (from iPhone \(UUID().uuidString))"
    }

    /// `note.md` -> `note (from iPhone).md`, then `note (from iPhone 2).md`.
    private static func freeName(for item: URL, in destination: URL) -> URL {
        let target = destination.appendingPathComponent(item.lastPathComponent)
        guard fm.fileExists(atPath: target.path) else { return target }

        let ext = item.pathExtension
        let stem = item.deletingPathExtension().lastPathComponent

        for suffix in 1...500 {
            let name = suffix == 1 ? "\(stem) (from iPhone)" : "\(stem) (from iPhone \(suffix))"
            let candidate = destination.appendingPathComponent(name).appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return destination.appendingPathComponent("\(stem) (from iPhone \(UUID().uuidString))")
            .appendingPathExtension(ext)
    }
}
