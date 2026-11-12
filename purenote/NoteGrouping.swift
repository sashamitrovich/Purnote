//
//  NoteGrouping.swift
//  purenote
//
//  Month grouping for a date-sorted list, as a pure function. Not wired to a
//  view yet.
//

import Foundation

struct MonthGroup {
    /// "November 2026"
    let title: String
    let notes: [Note]
    let calendar: Calendar

    /// Day of the month in the calendar's time zone.
    func day(of note: Note) -> Int {
        calendar.component(.day, from: note.date)
    }

    /// Short weekday name in the calendar's locale, e.g. "Thu".
    func weekday(of note: Note) -> String {
        let index = calendar.component(.weekday, from: note.date) - 1
        return calendar.shortWeekdaySymbols[index]
    }
}

enum NoteGrouping {

    /// Splits `notes` into runs of the same month and year, keeping the given
    /// order. Titles are always "Month YYYY". `now` is accepted so a view can
    /// pass the clock it already uses; the grouping itself does not depend on it.
    static func byMonth(_ notes: [Note], now: Date, calendar: Calendar) -> [MonthGroup] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? Locale.current
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")

        var groups: [MonthGroup] = []
        var run: [Note] = []
        var runKey: DateComponents?

        func flush() {
            guard let first = run.first else { return }
            groups.append(MonthGroup(title: formatter.string(from: first.date), notes: run, calendar: calendar))
            run = []
        }

        for note in notes {
            let key = calendar.dateComponents([.year, .month], from: note.date)
            if key != runKey { flush(); runKey = key }
            run.append(note)
        }
        flush()
        return groups
    }
}
