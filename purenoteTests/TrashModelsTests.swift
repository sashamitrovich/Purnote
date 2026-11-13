//
//  TrashModelsTests.swift
//  purenoteTests
//
//  The pure rules of the trash: which recorded paths are believed, how item
//  folders are named, how a free name is picked, how attachment references are
//  rewritten, and the shape of origin.json.
//

@testable import Purnote
import XCTest

final class TrashModelsTests: XCTestCase {

    // MARK: recorded paths

    func testComponentsOfAPlainRelativePath() {
        XCTAssertEqual(TrashPath.components(ofRelativePath: "Note.md"), ["Note.md"])
        XCTAssertEqual(TrashPath.components(ofRelativePath: "Folder/Sub/Note.md"), ["Folder", "Sub", "Note.md"])
        XCTAssertEqual(TrashPath.components(ofRelativePath: "Ünïcode Ordner/日本語.md"), ["Ünïcode Ordner", "日本語.md"])
    }

    func testComponentsRejectAnythingThatCouldLeaveTheLibraryOrHitInternals() {
        let bad = ["", "/", "/etc/passwd", "/Note.md", "../Note.md", "Folder/../../Note.md", "..",
                   "Folder/..", "./Note.md", "Folder//Note.md", "Folder/", ".purnote/pins.json",
                   "Folder/.hidden.md", ".Trash/x.md", "a\u{0}b.md", "Folder/./x.md"]
        for path in bad {
            XCTAssertNil(TrashPath.components(ofRelativePath: path), "should not be believed: \(path.debugDescription)")
        }
    }

    func testSafeNames() {
        XCTAssertTrue(TrashPath.isSafeName("Note.md"))
        XCTAssertTrue(TrashPath.isSafeName("Trip 2.assets"))
        for bad in ["", ".", "..", "a/b", "../x", "/abs", ".hidden"] {
            XCTAssertFalse(TrashPath.isSafeName(bad), "\(bad.debugDescription)")
        }
    }

    func testRelativePathAgainstTheLibraryRoot() {
        let root = URL(fileURLWithPath: "/Users/x/Library/Notes")
        XCTAssertEqual(TrashPath.relativePath(of: root.appendingPathComponent("A.md"), in: root), "A.md")
        XCTAssertEqual(TrashPath.relativePath(of: root.appendingPathComponent("F/S/A.md"), in: root), "F/S/A.md")
        XCTAssertNil(TrashPath.relativePath(of: root, in: root), "the root itself is not inside the root")
        XCTAssertNil(TrashPath.relativePath(of: URL(fileURLWithPath: "/Users/x/Library/Notes2/A.md"), in: root),
                     "a sibling whose name starts the same is not inside")
        XCTAssertNil(TrashPath.relativePath(of: URL(fileURLWithPath: "/Users/x/Other/A.md"), in: root))
        XCTAssertEqual(TrashPath.relativePath(of: URL(fileURLWithPath: "/private/Users/x/Library/Notes/A.md"), in: root), "A.md",
                       "the /private prefix does not matter")
    }

    func testResolveStaysInsideTheRoot() {
        let root = URL(fileURLWithPath: "/Users/x/Library/Notes")
        XCTAssertEqual(TrashPath.resolve("F/A.md", in: root)?.path, "/Users/x/Library/Notes/F/A.md")
        XCTAssertNil(TrashPath.resolve("../A.md", in: root))
        XCTAssertNil(TrashPath.resolve("/A.md", in: root))
    }

    // MARK: item folder names

