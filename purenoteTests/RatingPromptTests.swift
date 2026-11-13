@testable import Purnote
import XCTest

/// When the app asks for a rating: at the 8th, 40th and 120th success, at most
/// once per app version, with the counts kept in UserDefaults.
final class RatingPromptTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RatingPromptTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func prompt() -> RatingPrompt { RatingPrompt(defaults: defaults) }

    private func succeed(_ times: Int) {
        let p = prompt()
        for _ in 0..<times { p.recordSuccess() }
    }

    func testCountIsKeptAcrossInstances() {
        succeed(3)
        XCTAssertEqual(prompt().successCount, 3)
        succeed(2)
        XCTAssertEqual(RatingPrompt(defaults: defaults).successCount, 5)
    }

    func testNoAskBeforeTheEighthSuccess() {
        succeed(7)
        XCTAssertFalse(prompt().shouldAsk(version: "1.5"))
        XCTAssertFalse(prompt().takeAsk(version: "1.5"))
    }

    func testAsksAtTheEighthSuccessAndThenNotAgainInThatVersion() {
        succeed(8)
        XCTAssertTrue(prompt().takeAsk(version: "1.5"))
        XCTAssertFalse(prompt().takeAsk(version: "1.5"))
        succeed(1)
        XCTAssertFalse(prompt().takeAsk(version: "1.5"))
        // a newer version does not ask either: 9 is not a threshold
        XCTAssertFalse(prompt().takeAsk(version: "1.6"))
    }

    func testAsksAtFortyAndOneTwentyInLaterVersions() {
        succeed(8)
        XCTAssertTrue(prompt().takeAsk(version: "1.5"))
        succeed(32)
        XCTAssertFalse(prompt().takeAsk(version: "1.5"), "40 reached, but 1.5 has asked")
        XCTAssertTrue(prompt().takeAsk(version: "1.6"))
        succeed(80)
        XCTAssertTrue(prompt().takeAsk(version: "1.7"))
        succeed(500)
        XCTAssertFalse(prompt().takeAsk(version: "1.8"), "nothing is asked after 120")
    }

    func testAThresholdReachedInABlockedVersionIsDueInTheNextOne() {
        succeed(8)
        XCTAssertTrue(prompt().takeAsk(version: "1.5"))
        succeed(32)
        XCTAssertFalse(prompt().shouldAsk(version: "1.5"))
        XCTAssertTrue(prompt().shouldAsk(version: "1.6"))
    }

    func testShouldAskDoesNotUseUpTheAsk() {
        succeed(8)
        XCTAssertTrue(prompt().shouldAsk(version: "1.5"))
        XCTAssertTrue(prompt().shouldAsk(version: "1.5"))
        XCTAssertTrue(prompt().takeAsk(version: "1.5"))
    }

    func testAskedStateSurvivesANewInstance() {
        succeed(8)
        XCTAssertTrue(RatingPrompt(defaults: defaults).takeAsk(version: "1.5"))
        XCTAssertFalse(RatingPrompt(defaults: defaults).shouldAsk(version: "1.5"))
    }

    func testCountPastSeveralThresholdsAsksOnceNotOncePerThreshold() {
        succeed(130)
        XCTAssertTrue(prompt().takeAsk(version: "1.5"))
        XCTAssertFalse(prompt().takeAsk(version: "1.6"))
    }
}
