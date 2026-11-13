//
//  NotesLocation.swift
//  purenote
//
//  Where the notes are, said in words. The first-run screens, the About screen
//  and the folder alerts all name the place, and they used to each carry their
//  own sentence, which is how "iCloud Drive › Purnote" ended up in an alert
//  shown to people whose notes are on the phone. One pure type decides the
//  words; the views only draw them.
//

import Foundation
import UIKit

struct NotesLocation: Equatable {

    enum Kind: Equatable { case iCloud, device }

    let kind: Kind
    /// "iPhone" or "iPad", for the Files location and the sentences around it.
    let deviceName: String

    /// What the folder is called in iCloud Drive. This is the container name the
    /// app declares (NSUbiquitousContainerName in Info.plist, which a unit test
    /// checks), not the app name: the two differ in capitalisation.
    static let iCloudFolderName = "purnote"
    /// The app's own folder under "On My iPhone" in Files is named after the app.
    static let deviceFolderName = "Purnote"

    init(kind: Kind, deviceName: String = "iPhone") {
        self.kind = kind
        self.deviceName = deviceName
    }

    /// The same decision the app makes when it picks a storage root: local when
    /// the user chose to carry on without iCloud, and always in a UI-test fixture.
    static func current(useLocalStorage: Bool,
                        isUITestFixture: Bool = Storage.isUITestFixture,
                        deviceName: String = NotesLocation.currentDeviceName) -> NotesLocation {
        NotesLocation(kind: (useLocalStorage || isUITestFixture) ? .device : .iCloud,
                      deviceName: deviceName)
    }

    static var currentDeviceName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    // MARK: Words

    /// The place as Files shows it: "iCloud Drive › purnote".
    var path: String {
        switch kind {
        case .iCloud: return "iCloud Drive › \(Self.iCloudFolderName)"
        case .device: return "On My \(deviceName) › \(Self.deviceFolderName)"
        }
    }

    /// For a count line: "iCloud Drive" / "On this iPhone".
    var shortName: String {
        switch kind {
        case .iCloud: return "iCloud Drive"
        case .device: return "On this \(deviceName)"
        }
    }

    /// One line under the place, saying what it means for the notes.
    var detail: String {
        switch kind {
        case .iCloud: return "Synced to your devices"
        case .device: return "This \(deviceName) only, still visible in Files"
        }
    }

    /// The New Folder alert message.
    var newFolderMessage: String { "A real folder, in \(path)." }

    /// The Rename Folder alert message.
    var renameMessage: String { "The folder is renamed in \(path)." }

    /// The second privacy line on the About screen: where the notes go.
    var privacyDestination: String {
        switch kind {
        case .iCloud: return "Your notes go only where iCloud and you send them."
        case .device: return "Your notes stay on this \(deviceName) unless you send them somewhere."
        }
    }
}

/// The version line on the About screen.
enum AppVersion {

    /// "Version 1.5 (210)". With no build number "Version 1.5"; with neither,
    /// "Version unknown", so a missing key never prints as an empty string.
    static func text(short: String?, build: String?) -> String {
        let short = short?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let build = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !short.isEmpty else { return "Version unknown" }
        return build.isEmpty ? "Version \(short)" : "Version \(short) (\(build))"
    }

    static var current: String {
        let info = Bundle.main.infoDictionary
        return text(short: info?["CFBundleShortVersionString"] as? String,
                    build: info?["CFBundleVersion"] as? String)
    }
}