    func testItemFolderNameHasUTCDateThenUUID() {
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let id = TrashNaming.makeID(now: Date(timeIntervalSince1970: 1_700_000_000), uuid: uuid)
        XCTAssertEqual(id, "20231114221320-11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(TrashNaming.date(fromID: id), Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testTwoIDsAtTheSameInstantDiffer() {
        let now = Date()
        XCTAssertNotEqual(TrashNaming.makeID(now: now), TrashNaming.makeID(now: now))
    }

    func testSafeIDs() {
        XCTAssertTrue(TrashNaming.isSafeID("20231114221320-11111111-2222-3333-4444-555555555555"))
        XCTAssertTrue(TrashNaming.isSafeID("something-a-person-made"), "any plain folder name is addressable")
        for bad in ["", ".", "..", "a/b", "../victim", ".hidden", "/abs"] {
            XCTAssertFalse(TrashNaming.isSafeID(bad), "\(bad.debugDescription)")
        }
        XCTAssertNil(TrashNaming.date(fromID: "something-a-person-made"))
    }

    func testISODateRoundTripToTheSecond() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(TrashNaming.isoDate(TrashNaming.isoString(d)), d)
        XCTAssertEqual(TrashNaming.isoString(d), "2023-11-14T22:13:20Z")
        XCTAssertNil(TrashNaming.isoDate("yesterday"))
    }

    // MARK: free names

    private func noteNames(_ stem: String) -> [String] { [stem + ".md", stem + ".assets"] }

