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
}
