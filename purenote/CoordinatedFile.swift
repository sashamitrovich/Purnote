//
//  CoordinatedFile.swift
//  purenote
//

import Foundation

/// Every read and write of a note goes through here.
///
/// The notes live inside the iCloud ubiquity container, which means this app
/// is not the only thing writing them: the sync daemon replaces files as they
/// arrive from the Mac. Reading and writing them directly is a race. A read
/// can land in the middle of a write and return a truncated note, and a write
/// during an upload makes iCloud produce a conflict version that nothing in
/// the app ever looks at.
///
/// NSFileCoordinator is how the app and the daemon take turns.
///
/// These calls are synchronous and can block while the other side finishes,
/// which matches how the rest of the app already does its file work. If the
/// app ever moves its file access off the main thread, this is the layer to
/// make async rather than every call site.
enum CoordinatedFile {

    static func read(_ url: URL) throws -> String {
        var coordinationError: NSError?
        var result: Result<String, Error>?

        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { actual in
            result = Result { try String(contentsOf: actual, encoding: .utf8) }
        }

        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    static func write(_ text: String, to url: URL) throws {
        try coordinateWriting(at: url, options: .forReplacing) { actual in
            try text.write(to: actual, atomically: true, encoding: .utf8)
        }
    }

    /// Binary variant for attachments (images etc.): same coordination, just
    /// raw bytes instead of UTF-8 text.
    static func write(_ data: Data, to url: URL) throws {
        try coordinateWriting(at: url, options: .forReplacing) { actual in
            try data.write(to: actual, options: .atomic)
        }
    }

    static func createDirectory(at url: URL, withIntermediateDirectories intermediates: Bool = false) throws {
        try coordinateWriting(at: url, options: .forReplacing) { actual in
            try FileManager.default.createDirectory(at: actual,
                                                    withIntermediateDirectories: intermediates)
        }
    }

    /// Moves to the system Trash. Not used for notes and folders any more: the
    /// app deletes through `TrashStore` (its own Recently Deleted folder), because
    /// the system Trash does not exist on the simulator and the url an item went to
    /// is thrown away here, so neither testing nor Undo is possible with this.
    static func trash(_ url: URL) throws {
        try coordinateWriting(at: url, options: .forDeleting) { actual in
            try FileManager.default.trashItem(at: actual, resultingItemURL: nil)
        }
    }

    /// Deletes one file or folder, with everything in it, through the
    /// coordinator. Not the system Trash: callers use this only on things they
    /// are meant to delete for good (the trash's own contents).
    static func remove(_ url: URL) throws {
        try coordinateWriting(at: url, options: .forDeleting) { actual in
            try FileManager.default.removeItem(at: actual)
        }
    }

    /// Removes a folder only if it is empty. This is rmdir, which the system
    /// refuses on a folder with anything in it, so unlike `remove` it can never
    /// delete content: it is how the trash tidies up an item folder.
    static func removeEmptyDirectory(_ url: URL) throws {
        try coordinateWriting(at: url, options: .forDeleting) { actual in
            if rmdir(actual.path) != 0 {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
    }

    /// Both ends are coordinated: a rename or a move between folders touches
    /// two places, and the daemon may be interested in either.
    static func move(from source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var moveError: Error?

        NSFileCoordinator().coordinate(writingItemAt: source, options: .forMoving,
                                       writingItemAt: destination, options: .forReplacing,
                                       error: &coordinationError) { fromURL, toURL in
            do { try FileManager.default.moveItem(at: fromURL, to: toURL) }
            catch { moveError = error }
        }

        if let coordinationError { throw coordinationError }
        if let moveError { throw moveError }
    }

    /// Copies a file or folder. The destination is written under coordination;
    /// the source is read under coordination too, since the daemon may be
    /// replacing it.
    static func copy(from source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?

        NSFileCoordinator().coordinate(readingItemAt: source, options: [],
                                       writingItemAt: destination, options: .forReplacing,
                                       error: &coordinationError) { fromURL, toURL in
            do { try FileManager.default.copyItem(at: fromURL, to: toURL) }
            catch { copyError = error }
        }

        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }

    private static func coordinateWriting(at url: URL,
                                          options: NSFileCoordinator.WritingOptions,
                                          _ body: @escaping (URL) throws -> Void) throws {
        var coordinationError: NSError?
        var innerError: Error?

        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordinationError) { actual in
            do { try body(actual) }
            catch { innerError = error }
        }

        if let coordinationError { throw coordinationError }
        if let innerError { throw innerError }
    }
}
