//
//  TrashStoreTests.swift
//  purenoteTests
//
//  The library's own trash (.purnote/trash/<date>-<uuid>/). Everything runs in
//  temp-directory libraries: the simulator has no system Trash, so nothing here
//  may (or does) call trashItem.
//

@testable import Purnote
import XCTest

/// A throwaway library on disk plus the small helpers every trash test needs.
class TrashFixtureCase: XCTestCase {

    var root: URL!
    var fm: FileManager { .default }

    struct Injected: Error {}

    override func setUpWithError() throws {
        let base = fm.temporaryDirectory.appendingPathComponent("purnote-trash-\(UUID().uuidString)", isDirectory: true)
        root = base.appendingPathComponent("library", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root.deletingLastPathComponent())
    }

    func url(_ rel: String) -> URL { root.appendingPathComponent(rel) }
    var trashDir: URL { root.appendingPathComponent(".purnote/trash", isDirectory: true) }

    @discardableResult
    func write(_ rel: String, _ text: String = "x") throws -> URL {
        let u = url(rel)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: u, atomically: true, encoding: .utf8)
        return u
    }

    func mkdir(_ rel: String) throws {
        try fm.createDirectory(at: url(rel), withIntermediateDirectories: true)
    }

    func read(_ rel: String) -> String? { try? String(contentsOf: url(rel), encoding: .utf8) }
    func exists(_ rel: String) -> Bool { fm.fileExists(atPath: url(rel).path) }

    /// Every name in a folder of the library (hidden ones too), sorted.
    func names(_ rel: String = "") -> [String] {
        ((try? fm.contentsOfDirectory(atPath: url(rel).path)) ?? []).sorted()
    }

    func itemFolders() -> [String] {
        ((try? fm.contentsOfDirectory(atPath: trashDir.path)) ?? []).sorted()
    }

    func folder(of item: TrashedItem) -> URL { trashDir.appendingPathComponent(item.id) }

    func same(_ a: URL?, _ b: URL) -> Bool {
        guard let a else { return false }
        return a.resolvingSymlinksInPath().path == b.resolvingSymlinksInPath().path
    }

    /// A note with an attachments folder holding one image, referenced the
    /// way the app writes references.
    @discardableResult
    func writeNoteWithAssets(_ stem: String, in dir: String = "", body: String? = nil, image: String = "PHOTO") throws -> URL {
        let prefix = dir.isEmpty ? "" : dir + "/"
        let text = body ?? "\(stem)\n![](<\(stem).assets/image.jpg>)\n"
        let note = try write("\(prefix)\(stem).md", text)
        try write("\(prefix)\(stem).assets/image.jpg", image)
        return note
    }

    /// An item folder made by hand, as another device or an older build might leave it.
    @discardableResult
    func makeItemFolder(id: String? = nil, origin: String?, files: [String: String] = [:], dirs: [String] = []) throws -> String {
        let name = id ?? TrashNaming.makeID(now: Date())
        let base = ".purnote/trash/\(name)"
        try mkdir(base)
        if let origin { try write("\(base)/origin.json", origin) }
        for (file, text) in files { try write("\(base)/\(file)", text) }
        for dir in dirs { try mkdir("\(base)/\(dir)") }
        return name
    }

    func originJSON(path: String, kind: String = "note", payload: String? = nil, assets: String? = nil,
                    deletedAt: String = "2026-11-13T10:00:00Z", version: Int = 1) -> String {
        let payload = payload ?? (path as NSString).lastPathComponent
        var json = "{\"version\":\(version),\"path\":\(quoted(path)),\"kind\":\"\(kind)\",\"deletedAt\":\"\(deletedAt)\",\"payloadName\":\(quoted(payload))"
        if let assets { json += ",\"assetsName\":\(quoted(assets))" }
        return json + "}"
    }

    private func quoted(_ s: String) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: [s], options: [.withoutEscapingSlashes])) ?? Data("[\"\"]".utf8)
        let text = String(decoding: data, as: UTF8.self)
        return String(text.dropFirst().dropLast())
    }

    func failingMover(when fails: @escaping (URL, URL) -> Bool) -> TrashStore.Mover {
        return { from, to in
            if fails(from, to) { throw Injected() }
            try CoordinatedFile.move(from: from, to: to)
        }
    }

    func isInsideTrash(_ u: URL) -> Bool { u.path.contains("/.purnote/trash/") }
}

final class TrashStoreTests: TrashFixtureCase {

    // MARK: - round trips

    func testNoteAndAssetsRoundTrip() throws {
        let note = try writeNoteWithAssets("Trip", in: "Travel")
        let item = try TrashStore.moveToTrash(note, libraryRoot: root)

        XCTAssertFalse(exists("Travel/Trip.md"))
        XCTAssertFalse(exists("Travel/Trip.assets"))
        XCTAssertEqual(item.kind, .note)
        XCTAssertEqual(item.originalPath, "Travel/Trip.md")
        XCTAssertEqual(item.payloadName, "Trip.md")
        XCTAssertEqual(item.assetsName, "Trip.assets")
        XCTAssertEqual(item.state, .ready)
        XCTAssertTrue(item.originKnown)
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["Trip.assets", "Trip.md", "origin.json"])

        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Travel/Trip.md")), "\(restored.path)")
        XCTAssertEqual(read("Travel/Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n")
        XCTAssertEqual(read("Travel/Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(itemFolders(), [], "the emptied item folder is removed")
        XCTAssertTrue(fm.fileExists(atPath: trashDir.path), "the trash folder itself stays")
    }

    func testNoteWithoutAssetsRoundTrip() throws {
        let note = try write("Plain.md", "Plain\ntext")
        let item = try TrashStore.moveToTrash(note, libraryRoot: root)
        XCTAssertNil(item.assetsName)
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["Plain.md", "origin.json"])
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Plain.md")))
        XCTAssertEqual(read("Plain.md"), "Plain\ntext")
    }

    func testFolderWithNestedNotesRoundTrip() throws {
        try writeNoteWithAssets("Rome", in: "Travel")
        try write("Travel/Sub/Paris.md", "Paris")
        try write("Travel/Sub/Deeper/Oslo.md", "Oslo")
        let item = try TrashStore.moveToTrash(url("Travel"), libraryRoot: root)

        XCTAssertEqual(item.kind, .folder)
        XCTAssertEqual(item.originalPath, "Travel")
        XCTAssertEqual(item.payloadName, "Travel")
        XCTAssertNil(item.assetsName)
        XCTAssertFalse(exists("Travel"))
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["Travel", "origin.json"])

        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Travel")))
        XCTAssertEqual(read("Travel/Rome.md"), "Rome\n![](<Rome.assets/image.jpg>)\n")
        XCTAssertEqual(read("Travel/Rome.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(read("Travel/Sub/Paris.md"), "Paris")
        XCTAssertEqual(read("Travel/Sub/Deeper/Oslo.md"), "Oslo")
        XCTAssertEqual(itemFolders(), [])
    }

    func testTwoDeletesOfTheSameNameDoNotCollide() throws {
        let first = try TrashStore.moveToTrash(try write("A.md", "first"), libraryRoot: root)
        let second = try TrashStore.moveToTrash(try write("A.md", "second"), libraryRoot: root)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(itemFolders().count, 2)
        XCTAssertEqual(Set(TrashStore.listNow(libraryRoot: root).map(\.id)), [first.id, second.id])

        let a = try TrashStore.restore(second, libraryRoot: root)
        let b = try TrashStore.restore(first, libraryRoot: root)
        XCTAssertEqual(a.lastPathComponent, "A.md")
        XCTAssertEqual(b.lastPathComponent, "A 2.md")
        XCTAssertEqual(read("A.md"), "second")
        XCTAssertEqual(read("A 2.md"), "first")
    }

    // MARK: - restore when the name is taken

    func testRestoreWhenTheNoteNameIsTaken() throws {
        let item = try TrashStore.moveToTrash(try write("X.md", "mine"), libraryRoot: root)
        try write("X.md", "the other one")
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "X 2.md")
        XCTAssertEqual(read("X.md"), "the other one", "nothing is overwritten")
        XCTAssertEqual(read("X 2.md"), "mine")
    }

    func testRestoreWhenTheAssetsFolderIsTakenButTheNoteNameIsNot() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("X"), libraryRoot: root)
        try write("X.assets/image.jpg", "STRANGER")   // someone else's folder of that name, no X.md
        let restored = try TrashStore.restore(item, libraryRoot: root)

