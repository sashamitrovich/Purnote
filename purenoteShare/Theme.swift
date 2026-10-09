//
//  Theme.swift
//  purenoteShare
//

import UIKit

extension UIColor {
    /// Mirrors the app's paper colour (`extensions/View.swift` in the app
    /// target) so the extension matches it exactly. Keep the two in sync.
    static let purnotePaper = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.090, green: 0.084, blue: 0.067, alpha: 1)   // ~#17150F
            : UIColor(red: 0.988, green: 0.980, blue: 0.965, alpha: 1)   // ~#FCFAF6
    }

    /// Purnote's accent: warm amber, deliberately distinct from Apple's orange.
    /// Mirrors the app's `AccentColor` asset so the extension matches it exactly.
    static let purnoteAmber = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.933, green: 0.541, blue: 0.235, alpha: 1)   // #EE8A3C
            : UIColor(red: 0.871, green: 0.420, blue: 0.106, alpha: 1)   // #DE6B1B
    }
}
