//
//  RatingPrompt.swift
//  purenote
//
//  When to ask for an App Store rating. Only the decision lives here; the
//  views call StoreKit. Apple limits how often the system really shows the
//  prompt, so this only chooses the moments to ask.
//
//  A "success" is a note whose text was changed and finished with Done, or a
//  note restored from Recently Deleted. The first ask is at the 8th success,
//  then at the 40th and the 120th, and never twice in one app version.
//  The counters are kept in the UserDefaults passed in, so tests use a
//  throwaway suite.
//

import Foundation

struct RatingPrompt {
    /// The success counts that call for an ask, in order.
    static let thresholds = [8, 40, 120]

    private static let countKey = "ratingPrompt.successCount"
    private static let thresholdKey = "ratingPrompt.lastThreshold"
    private static let versionKey = "ratingPrompt.lastVersionAsked"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The app version, as the App Store shows it.
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// How many successes have been counted so far.
    var successCount: Int { defaults.integer(forKey: Self.countKey) }

    func recordSuccess() {
        defaults.set(successCount + 1, forKey: Self.countKey)
    }

    /// True when a threshold has been reached that has not been asked about,
    /// and this version has not asked yet. Does not change anything.
    func shouldAsk(version: String) -> Bool {
        guard defaults.string(forKey: Self.versionKey) != version else { return false }
        return Self.thresholds.contains { $0 > lastThreshold && $0 <= successCount }
    }

    /// Decides and, when the answer is yes, records that this version asked.
    /// Every threshold reached so far counts as asked: a count that passed 40
    /// while this version had already asked does not ask again for 40 later.
    func takeAsk(version: String) -> Bool {
        guard shouldAsk(version: version) else { return false }
        defaults.set(version, forKey: Self.versionKey)
        defaults.set(Self.thresholds.last { $0 <= successCount } ?? lastThreshold,
                     forKey: Self.thresholdKey)
        return true
    }

    private var lastThreshold: Int { defaults.integer(forKey: Self.thresholdKey) }
}
