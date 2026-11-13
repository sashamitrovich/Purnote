@testable import Purnote
import XCTest

/// The line above a note's title: "Journal · Edited today, 07:40". Pure text; the
/// view sets it in small SF capitals. It never shows the file name.
final class NoteKickerTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_GB")
        return c
    }
    private let locale = Locale(identifier: "en_GB")

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func kicker(folder: String?, modified: Date, now: Date) -> String {
        NoteKicker.text(folder: folder, modified: modified, now: now, calendar: calendar, locale: locale)
    }

    // MARK: edited

    func testEditedToday() {
        let now = date(2026, 11, 13, 18, 0)
        XCTAssertEqual(NoteKicker.edited(date(2026, 11, 13, 7, 40), now: now, calendar: calendar, locale: locale),
                       "Edited today, 07:40")
    }

    func testEditedYesterday() {
        let now = date(2026, 11, 13, 9, 0)
        XCTAssertEqual(NoteKicker.edited(date(2026, 11, 12, 23, 5), now: now, calendar: calendar, locale: locale),
                       "Edited yesterday, 23:05")
    }

    func testEditedEarlierThisYearUsesDayAndMonth() {
        let now = date(2026, 11, 13, 9, 0)
        XCTAssertEqual(NoteKicker.edited(date(2026, 3, 4, 12, 0), now: now, calendar: calendar, locale: locale),
                       "Edited 4 Mar")
    }

    func testEditedInAnEarlierYearAddsTheYear() {
        let now = date(2026, 11, 13, 9, 0)
        XCTAssertEqual(NoteKicker.edited(date(2025, 12, 31, 12, 0), now: now, calendar: calendar, locale: locale),
                       "Edited 31 Dec 2025")
    }

    func testJustAfterMidnightIsStillToday() {
        let now = date(2026, 11, 13, 0, 30)
        XCTAssertEqual(NoteKicker.edited(date(2026, 11, 13, 0, 5), now: now, calendar: calendar, locale: locale),
                       "Edited today, 00:05")
    }

    func testAFutureDateIsShownAsADate() {
        // a clock that is behind the file's: never "in the future" wording
        let now = date(2026, 11, 13, 9, 0)
        XCTAssertEqual(NoteKicker.edited(date(2026, 11, 14, 10, 0), now: now, calendar: calendar, locale: locale),
                       "Edited 14 Nov")
    }

    // MARK: the whole line

    func testFolderAndEdited() {
        let now = date(2026, 11, 13, 18, 0)
        XCTAssertEqual(kicker(folder: "Journal", modified: date(2026, 11, 13, 7, 40), now: now),
                       "Journal · Edited today, 07:40")
    }

    func testRootNoteSaysPurnote() {
        let now = date(2026, 11, 13, 18, 0)
        XCTAssertEqual(kicker(folder: nil, modified: date(2026, 11, 13, 7, 40), now: now),
                       "Purnote · Edited today, 07:40")
    }

    func testEmptyFolderNameIsTheRoot() {
        let now = date(2026, 11, 13, 18, 0)
        XCTAssertEqual(kicker(folder: "", modified: date(2026, 11, 13, 7, 40), now: now),
                       "Purnote · Edited today, 07:40")
    }

    func testNeverShowsAFileName() {
        let now = date(2026, 11, 13, 18, 0)
        let line = kicker(folder: "Journal", modified: date(2026, 11, 13, 7, 40), now: now)
        XCTAssertFalse(line.contains(".md"))
        XCTAssertFalse(line.contains("Untitled"))
    }

    // MARK: the folder a note is in

    func testFolderNameForARootNoteIsNil() {
        let root = URL(fileURLWithPath: "/lib")
        XCTAssertNil(NoteKicker.folderName(of: root.appendingPathComponent("A.md"), libraryRoot: root))
    }

    func testFolderNameIsTheFolderTheNoteIsIn() {
        let root = URL(fileURLWithPath: "/lib")
        XCTAssertEqual(NoteKicker.folderName(of: root.appendingPathComponent("Journal/A.md"), libraryRoot: root),
                       "Journal")
    }

    func testFolderNameOfANestedNoteIsTheInnermostFolder() {
        let root = URL(fileURLWithPath: "/lib")
        XCTAssertEqual(NoteKicker.folderName(of: root.appendingPathComponent("Travel/Italy/A.md"), libraryRoot: root),
                       "Italy")
    }

    func testFolderNameWithRootGivenAsASymlinkedPath() {
        // /private/var vs /var: both spellings of the root must be the root
        let root = URL(fileURLWithPath: "/var/lib")
        let note = URL(fileURLWithPath: "/private/var/lib/A.md")
        XCTAssertNil(NoteKicker.folderName(of: note, libraryRoot: root))
    }
}
