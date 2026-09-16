import XCTest
@testable import Purnote

/// The URL arithmetic around `.icloud` placeholders, and the download wait
/// that replaced the old main-thread busy loop.
final class ICloudPlaceholderTests: XCTestCase {

    func testDownloadedURLStripsLeadingDotAndSuffix() {
        let placeholder = URL(fileURLWithPath: "/notes/.shopping.md.icloud")
        XCTAssertEqual(
            ICloudPlaceholder.downloadedURL(for: placeholder),
            URL(fileURLWithPath: "/notes/shopping.md")
        )
    }

    func testDownloadedURLWithoutLeadingDot() {
        let placeholder = URL(fileURLWithPath: "/notes/shopping.md.icloud")
        XCTAssertEqual(
            ICloudPlaceholder.downloadedURL(for: placeholder),
            URL(fileURLWithPath: "/notes/shopping.md")
        )
    }

    func testDownloadedURLForOrdinaryFileIsUnchanged() {
        let url = URL(fileURLWithPath: "/notes/shopping.md")
        XCTAssertEqual(ICloudPlaceholder.downloadedURL(for: url), url)
    }

    func testWaitForDownloadReturnsImmediatelyWhenFileExists() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }

        try? "hello".write(to: url, atomically: true, encoding: .utf8)
        let start = Date()
        await ICloudPlaceholder.waitForDownload(at: url, timeout: .seconds(2))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }

    func testWaitForDownloadGivesUpAfterTimeout() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("purnote-\(UUID().uuidString).md")
        let start = Date()
        await ICloudPlaceholder.waitForDownload(at: url,
                                                timeout: .milliseconds(300),
                                                pollingEvery: .milliseconds(50))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.25)
    }
}