        XCTAssertEqual(restored.lastPathComponent, "X 2.md", "a free note name is not enough, the folder name must be free too")
        XCTAssertEqual(read("X.assets/image.jpg"), "STRANGER")
        XCTAssertEqual(read("X 2.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(read("X 2.md"), "X\n![](<X 2.assets/image.jpg>)\n")
        XCTAssertFalse(exists("X.md"))
    }

    func testRestoreWhenOnlyTheNoteNameIsTakenRenamesTheAssetsAndTheReferences() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("X"), libraryRoot: root)
        try write("X.md", "the other one")
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "X 2.md")
        XCTAssertEqual(read("X 2.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(read("X 2.md"), "X\n![](<X 2.assets/image.jpg>)\n")
        XCTAssertEqual(read("X.md"), "the other one")
    }

    /// The review's "Trip" case: a note with photos is deleted, then a new note
    /// called Trip with its own photos is made. Restoring must neither overwrite
    /// a photo nor leave the restored note showing the other note's photo.
    func testTripCaseBothNamesTaken() throws {
        let body = "Trip\n![](<Trip.assets/image.jpg>)\nOther Trip.assets/z.jpg is just text\nsee MyTrip.assets/k.jpg\n"
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip", body: body, image: "MINE"), libraryRoot: root)

        try writeNoteWithAssets("Trip", image: "OTHER")   // the new Trip.md + Trip.assets/image.jpg
        let restored = try TrashStore.restore(item, libraryRoot: root)

        XCTAssertEqual(restored.lastPathComponent, "Trip 2.md")
        XCTAssertEqual(read("Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n", "the other note is untouched")
        XCTAssertEqual(read("Trip.assets/image.jpg"), "OTHER", "the other note's photo is untouched")
        XCTAssertEqual(read("Trip 2.assets/image.jpg"), "MINE")

        let content = try XCTUnwrap(read("Trip 2.md"))
        XCTAssertTrue(content.contains("![](<Trip 2.assets/image.jpg>)"), content)
        XCTAssertFalse(content.contains("<Trip.assets/"), "no reference may still point at the other note's folder: \(content)")
        XCTAssertTrue(content.contains("Other Trip.assets/z.jpg is just text"), "plain words are not rewritten: \(content)")
        XCTAssertTrue(content.contains("see MyTrip.assets/k.jpg"), content)
    }

    func testRestoreTreatsNamesAsTakenWhateverTheirCase() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip", image: "MINE"), libraryRoot: root)
        try write("trip.md", "lowercase note")
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "Trip 2.md", "trip.md blocks Trip.md even on a case-sensitive volume")
        XCTAssertEqual(read("trip.md"), "lowercase note")
        XCTAssertEqual(read("Trip 2.assets/image.jpg"), "MINE")
    }

    func testRestoreTreatsALowercaseAssetsFolderAsTaken() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip", image: "MINE"), libraryRoot: root)
        try write("trip.assets/image.jpg", "STRANGER")
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "Trip 2.md")
        XCTAssertEqual(read("trip.assets/image.jpg"), "STRANGER")
    }

    func testRestoreTreatsAnICloudPlaceholderAsATakenName() throws {
        let item = try TrashStore.moveToTrash(try write("X.md", "mine"), libraryRoot: root)
        try write(".X.md.icloud", "")   // a note of that name, not downloaded on this device
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "X 2.md")
    }

    func testRestoreSkipsNumbersAlreadyTaken() throws {
        let item = try TrashStore.moveToTrash(try write("X.md", "mine"), libraryRoot: root)
        try write("X.md"); try write("X 2.md"); try write("x 3.md")
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "X 4.md")
    }

    func testRestoreRecreatesAMissingParentFolder() throws {
        let item = try TrashStore.moveToTrash(try write("Folder/Sub/N.md", "n"), libraryRoot: root)
        try fm.removeItem(at: url("Folder"))
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Folder/Sub/N.md")))
        XCTAssertEqual(read("Folder/Sub/N.md"), "n")
    }

    func testRestoreOfAFolderUsesAFolderNameNotANoteName() throws {
        try write("Travel/Rome.md", "Rome")
        let item = try TrashStore.moveToTrash(url("Travel"), libraryRoot: root)
        try write("Travel/Other.md", "Other")   // the name is taken again
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "Travel 2", "no .md on a folder")
        XCTAssertEqual(read("Travel 2/Rome.md"), "Rome")
        XCTAssertEqual(read("Travel/Other.md"), "Other")
    }

    func testRestoreOfAFolderIsNotBlockedByANoteOfTheSameStem() throws {
        try write("Travel/Rome.md", "Rome")
        let item = try TrashStore.moveToTrash(url("Travel"), libraryRoot: root)
        try write("Travel.md", "a note called Travel")
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "Travel")
    }

    func testRestoreOfAFolderTakenByAFileOfThatNameCaseInsensitively() throws {
        try write("Travel/Rome.md", "Rome")
        let item = try TrashStore.moveToTrash(url("Travel"), libraryRoot: root)
        try mkdir("travel")
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "Travel 2")
    }

    func testRestoreTwiceTheSecondFindsNothingAndNothingIsDuplicated() throws {
        let item = try TrashStore.moveToTrash(try write("A.md", "a"), libraryRoot: root)
        _ = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root)) { error in
            guard case TrashError.itemGone = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(names(), [".purnote", "A.md"])
    }

    func testRestoreFromATrashWhoseNoteIsNotValidTextFailsBeforeMovingAnything() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("X"), libraryRoot: root)
        try write("X.md", "taken")                      // forces a rename, which needs to read the note
        let payload = folder(of: item).appendingPathComponent("X.md")
        try Data([0xFF, 0xFE, 0xFD, 0x00, 0xC3, 0x28]).write(to: payload)
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root))
        XCTAssertEqual(names(), [".purnote", "X.md"])
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["X.assets", "X.md", "origin.json"], "the item is intact")
    }

    // MARK: - origin.json

    func testOriginJSONIsWrittenBeforeAnythingMoves() throws {
        let note = try writeNoteWithAssets("Trip")
        var sawOrigin: [Bool] = []
        let mover: TrashStore.Mover = { from, to in
            sawOrigin.append(FileManager.default.fileExists(atPath: to.deletingLastPathComponent().appendingPathComponent("origin.json").path))
            try CoordinatedFile.move(from: from, to: to)
        }
        _ = try TrashStore.moveToTrash(note, libraryRoot: root, mover: mover)
        XCTAssertEqual(sawOrigin, [true, true], "payload and assets each moved after origin.json existed")
    }

    func testOriginJSONContents() throws {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip", in: "Travel"), libraryRoot: root, now: when)
        let data = try Data(contentsOf: folder(of: item).appendingPathComponent("origin.json"))
        let origin = try XCTUnwrap(TrashOrigin.decode(data))
        XCTAssertEqual(origin, TrashOrigin(path: "Travel/Trip.md", kind: .note, deletedAt: when,
                                           payloadName: "Trip.md", assetsName: "Trip.assets"))
        XCTAssertTrue(item.id.hasPrefix("20231114221320-"), item.id)
    }

    func testMissingOriginJSONIsListedAndRestoresToTheRoot() throws {
        let id = try makeItemFolder(id: "20260101120000-AAAA", origin: nil, files: ["Lonely.md": "text"])
        let items = TrashStore.listNow(libraryRoot: root)
        XCTAssertEqual(items.count, 1)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.id, id)
        XCTAssertFalse(item.originKnown)
        XCTAssertEqual(item.displayName, "Lonely.md")
        XCTAssertEqual(item.state, .ready)
        XCTAssertEqual(item.deletedAt, TrashNaming.date(fromID: id), "the date comes from the folder name")
        XCTAssertEqual(item.kind, .note)

        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Lonely.md")))
        XCTAssertEqual(read("Lonely.md"), "text")
        XCTAssertEqual(itemFolders(), [])
    }

    func testMissingOriginJSONWithAnAssetsFolderKeepsThePair() throws {
        try makeItemFolder(origin: nil, files: ["Trip.md": "Trip\n![](<Trip.assets/image.jpg>)", "Trip.assets/image.jpg": "PHOTO"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.assetsName, "Trip.assets")
        XCTAssertEqual(item.payloadName, "Trip.md")
        try write("Trip.md", "taken")
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "Trip 2.md")
        XCTAssertEqual(read("Trip 2.assets/image.jpg"), "PHOTO")
    }

    func testMissingOriginJSONWithAFolderPayload() throws {
        try makeItemFolder(origin: nil, files: ["Travel/Rome.md": "Rome"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.kind, .folder)
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "Travel")
        XCTAssertEqual(read("Travel/Rome.md"), "Rome")
    }

    func testMissingOriginJSONWithAFileThatIsNotMarkdown() throws {
        try makeItemFolder(origin: nil, files: ["photo.png": "png"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        try write("photo.png", "taken")
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "photo 2.png")
    }

    func testCorruptOriginJSONIsListedAndRestoresToTheRoot() throws {
        try makeItemFolder(origin: "{ this is not json", files: ["Note.md": "n"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertFalse(item.originKnown)
        XCTAssertEqual(item.displayName, "Note.md")
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "Note.md")
        XCTAssertEqual(read("Note.md"), "n")
    }

    func testOriginJSONOfAnUnknownVersionIsNotBelieved() throws {
        try makeItemFolder(origin: originJSON(path: "Folder/Note.md", version: 2), files: ["Note.md": "n"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertFalse(item.originKnown)
        XCTAssertEqual(item.originalFolder, "")
    }

    func testOriginJSONWithAnUnsafePathRestoresToTheRootAndWritesNothingOutside() throws {
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside", isDirectory: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        let before = try fm.contentsOfDirectory(atPath: outside.path)

        let bad = ["/etc/evil.md", "../outside/Note.md", "Folder/../../outside/Note.md", "..", ".purnote/pins.json", "Folder/.hidden/Note.md"]
        for (n, path) in bad.enumerated() {
            let id = "2026010112000\(n)-BAD"
            try makeItemFolder(id: id, origin: originJSON(path: path, payload: "Note.md"), files: ["Note.md": "n\(n)"])
            let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first { $0.id == id }, path)
            XCTAssertFalse(item.originKnown, path)
            XCTAssertEqual(item.originalFolder, "", path)
            let restored = try TrashStore.restore(item, libraryRoot: root)
            XCTAssertTrue(same(restored.deletingLastPathComponent(), root), "\(path) -> \(restored.path)")
            try fm.removeItem(at: restored)
        }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: outside.path), before, "nothing was written outside the library")
        XCTAssertFalse(fm.fileExists(atPath: "/etc/evil.md"))
    }

    func testOriginJSONWithAnUnsafePayloadNameIsNotBelieved() throws {
        try makeItemFolder(origin: originJSON(path: "Note.md", payload: "../../etc/passwd"), files: ["Real.md": "r"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.payloadName, "Real.md")
        XCTAssertFalse(item.originKnown)
    }

    func testRecordedPayloadMissingFallsBackToTheSingleFileInTheFolder() throws {
        try makeItemFolder(origin: originJSON(path: "Folder/Note.md"), files: ["Renamed.md": "renamed"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.state, .ready)
        XCTAssertEqual(item.payloadName, "Renamed.md")
        XCTAssertEqual(item.originalPath, "Folder/Renamed.md", "the recorded folder, the name found")
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Folder/Renamed.md")))
        XCTAssertEqual(read("Folder/Renamed.md"), "renamed")
        XCTAssertEqual(itemFolders(), [])
    }

    func testRecordedPayloadMissingWithSeveralFilesIsNotListedAndNotDeleted() throws {
        let id = try makeItemFolder(origin: originJSON(path: "Note.md"), files: ["One.md": "1", "Two.md": "2"])
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
        XCTAssertEqual(names(".purnote/trash/\(id)"), ["One.md", "Two.md", "origin.json"])
    }

    // MARK: - three sync states

    func testOriginJSONStillDownloadingIsListedAsDownloadingAndNotRestorable() throws {
        let id = try makeItemFolder(origin: nil, files: [".origin.json.icloud": "", ".Note.md.icloud": ""])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.state, .downloading)
        XCTAssertFalse(item.isRestorable)
        XCTAssertEqual(item.displayName, "Note.md", "a stub name is never shown as a title")
        XCTAssertFalse(item.displayName.hasPrefix("."))
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root)) { error in
            guard case TrashError.stillDownloading = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(names(".purnote/trash/\(id)"), [".Note.md.icloud", ".origin.json.icloud"], "nothing touched")
    }

    func testOnlyTheOriginStubPresentIsStillListedAsDownloading() throws {
        try makeItemFolder(origin: nil, files: [".origin.json.icloud": ""])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.state, .downloading)
        XCTAssertFalse(item.displayName.hasSuffix(".icloud"))
        XCTAssertFalse(item.displayName.hasPrefix("."))
    }

    func testPayloadStillDownloadingWhileOriginIsReadable() throws {
        try makeItemFolder(origin: originJSON(path: "Folder/Note.md"), files: [".Note.md.icloud": ""])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.state, .downloading)
        XCTAssertEqual(item.displayName, "Note.md")
        XCTAssertEqual(item.originalPath, "Folder/Note.md")
        XCTAssertEqual(item.payloadName, "Note.md")
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root))
    }

    func testOriginJSONAbsentAndFolderCurrentIsRestorableToTheRoot() throws {
        try makeItemFolder(origin: nil, files: ["Note.md": "n"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.state, .ready)
        XCTAssertTrue(item.isRestorable)
        XCTAssertFalse(item.originKnown)
    }

    func testOriginJSONPresentAndPayloadAbsentIsNotListedAndNotDeleted() throws {
        let id = try makeItemFolder(origin: originJSON(path: "Note.md"))
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
        XCTAssertEqual(names(".purnote/trash/\(id)"), ["origin.json"], "listing deletes nothing")
        // an assets folder that is there without its note is listed in its own right
        // (it may be an orphan that would otherwise be unreachable); see TrashStoreOrphanTests
        try mkdir(".purnote/trash/\(id)/Note.assets")
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root).map(\.payloadName), ["Note.assets"])
        XCTAssertEqual(names(".purnote/trash/\(id)"), ["Note.assets", "origin.json"], "listing deletes nothing")
    }

    func testAnEmptyItemFolderIsNotListed() throws {
        try makeItemFolder(origin: nil)
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
    }

    func testListIgnoresLooseFilesAndHiddenEntriesInTheTrashFolder() throws {
        try mkdir(".purnote/trash")
        try write(".purnote/trash/.DS_Store", "x")
        try write(".purnote/trash/stray.txt", "x")
        try makeItemFolder(origin: nil, files: ["Note.md": "n"])
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root).count, 1)
    }

    func testListNeverBlocksOnItsOwnStubsAndFinishesQuickly() async throws {
        for _ in 0..<20 { try makeItemFolder(origin: nil, files: [".origin.json.icloud": "", ".N.md.icloud": ""]) }
        let start = Date()
        let items = await TrashStore.list(libraryRoot: root)
        XCTAssertEqual(items.count, 20)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    // MARK: - list

    func testListIsEmptyWhenThereIsNoTrash() async {
        let items = await TrashStore.list(libraryRoot: root)
        XCTAssertEqual(items, [])
        XCTAssertFalse(exists(".purnote"), "listing creates nothing")
    }

    func testListOrderIsNewestFirst() async throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let a = try TrashStore.moveToTrash(try write("A.md"), libraryRoot: root, now: t0)
        let c = try TrashStore.moveToTrash(try write("C.md"), libraryRoot: root, now: t0.addingTimeInterval(20))
        let b = try TrashStore.moveToTrash(try write("B.md"), libraryRoot: root, now: t0.addingTimeInterval(10))
        let items = await TrashStore.list(libraryRoot: root)
        XCTAssertEqual(items.map(\.displayName), ["C.md", "B.md", "A.md"])
        XCTAssertEqual(items, [c, b, a], "a listed item equals the one moveToTrash returned")
    }

    func testListOrdersAnItemWithoutOriginByItsFolderDate() async throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let a = try TrashStore.moveToTrash(try write("A.md"), libraryRoot: root, now: t0)
        try makeItemFolder(id: TrashNaming.makeID(now: t0.addingTimeInterval(50)), origin: nil, files: ["Old.md": "x"])
        let items = await TrashStore.list(libraryRoot: root)
        XCTAssertEqual(items.map(\.displayName), ["Old.md", "A.md"])
        XCTAssertEqual(items.last, a)
    }

    func testListAnIDThatIsNotOurFormatStillListsAndHasADate() throws {
        try makeItemFolder(id: "made-by-hand", origin: nil, files: ["Note.md": "n"])
        let item = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(item.id, "made-by-hand")
        XCTAssertNoThrow(try TrashStore.restore(item, libraryRoot: root))
    }

    // MARK: - delete forever

    func testDeleteForeverRemovesOnlyTheListedItemsAndNotTheTrashFolder() throws {
        let a = try TrashStore.moveToTrash(try write("A.md"), libraryRoot: root)
        let b = try TrashStore.moveToTrash(try writeNoteWithAssets("B"), libraryRoot: root)
        let c = try TrashStore.moveToTrash(try write("C.md"), libraryRoot: root)

        XCTAssertEqual(TrashStore.deleteForever([b], libraryRoot: root).count, 0)
        XCTAssertEqual(itemFolders(), [a.id, c.id].sorted())
        XCTAssertEqual(Set(TrashStore.listNow(libraryRoot: root).map(\.id)), [a.id, c.id])

        XCTAssertEqual(TrashStore.deleteForever([a, c], libraryRoot: root).count, 0)
        XCTAssertEqual(itemFolders(), [])
        XCTAssertTrue(fm.fileExists(atPath: trashDir.path), "the trash folder is never removed")
        XCTAssertTrue(fm.fileExists(atPath: url(".purnote").path))
    }

    func testDeleteForeverToleratesItemsThatAreAlreadyGone() throws {
        let a = try TrashStore.moveToTrash(try write("A.md"), libraryRoot: root)
        let b = try TrashStore.moveToTrash(try write("B.md"), libraryRoot: root)
        try fm.removeItem(at: folder(of: a))   // another device emptied it first
        XCTAssertEqual(TrashStore.deleteForever([a, b], libraryRoot: root).count, 0, "already gone is not a failure")
        XCTAssertEqual(TrashStore.deleteForever([a, b], libraryRoot: root).count, 0, "and neither is a second time")
        XCTAssertEqual(itemFolders(), [])
    }

    func testDeleteForeverWithDuplicateIDsInTheList() throws {
        let a = try TrashStore.moveToTrash(try write("A.md"), libraryRoot: root)
        XCTAssertEqual(TrashStore.deleteForever([a, a], libraryRoot: root).count, 0)
        XCTAssertEqual(itemFolders(), [])
    }

    func testDeleteForeverRemovesPayloadAssetsStubsAndOrigin() throws {
        let id = try makeItemFolder(origin: originJSON(path: "Note.md", assets: "Note.assets"),
                                    files: ["Note.md": "n", "Note.assets/image.jpg": "p", ".Other.md.icloud": ""])
        let item = TrashedItem(id: id, kind: .note, originalPath: "Note.md", originKnown: true, deletedAt: Date(),
                               payloadName: "Note.md", assetsName: "Note.assets", state: .ready)
        XCTAssertEqual(TrashStore.deleteForever([item], libraryRoot: root).count, 0)
        XCTAssertEqual(itemFolders(), [])
    }

    func testDeleteForeverRefusesAnIDThatWouldLeaveTheTrashFolder() throws {
        try mkdir("victim")
        try write("victim/keep.md", "keep")
        let evil = TrashedItem(id: "../../victim", kind: .folder, originalPath: "victim", originKnown: true, deletedAt: Date(),
                               payloadName: "victim", assetsName: nil, state: .ready)
        let dot = TrashedItem(id: "..", kind: .folder, originalPath: "x", originKnown: true, deletedAt: Date(),
                              payloadName: "x", assetsName: nil, state: .ready)
        let failures = TrashStore.deleteForever([evil, dot], libraryRoot: root)
        XCTAssertEqual(failures.count, 2)
        XCTAssertEqual(read("victim/keep.md"), "keep")
        XCTAssertEqual(names(), ["victim"])
    }

    // MARK: - failure paths of moveToTrash

    func testMoveToTrashThrowsWhenTheSourceDoesNotExistAndLeavesNothingBehind() throws {
        XCTAssertThrowsError(try TrashStore.moveToTrash(url("Ghost.md"), libraryRoot: root)) { error in
            guard case TrashError.sourceMissing = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(names(), [], "not even an empty .purnote/trash")
    }

    func testMoveToTrashOfAnICloudPlaceholderThrowsAndTouchesNothing() throws {
        try write(".Remote.md.icloud", "")
        XCTAssertThrowsError(try TrashStore.moveToTrash(url(".Remote.md.icloud"), libraryRoot: root)) { error in
            guard case TrashError.stillInICloud = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try TrashStore.moveToTrash(url("Remote.md"), libraryRoot: root), "the real file is not here either")
        XCTAssertEqual(names(), [".Remote.md.icloud"])
    }

    func testMoveToTrashRefusesWhatIsNotInsideTheLibraryOrIsHidden() throws {
        let outside = root.deletingLastPathComponent().appendingPathComponent("Outside.md")
        try "x".write(to: outside, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try TrashStore.moveToTrash(outside, libraryRoot: root)) { error in
            guard case TrashError.outsideLibrary = error else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(fm.fileExists(atPath: outside.path))
        XCTAssertThrowsError(try TrashStore.moveToTrash(root, libraryRoot: root)) { error in
            guard case TrashError.outsideLibrary = error else { return XCTFail("\(error)") }
        }
        try write(".purnote/pins.json", "{}")
        XCTAssertThrowsError(try TrashStore.moveToTrash(url(".purnote/pins.json"), libraryRoot: root)) { error in
            guard case TrashError.hiddenItem = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try TrashStore.moveToTrash(url(".purnote"), libraryRoot: root))
        XCTAssertEqual(read(".purnote/pins.json"), "{}")
    }

    func testPayloadMoveFailureThrowsAndLeavesNothingBehind() throws {
        let note = try writeNoteWithAssets("Trip")
        let mover = failingMover { _, _ in true }
        XCTAssertThrowsError(try TrashStore.moveToTrash(note, libraryRoot: root, mover: mover))
        XCTAssertEqual(read("Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n")
        XCTAssertEqual(read("Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(itemFolders(), [], "origin.json and the item folder are cleaned up")
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
    }

    func testAssetsMoveFailureRollsTheNoteBack() throws {
        let note = try writeNoteWithAssets("Trip")
        let mover = failingMover { from, _ in from.lastPathComponent == "Trip.assets" }
        XCTAssertThrowsError(try TrashStore.moveToTrash(note, libraryRoot: root, mover: mover)) { error in
            XCTAssertTrue(error is Injected, "the original error is reported: \(error)")
        }
        XCTAssertEqual(read("Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n", "the note is back")
        XCTAssertEqual(read("Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(itemFolders(), [], "nothing is left in the trash")
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
    }

    func testAssetsMoveFailureRollbackNeverRemovesANonEmptyItemFolder() throws {
        let note = try writeNoteWithAssets("Trip")
        // a stranger's file lands in the item folder (another device syncing) while the move is failing
        let mover: TrashStore.Mover = { from, to in
            if from.lastPathComponent == "Trip.assets" {
                try "keep me".write(to: to.deletingLastPathComponent().appendingPathComponent("stray.txt"),
                                    atomically: true, encoding: .utf8)
                throw Injected()
            }
            try CoordinatedFile.move(from: from, to: to)
        }
        XCTAssertThrowsError(try TrashStore.moveToTrash(note, libraryRoot: root, mover: mover))
        XCTAssertEqual(read("Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n")
        let folders = itemFolders()
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(names(".purnote/trash/\(folders[0])"), ["stray.txt"], "origin.json is gone, the folder and the stray file stay")
        XCTAssertEqual(read(".purnote/trash/\(folders[0])/stray.txt"), "keep me")
    }

    func testRollbackFailureKeepsTheItemListedAndRestorable() throws {
        let note = try writeNoteWithAssets("Trip")
        // the assets move fails, and so does moving the note back
        let mover = failingMover { from, to in
            from.lastPathComponent == "Trip.assets" || to.standardizedFileURL.path == note.standardizedFileURL.path
        }
        var thrown: TrashedItem?
        XCTAssertThrowsError(try TrashStore.moveToTrash(note, libraryRoot: root, mover: mover)) { error in
            guard case TrashError.rollbackFailed(let item, _) = error else { return XCTFail("\(error)") }
            thrown = item
        }
        let item = try XCTUnwrap(thrown)
        XCTAssertFalse(exists("Trip.md"))
        XCTAssertEqual(read("Trip.assets/image.jpg"), "PHOTO", "the assets never moved")
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["Trip.md", "origin.json"])
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [item], "still listed")
        // and it can be restored. The name must be free for Trip.md AND Trip.assets, and Trip.assets is
        // still there (it never moved), so the note comes back as "Trip 2.md" and the folder is untouched
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Trip 2.md")), restored.path)
        XCTAssertEqual(read("Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(read("Trip 2.md"), "Trip\n![](<Trip.assets/image.jpg>)\n", "its references still lead to the pictures that are there")
    }

    // MARK: - failure paths of restore

    func testRestoreAssetsMoveFailureMovesTheNoteBackIntoTheTrash() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip"), libraryRoot: root)
        let mover = failingMover { from, _ in from.lastPathComponent == "Trip.assets" }
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root, mover: mover)) { error in
            XCTAssertTrue(error is Injected, "\(error)")
        }
        XCTAssertEqual(names(), [".purnote"], "nothing half-restored in the library")
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["Trip.assets", "Trip.md", "origin.json"])
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [item], "still listed, still restorable")
        XCTAssertNoThrow(try TrashStore.restore(item, libraryRoot: root))
        XCTAssertEqual(read("Trip.assets/image.jpg"), "PHOTO")
    }

    func testRestoreRollbackFailureReportsAPartialRestoreAndKeepsOriginJSON() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip"), libraryRoot: root)
        let mover = failingMover { from, to in
            from.lastPathComponent == "Trip.assets" || to.path.contains("/.purnote/trash/")
        }
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root, mover: mover)) { error in
            guard case TrashError.partialRestore(let restored, _) = error else { return XCTFail("\(error)") }
            XCTAssertTrue(same(restored, url("Trip.md")))
            XCTAssertTrue(restored.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
        }
        XCTAssertEqual(read("Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n", "the note that did move is intact")
        XCTAssertTrue(exists(".purnote/trash/\(item.id)/origin.json"), "origin.json stays while anything is unresolved")
        XCTAssertTrue(exists(".purnote/trash/\(item.id)/Trip.assets/image.jpg"), "the assets were not lost")
    }

    func testCleanupAfterRestoreNeverRemovesANonEmptyItemFolder() throws {
        let item = try TrashStore.moveToTrash(try write("A.md", "a"), libraryRoot: root)
        try write(".purnote/trash/\(item.id)/stray.txt", "keep me")
        _ = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["stray.txt"], "origin.json is gone, the rest stays")
        XCTAssertEqual(read(".purnote/trash/\(item.id)/stray.txt"), "keep me")
        let left = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(left.displayName, "stray.txt", "it is left listed, not hidden")
    }

    func testRestoreOfAnItemWhosePayloadIsGoneThrowsItemGone() throws {
        let item = try TrashStore.moveToTrash(try write("A.md", "a"), libraryRoot: root)
        try fm.removeItem(at: folder(of: item).appendingPathComponent("A.md"))
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root)) { error in
            guard case TrashError.itemGone = error else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(exists(".purnote/trash/\(item.id)/origin.json"), "nothing is deleted")
    }

    // MARK: - batches

    func testMultiItemBatchReturnsOneTrashedItemEach() throws {
        try write("Folder/D.md", "d")
        let urls = [try write("A.md"), try writeNoteWithAssets("B"), try write("Sub/C.md"), url("Folder")]
        let batch = TrashStore.moveToTrash(urls, libraryRoot: root)
        XCTAssertEqual(batch.items.count, 4)
        XCTAssertEqual(batch.failures.count, 0)
        XCTAssertEqual(Set(batch.items.map(\.id)).count, 4, "distinct ids")
        XCTAssertEqual(batch.items.map(\.displayName), ["A.md", "B.md", "C.md", "Folder"], "in the order given")
        XCTAssertEqual(batch.items.map(\.kind), [.note, .note, .note, .folder])
        XCTAssertEqual(batch.items[1].assetsName, "B.assets")
        XCTAssertEqual(Set(TrashStore.listNow(libraryRoot: root).map(\.id)), Set(batch.items.map(\.id)))
    }

    func testBatchWithOneMissingFileTrashesTheOthersAndReportsTheFailure() throws {
        let a = try write("A.md"), c = try write("C.md")
        let batch = TrashStore.moveToTrash([a, url("Ghost.md"), c], libraryRoot: root)
        XCTAssertEqual(batch.items.map(\.displayName), ["A.md", "C.md"])
        XCTAssertEqual(batch.failures.count, 1)
        XCTAssertEqual(batch.failures.first?.url.lastPathComponent, "Ghost.md")
        XCTAssertFalse(exists("A.md")); XCTAssertFalse(exists("C.md"))
        // every one can be undone
        for item in batch.items { XCTAssertNoThrow(try TrashStore.restore(item, libraryRoot: root)) }
        XCTAssertEqual(names(), [".purnote", "A.md", "C.md"])
    }

    func testTenNotesInABatchAllComeBack() throws {
        let urls = try (1...10).map { try write("Note \($0).md", "n\($0)") }
        let batch = TrashStore.moveToTrash(urls, libraryRoot: root)
        XCTAssertEqual(batch.items.count, 10)
        XCTAssertEqual(batch.failures.count, 0)
        for item in batch.items { _ = try TrashStore.restore(item, libraryRoot: root) }
        for n in 1...10 { XCTAssertEqual(read("Note \(n).md"), "n\(n)") }
        XCTAssertEqual(itemFolders(), [])
    }

    // MARK: - library root vs subfolder

    func testThePathIsRelativeToTheLibraryRootNotTheFolderTheNoteIsIn() throws {
        let item = try TrashStore.moveToTrash(try write("Sub/Deep/N.md"), libraryRoot: root)
        XCTAssertEqual(item.originalPath, "Sub/Deep/N.md")
        XCTAssertEqual(item.originalFolder, "Sub/Deep")
        let atRoot = try TrashStore.moveToTrash(try write("R.md"), libraryRoot: root)
        XCTAssertEqual(atRoot.originalPath, "R.md")
        XCTAssertEqual(atRoot.originalFolder, "")
        XCTAssertTrue(same(try TrashStore.restore(item, libraryRoot: root), url("Sub/Deep/N.md")))
    }

    func testALibraryRootGivenWithATrailingSlashOrDotsStillWorks() throws {
        let odd = URL(fileURLWithPath: root.path + "/Sub/..", isDirectory: true)
        let item = try TrashStore.moveToTrash(try write("Sub/N.md"), libraryRoot: odd)
        XCTAssertEqual(item.originalPath, "Sub/N.md")
        XCTAssertTrue(same(try TrashStore.restore(item, libraryRoot: odd), url("Sub/N.md")))
    }
}


