//
//  Theme.swift
//  purenoteShare
//

import UIKit

/// Hand-copied from `PurnoteColor` (purenote/PurnoteColor.swift in the app
/// target), which is the source of truth. Keep the values in sync.
extension UIColor {
    private convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }

    /// `page`: #FBFBF9 light, #0F1012 dark.
    static let pnPage = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0x0F1012) : UIColor(hex: 0xFBFBF9)
    }

    /// `ribbon`: #C2511A light, #F08A3E dark. Mirrors the app's `AccentColor` asset.
    static let pnRibbon = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: 0xF08A3E) : UIColor(hex: 0xC2511A)
    }
}
