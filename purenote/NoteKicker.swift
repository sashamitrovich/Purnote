//
//  NoteKicker.swift
//  purenote
//
//  The small line above a note's title: "Journal · Edited today, 07:40".
//
//  Pure text, so it can be tested; the view sets it in small SF capitals. It
//  names the folder, never the file: a new note's file is named by the clock
//  until it is first saved, so a file name here would be false or ugly.
//

import Foundation

enum NoteKicker {

    /// What the root of the library is called when there is no folder to name.
    static let rootName = "Purnote"

    /// "Journal · Edited today, 07:40". A nil or empty folder is the library
    /// root and reads "Purnote".
    static func text(folder: String?, modified: Date, now: Date = Date(),
                     calendar: Calendar = .current, locale: Locale = .current) -> String {
        let name = (folder?.isEmpty == false) ? folder! : rootName
        return name + " · " + edited(modified, now: now, calendar: calendar, locale: locale)
    }

    /// "Edited today, 07:40", "Edited yesterday, 23:05", "Edited 4 Mar" (this
    /// year), "Edited 31 Dec 2025" (any other year, and a date after `now`).
    static func edited(_ date: Date, now: Date = Date(),
                       calendar: Calendar = .current, locale: Locale = .current) -> String {
        func format(_ template: String) -> String {
            let f = DateFormatter()
            f.locale = locale
            f.calendar = calendar
            f.timeZone = calendar.timeZone
            f.setLocalizedDateFormatFromTemplate(template)
            return f.string(from: date)
        }

        if date <= now || calendar.isDate(date, inSameDayAs: now) {
            if calendar.isDate(date, inSameDayAs: now) { return "Edited today, " + format("jmm") }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               calendar.isDate(date, inSameDayAs: yesterday) {
                return "Edited yesterday, " + format("jmm")
            }
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return "Edited " + format(sameYear ? "dMMM" : "dMMMy")
    }

    /// The folder a note is in, relative to the library root: the innermost
    /// folder's name, or nil for a note at the root.
    static func folderName(of noteURL: URL, libraryRoot: URL) -> String? {
        let folder = noteURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        let root = libraryRoot.resolvingSymlinksInPath().standardizedFileURL.path
        guard folder != root else { return nil }
        return (folder as NSString).lastPathComponent
    }
}