/// Review round: attachments folders that lose their note, the free-name rule for
/// X.assets, and a few guards.
final class TrashStoreOrphanTests: TrashFixtureCase {

    // MARK: - orphan attachments folders (four routes)

    /// Route 1: the note was restored alone (its pictures had not synced yet); the pictures arrive afterwards.
    func testPicturesThatArriveAfterTheNoteWasRestoredAreListedAndRestorable() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip", in: "Travel"), libraryRoot: root)
        let held = trashDir.appendingPathComponent("\(item.id)/Trip.assets")
        let aside = root.deletingLastPathComponent().appendingPathComponent("aside-Trip.assets")
        try fm.moveItem(at: held, to: aside)                   // "not synced yet"
        _ = try TrashStore.restore(item, libraryRoot: root)    // the note alone goes back
        XCTAssertEqual(itemFolders(), [])
        try fm.createDirectory(at: folder(of: item), withIntermediateDirectories: true)
        try fm.moveItem(at: aside, to: held)                   // the pictures arrive, no origin.json with them

        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(listed.id, item.id)
        XCTAssertEqual(listed.payloadName, "Trip.assets")
        XCTAssertEqual(listed.displayName, "Trip.assets")
        XCTAssertFalse(listed.originKnown)
        XCTAssertEqual(listed.state, .ready)
        let restored = try TrashStore.restore(listed, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Trip.assets")), "an unknown origin goes to the library root: \(restored.path)")
        XCTAssertEqual(read("Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(itemFolders(), [])
    }

    /// Route 2: a restore that stopped between the two moves (partialRestore).
    func testPicturesLeftBehindByAPartialRestoreAreListedWithTheirOriginAndRestorable() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("Trip", in: "Travel"), libraryRoot: root)
        let mover = failingMover { from, to in
            from.lastPathComponent == "Trip.assets" || to.path.contains("/.purnote/trash/")
        }
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root, mover: mover))
        XCTAssertTrue(exists("Travel/Trip.md"))

        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(listed.kind, .folder)
        XCTAssertEqual(listed.payloadName, "Trip.assets")
        XCTAssertEqual(listed.originalPath, "Travel/Trip.assets")
        XCTAssertTrue(listed.originKnown)
        XCTAssertEqual(listed.state, .ready)
        let restored = try TrashStore.restore(listed, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Travel/Trip.assets")), restored.path)
        XCTAssertEqual(read("Travel/Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(read("Travel/Trip.md"), "Trip\n![](<Trip.assets/image.jpg>)\n", "note and pictures are together again")
        XCTAssertEqual(itemFolders(), [])
    }

    /// Route 3: a crash between the two moves leaves origin.json and the pictures, the note already out.
    func testOriginJSONWithOnlyThePicturesLeftIsListed() throws {
        let id = try makeItemFolder(origin: originJSON(path: "Folder/Trip.md", assets: "Trip.assets"),
                                    files: ["Trip.assets/image.jpg": "PHOTO"])
        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(listed.id, id)
        XCTAssertEqual(listed.originalPath, "Folder/Trip.assets")
        XCTAssertEqual(listed.kind, .folder)
        XCTAssertTrue(listed.isRestorable)
        XCTAssertEqual(names(".purnote/trash/\(id)"), ["Trip.assets", "origin.json"], "listing deletes nothing")
    }

    /// Route 4: the recorded note is gone, another file stands in for it (rule 6), and the recorded
    /// assets folder has a different stem; it must not be dropped.
    func testFallbackNoteKeepsTheRecordedAssetsFolder() throws {
        try makeItemFolder(origin: originJSON(path: "Folder/Trip.md", assets: "Trip.assets"),
                           files: ["Renamed.md": "Renamed\n![](<Trip.assets/image.jpg>)", "Trip.assets/image.jpg": "PHOTO"])
        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(listed.payloadName, "Renamed.md")
        XCTAssertEqual(listed.assetsName, "Trip.assets", "the recorded name is used though the stems differ")
        let restored = try TrashStore.restore(listed, libraryRoot: root)
        XCTAssertTrue(same(restored, url("Folder/Renamed.md")))
        XCTAssertEqual(read("Folder/Trip.assets/image.jpg"), "PHOTO")
        XCTAssertEqual(read("Folder/Renamed.md"), "Renamed\n![](<Trip.assets/image.jpg>)")
        XCTAssertEqual(itemFolders(), [], "nothing was left behind")
    }

    func testFallbackNoteWithRecordedAssetsRewritesReferencesWhenTheNameIsTaken() throws {
        try makeItemFolder(origin: originJSON(path: "Trip.md", assets: "Trip.assets"),
                           files: ["Renamed.md": "R\n![](<Trip.assets/image.jpg>)", "Trip.assets/image.jpg": "MINE"])
        try write("Renamed.md", "other")
        try write("Trip.assets/image.jpg", "OTHER")
        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        let restored = try TrashStore.restore(listed, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "Renamed 2.md")
        XCTAssertEqual(read("Trip.assets/image.jpg"), "OTHER")
        XCTAssertEqual(read("Renamed 2.assets/image.jpg"), "MINE")
        XCTAssertEqual(read("Renamed 2.md"), "R\n![](<Renamed 2.assets/image.jpg>)")
    }

    func testOrphanPicturesRestoreUnderAFreeNameWhenTheirNameIsTaken() throws {
        try makeItemFolder(origin: nil, files: ["Trip.assets/image.jpg": "MINE"])
        try write("trip.assets/image.jpg", "OTHER")
        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        let restored = try TrashStore.restore(listed, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "Trip 2.assets")
        XCTAssertEqual(read("trip.assets/image.jpg"), "OTHER")
        XCTAssertEqual(read("Trip 2.assets/image.jpg"), "MINE")
    }

    func testOrphanPicturesCanBeDeletedForever() throws {
        let id = try makeItemFolder(origin: nil, files: ["Trip.assets/image.jpg": "p"])
        let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
        XCTAssertEqual(TrashStore.deleteForever([listed], libraryRoot: root).count, 0)
        XCTAssertFalse(exists(".purnote/trash/\(id)"))
    }

    func testSeveralPicturesFoldersWithNoNoteAreListedOneAfterTheOther() throws {
        try makeItemFolder(origin: nil, files: ["A.assets/a.jpg": "a", "B.assets/b.jpg": "b"])
        var seen: [String] = []
        for _ in 0..<2 {
            let listed = try XCTUnwrap(TrashStore.listNow(libraryRoot: root).first)
            seen.append(listed.payloadName)
            _ = try TrashStore.restore(listed, libraryRoot: root)
        }
        XCTAssertEqual(seen, ["A.assets", "B.assets"])
        XCTAssertEqual(read("A.assets/a.jpg"), "a"); XCTAssertEqual(read("B.assets/b.jpg"), "b")
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
        XCTAssertEqual(itemFolders(), [])
    }

    // MARK: - X.assets must be free even for a note without pictures

    func testNoteWithoutPicturesAvoidsAnOrphanAssetsFolderOfThatName() throws {
        let item = try TrashStore.moveToTrash(try write("X.md", "plain"), libraryRoot: root)
        try write("X.assets/image.jpg", "ANOTHER NOTE'S PHOTO")      // an orphan: no X.md beside it
        let restored = try TrashStore.restore(item, libraryRoot: root)
        XCTAssertEqual(restored.lastPathComponent, "X 2.md")
        XCTAssertEqual(read("X.assets/image.jpg"), "ANOTHER NOTE'S PHOTO")
        XCTAssertFalse(exists("X.md"))
    }

    func testNoteWithoutPicturesAvoidsALowercaseOrphanAssetsFolder() throws {
        let item = try TrashStore.moveToTrash(try write("X.md", "plain"), libraryRoot: root)
        try write("x.assets/image.jpg", "p")
        XCTAssertEqual(try TrashStore.restore(item, libraryRoot: root).lastPathComponent, "X 2.md")
    }

    // MARK: - guards

    func testExplicitIDWhoseFolderExistsFailsWithoutTouchingTheExistingItem() throws {
        let id = "20260101120000-TAKEN"
        try makeItemFolder(id: id, origin: originJSON(path: "Old.md"), files: ["Old.md": "old content"])
        let note = try write("New.md", "new")
        XCTAssertThrowsError(try TrashStore.moveToTrash(note, libraryRoot: root, id: id))
        XCTAssertEqual(read("New.md"), "new", "the note did not move")
        XCTAssertEqual(names(".purnote/trash/\(id)"), ["Old.md", "origin.json"])
        XCTAssertEqual(read(".purnote/trash/\(id)/Old.md"), "old content")
        XCTAssertEqual(read(".purnote/trash/\(id)/origin.json"), originJSON(path: "Old.md"), "origin.json was not replaced")
    }

    func testPartialRestoreNamesAPartThatExists() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("X", image: "MINE"), libraryRoot: root)
        try write("X.md", "taken")                                    // forces a rename, so the text is rewritten
        // the rewrite cannot be saved, the pictures cannot go back into the trash, the note can
        let mover = failingMover { from, to in from.lastPathComponent == "X 2.assets" && to.path.contains("/.purnote/trash/") }
        let writer: TrashStore.Writer = { _, _ in throw Injected() }
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root, mover: mover, writer: writer)) { error in
            guard case TrashError.partialRestore(let restored, _) = error else { return XCTFail("\(error)") }
            let part = try? XCTUnwrap(restored, "something that moved is still in the library")
            XCTAssertTrue(part.map { FileManager.default.fileExists(atPath: $0.path) } ?? false, "\(String(describing: restored))")
            XCTAssertTrue(same(part, url("X 2.assets")))
        }
        XCTAssertEqual(read("X.md"), "taken")
        XCTAssertEqual(read("X 2.assets/image.jpg"), "MINE")
        XCTAssertTrue(exists(".purnote/trash/\(item.id)/X.md"), "the note went back")
        XCTAssertTrue(exists(".purnote/trash/\(item.id)/origin.json"))
    }

    func testFailedRewriteWithEverythingUndoneIsAPlainError() throws {
        let item = try TrashStore.moveToTrash(try writeNoteWithAssets("X"), libraryRoot: root)
        try write("X.md", "taken")
        let writer: TrashStore.Writer = { _, _ in throw Injected() }
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root, writer: writer)) { error in
            XCTAssertTrue(error is Injected, "\(error)")
        }
        XCTAssertEqual(names(), [".purnote", "X.md"])
        XCTAssertEqual(names(".purnote/trash/\(item.id)"), ["X.assets", "X.md", "origin.json"])
    }

    func testDeleteForeverRefusesAnItemFolderThatIsASymlink() throws {
        try write("victim/keep.md", "keep")
        try mkdir(".purnote/trash")
        let id = "20260101120000-LINK"
        try fm.createSymbolicLink(at: trashDir.appendingPathComponent(id), withDestinationURL: url("victim"))
        let item = TrashedItem(id: id, kind: .folder, originalPath: "victim", originKnown: false, deletedAt: Date(),
                               payloadName: "victim", assetsName: nil, state: .ready)
        XCTAssertEqual(TrashStore.deleteForever([item], libraryRoot: root).count, 1)
        XCTAssertEqual(read("victim/keep.md"), "keep")
        XCTAssertNotNil(try? fm.destinationOfSymbolicLink(atPath: trashDir.appendingPathComponent(id).path), "the link is left alone")
    }

    func testListAndRestoreDoNotFollowAnItemFolderThatIsASymlink() throws {
        try write("victim/Note.md", "keep")
        try mkdir(".purnote/trash")
        let id = "20260101120000-LINK"
        try fm.createSymbolicLink(at: trashDir.appendingPathComponent(id), withDestinationURL: url("victim"))
        XCTAssertEqual(TrashStore.listNow(libraryRoot: root), [])
        let item = TrashedItem(id: id, kind: .note, originalPath: "Note.md", originKnown: false, deletedAt: Date(),
                               payloadName: "Note.md", assetsName: nil, state: .ready)
        XCTAssertThrowsError(try TrashStore.restore(item, libraryRoot: root))
        XCTAssertEqual(read("victim/Note.md"), "keep")
    }
}
