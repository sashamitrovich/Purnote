//
//  NoteDates.swift
//  purenote
//
//  The one place a note's date comes from. The date a note shows and sorts by
//  is when its file was last changed, not when it was created: saving replaces
//  the file (CoordinatedFile.write is atomic), which resets the creation date,
//  so the creation date only says "last saved in this app" and goes stale when
//  a note is edited on the Mac or in another app.
//

import Foundation

enum NoteDates {

    /// The file's content modification date; failing that its creation date;
    /// failing that now.
    static func modified(of url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        return values?.contentModificationDate ?? values?.creationDate ?? Date()
    }
}
