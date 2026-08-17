@testable import Purnote
import XCTest

/// The list-row text derivation: a serif title and a one-line preview with the
/// Markdown syntax stripped out, plus the Notes-style relative date. These pin
/// the "you scan what the note says, not the syntax" behaviour added in 1.1.
final class NoteRowTextTests: XCTestCase {

    // MARK: - title

    func testTitleIsFirstNonEmptyLineWithoutHeadingMarker() {
        XCTAssertEqual(NoteRowText.title(of: "# Reading list\n\nsome body"), "Reading list")
    }

    func testTitleSkipsLeadingBlankLines() {
        XCTAssertEqual(NoteRowText.title(of: "\n\n\n## Morning pages\n"), "Morning pages")
    }

    func testTitleStripsChecklistMarker() {
        XCTAssertEqual(NoteRowText.title(of: "- [x] buy milk"), "buy milk")
    }

    func testEmptyContentHasEmptyTitle() {
        XCTAssertEqual(NoteRowText.title(of: "   \n  \n"), "")
    }

    // MARK: - preview

    func testPreviewIsNextNonEmptyLineAfterTitle() {
        let note = "# Lisbon\n\n- Tram 28 early\n"
        XCTAssertEqual(NoteRowText.preview(of: note), "Tram 28 early")
    }

    func testPreviewEmptyWhenOnlyATitle() {
        XCTAssertEqual(NoteRowText.preview(of: "# Just a title"), "")
    }

    // MARK: - plain (markdown stripping)

    func testStripsEachBlockMarker() {
        XCTAssertEqual(NoteRowText.plain("### Heading"), "Heading")
        XCTAssertEqual(NoteRowText.plain("- bullet"), "bullet")
        XCTAssertEqual(NoteRowText.plain("* star bullet"), "star bullet")
        XCTAssertEqual(NoteRowText.plain("+ plus bullet"), "plus bullet")
        XCTAssertEqual(NoteRowText.plain("> a quote"), "a quote")
        XCTAssertEqual(NoteRowText.plain("- [ ] todo"), "todo")
    }

    func testStripsOrderedListMarker() {
        XCTAssertEqual(NoteRowText.plain("1. first"), "first")
        XCTAssertEqual(NoteRowText.plain("42.  spaced"), "spaced")
    }

    func testStripsInlineEmphasisCharacters() {
        XCTAssertEqual(NoteRowText.plain("a **bold** and *italic* and `code` and ~strike~"),
                       "a bold and italic and code and strike")
    }

    func testChecklistMarkerBeatsBulletPrefix() {
        // "- [ ] " must be recognised before the "- " inside it
        XCTAssertEqual(NoteRowText.plain("- [ ] task"), "task")
        XCTAssertFalse(NoteRowText.plain("- [ ] task").hasPrefix("["))
    }

    // MARK: - relative date

    func testRelativeDateYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(NoteRowText.relativeDate(yesterday), "Yesterday")
    }

    func testRelativeDateTodayIsNotYesterdayAndNotEmpty() {
        let s = NoteRowText.relativeDate(Date())
        XCTAssertFalse(s.isEmpty)
        XCTAssertNotEqual(s, "Yesterday")
    }

    func testRelativeDateOlderThanAWeekIsNotYesterday() {
        let old = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        let s = NoteRowText.relativeDate(old, now: Date())
        XCTAssertFalse(s.isEmpty)
        XCTAssertNotEqual(s, "Yesterday")
    }
}
