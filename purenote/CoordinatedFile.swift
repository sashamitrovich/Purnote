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

    static func createDirectory(at url: URL, withIntermediateDirectories intermediates: Bool = false) throws {
        try coordinateWriting(at: url, options: .forReplacing) { actual in
            try FileManager.default.createDirectory(at: actual,
                                                    withIntermediateDirectories: intermediates)
        }
    }

    /// Moves to the Trash, so a delete stays recoverable.
    static func trash(_ url: URL) throws {
        try coordinateWriting(at: url, options: .forDeleting) { actual in
            try FileManager.default.trashItem(at: actual, resultingItemURL: nil)
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
