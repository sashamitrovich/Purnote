import XCTest

/// About Purnote, driven through the real app: the "..." menu opens it, it shows
/// the running version and says where the notes are. The fixture library is on
/// the device (local storage), so the location must not say iCloud.
final class AboutUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestFixture", "-useLocalStorage", "YES", "-shownSplashScreen", "YES"]
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func openAbout() {
        app.launch()
        let more = app.buttons["menu.more"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 20), "no \"...\" menu on the home screen")
        more.tap()
        let about = app.buttons["menu.about"].firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 5), "no About Purnote entry in the menu")
        XCTAssertEqual(about.label, "About Purnote")
        XCTAssertFalse(app.buttons["menu.help"].firstMatch.exists, "the old Help entry is still in the menu")
        about.tap()
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testMenuOpensAboutWithVersionAndLocation() throws {
        openAbout()

        let version = element("about.version")
        XCTAssertTrue(version.waitForExistence(timeout: 10), "the About screen did not open")
        XCTAssertTrue(version.label.hasPrefix("Version "), "version line reads: \(version.label)")
        XCTAssertNotEqual(version.label, "Version unknown", "the bundle has no version")

        let location = element("about.location")
        XCTAssertTrue(location.exists, "no location line")
        XCTAssertEqual(location.label, "On My iPhone › Purnote", "the fixture is on the device, not iCloud")
        attach("about-light")
    }

}
