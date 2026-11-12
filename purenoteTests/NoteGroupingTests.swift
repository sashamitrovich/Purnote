@testable import Purnote
import XCTest

final class NoteGroupingTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US")
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func note(_ name: String, _ when: Date) -> Note {
        Note(content: name, date: when, path: name, isLocal: true, url: URL(fileURLWithPath: "/lib/\(name)"))
    }

    func testGroupsByMonthAndYearInOrder() {
        let notes = [
            note("a", date(2026, 11, 12)),
            note("b", date(2026, 11, 1, 0)),
            note("c", date(2026, 10, 31, 23)),
            note("d", date(2025, 10, 5)),
        ]
        let groups = NoteGrouping.byMonth(notes, now: date(2026, 11, 12), calendar: calendar)
        XCTAssertEqual(groups.map(\.title), ["November 2026", "October 2026", "October 2025"])
        XCTAssertEqual(groups.map { $0.notes.map(\.id) }, [["a", "b"], ["c"], ["d"]])
    }

    func testYearBoundary() {
        let notes = [note("new", date(2026, 1, 1, 0)), note("old", date(2025, 12, 31, 23))]
        let groups = NoteGrouping.byMonth(notes, now: date(2026, 1, 15), calendar: calendar)
        XCTAssertEqual(groups.map(\.title), ["January 2026", "December 2025"])
    }

    func testEmptyInputGivesNoGroups() {
        XCTAssertTrue(NoteGrouping.byMonth([], now: date(2026, 1, 1), calendar: calendar).isEmpty)
    }

    func testDayAndWeekdayOfNote() {
        // 2026-11-12 is a Thursday
        let n = note("a", date(2026, 11, 12))
        let group = NoteGrouping.byMonth([n], now: date(2026, 11, 12), calendar: calendar)[0]
        XCTAssertEqual(group.day(of: n), 12)
        XCTAssertEqual(group.weekday(of: n), "Thu")
    }

    func testDayUsesCalendarTimeZone() {
        // 23:30 UTC on the 31st is already the 1st in Tokyo
        var tokyo = calendar
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let n = note("a", date(2026, 10, 31, 23))
        let utc = NoteGrouping.byMonth([n], now: n.date, calendar: calendar)[0]
        let jp = NoteGrouping.byMonth([n], now: n.date, calendar: tokyo)[0]
        XCTAssertEqual(utc.title, "October 2026")
        XCTAssertEqual(jp.title, "November 2026")
        XCTAssertEqual(utc.day(of: n), 31)
        XCTAssertEqual(jp.day(of: n), 1)
    }

    func testNonAdjacentSameMonthStaysInInputOrder() {
        // e.g. a title-sorted list: runs are kept, not merged
        let notes = [note("a", date(2026, 11, 1)), note("b", date(2026, 10, 1)), note("c", date(2026, 11, 2))]
        let groups = NoteGrouping.byMonth(notes, now: date(2026, 11, 12), calendar: calendar)
        XCTAssertEqual(groups.map(\.title), ["November 2026", "October 2026", "November 2026"])
    }
}