    func testFreeStemKeepsTheNameWhenFree() {
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: [], names: noteNames), "Trip")
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: [TrashNaming.fold("Other.md")], names: noteNames), "Trip")
    }

    func testFreeStemTakenByNoteOrByAssetsOrByBoth() {
        let md = TrashNaming.fold("Trip.md"), assets = TrashNaming.fold("Trip.assets")
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: [md], names: noteNames), "Trip 2")
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: [assets], names: noteNames), "Trip 2")
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: [md, assets], names: noteNames), "Trip 2")
    }

    func testFreeStemSkipsTakenNumbersOnEitherSide() {
        let taken: Set<String> = ["trip.md", "trip 2.md", "trip 3.assets"].map(TrashNaming.fold).reduce(into: []) { $0.insert($1) }
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: taken, names: noteNames), "Trip 4")
    }

    func testFreeStemIsCaseInsensitive() {
        XCTAssertEqual(TrashNaming.freeStem("Trip", taken: [TrashNaming.fold("trip.MD")], names: noteNames), "Trip 2")
        XCTAssertEqual(TrashNaming.fold("TRIP"), TrashNaming.fold("trip"))
    }

    func testFoldTreatsComposedAndDecomposedAccentsAsOneName() {
        XCTAssertEqual(TrashNaming.fold("Caf\u{00E9}"), TrashNaming.fold("Cafe\u{0301}"))
    }

    func testFreeStemForAFolderNeedsOnlyTheFolderName() {
        XCTAssertEqual(TrashNaming.freeStem("Travel", taken: [TrashNaming.fold("Travel.md")], names: { [$0] }), "Travel",
                       "a note called Travel.md does not block a folder called Travel")
        XCTAssertEqual(TrashNaming.freeStem("Travel", taken: [TrashNaming.fold("travel")], names: { [$0] }), "Travel 2")
    }

    func testFreeStemFallsBackToAUUIDWhenEverythingIsTaken() {
        var taken: Set<String> = [TrashNaming.fold("A")]
        for n in 2...500 { taken.insert(TrashNaming.fold("A \(n)")) }
        let result = TrashNaming.freeStem("A", taken: taken, names: { [$0] })
        XCTAssertTrue(result.hasPrefix("A "), result)
        XCTAssertFalse(taken.contains(TrashNaming.fold(result)))
    }

    // MARK: reference rewriting

    func testRewriteChangesAReferenceInTheFormTheAppWrites() {
        let text = "Trip\n![](<Trip.assets/image.jpg>)\n"
        XCTAssertEqual(TrashNaming.rewriteAssetReferences(in: text, from: "Trip.assets", to: "Trip 2.assets"),
                       "Trip\n![](<Trip 2.assets/image.jpg>)\n")
    }

    func testRewriteChangesPlainParenthesisQuotedAndDotSlashForms() {
        let text = "![](Trip.assets/a.jpg) <img src=\"Trip.assets/b.jpg\"> <img src='Trip.assets/c.jpg'> ![](./Trip.assets/d.jpg)"
        XCTAssertEqual(TrashNaming.rewriteAssetReferences(in: text, from: "Trip.assets", to: "Trip 2.assets"),
                       "![](Trip 2.assets/a.jpg) <img src=\"Trip 2.assets/b.jpg\"> <img src='Trip 2.assets/c.jpg'> ![](./Trip 2.assets/d.jpg)")
    }

    func testRewriteChangesAPercentEncodedReference() {
        let text = "![](Trip%20Photos.assets/a.jpg)"
        XCTAssertEqual(TrashNaming.rewriteAssetReferences(in: text, from: "Trip Photos.assets", to: "Trip Photos 2.assets"),
                       "![](Trip%20Photos%202.assets/a.jpg)")
    }

    func testRewriteLeavesWordsAndLongerFolderNamesAlone() {
        let text = "Other Trip.assets/z.jpg is just text\nsee MyTrip.assets/k.jpg\n![](<Other Trip.assets/q.jpg>)\nTrip.assets alone"
        XCTAssertEqual(TrashNaming.rewriteAssetReferences(in: text, from: "Trip.assets", to: "Trip 2.assets"), text)
    }

    func testRewriteWithNothingToDoReturnsTheTextUnchanged() {
        XCTAssertEqual(TrashNaming.rewriteAssetReferences(in: "no images", from: "A.assets", to: "B.assets"), "no images")
        XCTAssertEqual(TrashNaming.rewriteAssetReferences(in: "![](<A.assets/x.jpg>)", from: "A.assets", to: "A.assets"),
                       "![](<A.assets/x.jpg>)")
    }

    // MARK: origin.json

    func testOriginIsVersionOneReadableJSON() throws {
        let origin = TrashOrigin(path: "Folder/Note.md", kind: .note,
                                 deletedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                 payloadName: "Note.md", assetsName: "Note.assets")
        let text = String(decoding: try origin.encoded(), as: UTF8.self)
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, 1)
        XCTAssertEqual(object?["path"] as? String, "Folder/Note.md")
        XCTAssertEqual(object?["kind"] as? String, "note")
        XCTAssertEqual(object?["deletedAt"] as? String, "2023-11-14T22:13:20Z")
        XCTAssertEqual(object?["payloadName"] as? String, "Note.md")
        XCTAssertEqual(object?["assetsName"] as? String, "Note.assets")
        XCTAssertTrue(text.contains("Folder/Note.md"), "slashes are not escaped: \(text)")
        XCTAssertEqual(TrashOrigin.decode(Data(text.utf8)), origin)
        XCTAssertEqual(origin.deletedDate, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testOriginWithoutAssetsOmitsTheKey() throws {
        let origin = TrashOrigin(path: "A.md", kind: .note, deletedAt: Date(), payloadName: "A.md", assetsName: nil)
        let object = try JSONSerialization.jsonObject(with: origin.encoded()) as? [String: Any]
        XCTAssertNil(object?["assetsName"])
        XCTAssertNotNil(TrashOrigin.decode(try origin.encoded()))
    }

    func testOriginDecodeRefusesWhatItDoesNotUnderstand() {
        for text in ["{ not json", "[]", "", "{\"version\":2,\"path\":\"A.md\",\"kind\":\"note\",\"deletedAt\":\"2023-11-14T22:13:20Z\",\"payloadName\":\"A.md\"}",
                     "{\"path\":\"A.md\",\"kind\":\"note\",\"deletedAt\":\"2023-11-14T22:13:20Z\",\"payloadName\":\"A.md\"}",
                     "{\"version\":1,\"path\":\"A.md\",\"kind\":\"banana\",\"deletedAt\":\"2023-11-14T22:13:20Z\",\"payloadName\":\"A.md\"}"] {
            XCTAssertNil(TrashOrigin.decode(Data(text.utf8)), text)
        }
    }

    // MARK: item display

    func testDisplayNameAndFolder() {
        let item = TrashedItem(id: "x", kind: .note, originalPath: "Folder/Sub/Note.md", originKnown: true,
                               deletedAt: Date(), payloadName: "Note.md", assetsName: nil, state: .ready)
        XCTAssertEqual(item.displayName, "Note.md")
        XCTAssertEqual(item.originalFolder, "Folder/Sub")
        let root = TrashedItem(id: "x", kind: .note, originalPath: "Note.md", originKnown: false,
                               deletedAt: Date(), payloadName: "Note.md", assetsName: nil, state: .ready)
        XCTAssertEqual(root.originalFolder, "")
    }
}
