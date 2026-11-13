@testable import Purnote
import XCTest

/// Where the notes are, in words: which place name goes with which storage, and
/// the version line. Pure text, so these only check what can be wrong: the
/// iCloud and on-device cases must never swap, and the folder alerts must name
/// the place the notes really are.
final class NotesLocationTests: XCTestCase {

    private let icloud = NotesLocation(kind: .iCloud)
    private let phone = NotesLocation(kind: .device, deviceName: "iPhone")
    private let pad = NotesLocation(kind: .device, deviceName: "iPad")

    // MARK: which storage

    func testLocalStorageChoiceMeansOnDevice() {
        XCTAssertEqual(NotesLocation.current(useLocalStorage: true, isUITestFixture: false, deviceName: "iPhone").kind, .device)
    }

    func testNoLocalChoiceMeansICloud() {
        XCTAssertEqual(NotesLocation.current(useLocalStorage: false, isUITestFixture: false, deviceName: "iPhone").kind, .iCloud)
    }

    func testUITestFixtureIsAlwaysOnDevice() {
        // the app uses local storage for the fixture whatever the setting says
        XCTAssertEqual(NotesLocation.current(useLocalStorage: false, isUITestFixture: true, deviceName: "iPhone").kind, .device)
    }

    // MARK: the folder alerts (the known copy bug)

    func testNewFolderAlertNamesICloudWhenOnICloud() {
        XCTAssertEqual(icloud.newFolderMessage, "A real folder, in iCloud Drive › purnote.")
    }

    func testNewFolderAlertDoesNotSayICloudWhenOnDevice() {
        XCTAssertEqual(phone.newFolderMessage, "A real folder, in On My iPhone › Purnote.")
        XCTAssertFalse(phone.newFolderMessage.contains("iCloud"))
    }

    func testRenameAlertDoesNotSayICloudWhenOnDevice() {
        XCTAssertEqual(phone.renameMessage, "The folder is renamed in On My iPhone › Purnote.")
        XCTAssertEqual(icloud.renameMessage, "The folder is renamed in iCloud Drive › purnote.")
    }

    func testOnAnIPadTheDeviceIsNamedAsSuch() {
        XCTAssertEqual(pad.path, "On My iPad › Purnote")
        XCTAssertEqual(pad.shortName, "On this iPad")
        XCTAssertFalse(pad.detail.contains("iPhone"))
        XCTAssertFalse(pad.privacyDestination.contains("iPhone"))
    }

    func testOnlyICloudPromisesSync() {
        XCTAssertTrue(icloud.detail.contains("Synced"))
        XCTAssertFalse(phone.detail.contains("Synced"))
        XCTAssertFalse(phone.privacyDestination.contains("iCloud"))
    }

    // The words say "purnote" because that is what the app declares to iCloud. If
    // the declaration changes, the words have to follow it.
    func testICloudFolderNameMatchesTheDeclaredContainerName() throws {
        let bundle = Bundle(for: iCloudMonitor.self)
        let containers = try XCTUnwrap(bundle.infoDictionary?["NSUbiquitousContainers"] as? [String: [String: Any]])
        let names = containers.values.compactMap { $0["NSUbiquitousContainerName"] as? String }
        XCTAssertEqual(names, [NotesLocation.iCloudFolderName])
    }

    // MARK: version line

    func testVersionWithBuild() {
        XCTAssertEqual(AppVersion.text(short: "1.5", build: "210"), "Version 1.5 (210)")
    }

    func testVersionWithoutBuild() {
        XCTAssertEqual(AppVersion.text(short: "1.5", build: nil), "Version 1.5")
        XCTAssertEqual(AppVersion.text(short: "1.5", build: "  "), "Version 1.5")
    }

    func testVersionMissingDoesNotPrintAnEmptyNumber() {
        XCTAssertEqual(AppVersion.text(short: nil, build: "210"), "Version unknown")
        XCTAssertEqual(AppVersion.text(short: "", build: "210"), "Version unknown")
    }
}
