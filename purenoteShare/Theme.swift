//
//  Theme.swift
//  purenoteShare
//

import UIKit

/// Hand-copied from `PurnoteColor` (purenote/PurnoteColor.swift in the app
/// target), which is the source of truth. Keep the values in sync. The app
/// file imports SwiftUI, so the extension keeps its own UIKit-only copy of the
/// tokens it uses; this is the only file in the extension with hex values.
extension UIColor {
    private convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        }
    }

    /// `page`: #FBFBF9 light, #0F1012 dark.
    static let pnPage = dynamic(light: 0xFBFBF9, dark: 0x0F1012)
    /// `sheet`: #FFFFFF light, #18191C dark. Sheets, menus.
    static let pnSheet = dynamic(light: 0xFFFFFF, dark: 0x18191C)
    /// `fill`: #F1F1EE light, #1C1D20 dark. Quiet buttons, fields.
    static let pnFill = dynamic(light: 0xF1F1EE, dark: 0x1C1D20)
    /// `ink`: #14161A light, #EDEBE6 dark. Text.
    static let pnInk = dynamic(light: 0x14161A, dark: 0xEDEBE6)
    /// `ink2`: #5E626B light, #A3A5AB dark. Secondary text.
    static let pnInk2 = dynamic(light: 0x5E626B, dark: 0xA3A5AB)
    /// `ink3`: #8C9098 light, #6B6E75 dark. Dimmed syntax and glyphs only.
    static let pnInk3 = dynamic(light: 0x8C9098, dark: 0x6B6E75)
    /// `rule`: #E3E3DF light, #26282C dark. Hairlines.
    static let pnRule = dynamic(light: 0xE3E3DF, dark: 0x26282C)
    /// `ribbon`: #C2511A light, #F08A3E dark. Mirrors the app's `AccentColor` asset.
    static let pnRibbon = dynamic(light: 0xC2511A, dark: 0xF08A3E)
    /// `ribbonText`: #A9480C light, #F5A262 dark. Amber as text.
    static let pnRibbonText = dynamic(light: 0xA9480C, dark: 0xF5A262)
    /// Text on a `ribbon` button: white on the light ribbon (4.7:1), the page
    /// colour on the dark ribbon (7.6:1; white would be 2.5:1).
    static let pnOnRibbon = dynamic(light: 0xFFFFFF, dark: 0x0F1012)
}

/// Hand-copied from `PurnoteType` (purenote/PurnoteType.swift, the 1.5 type
/// scale). Sizes are the values at the Large content size; each font is scaled
/// with `UIFontMetrics` for its text style so Dynamic Type works.
enum PNFont {

    /// Tracking in points for capitals, as `PurnoteType.capsTracking`.
    static let capsTracking: CGFloat = 0.8

    private static func make(size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign,
                             style: UIFont.TextStyle, maximum: CGFloat? = nil, traits: UITraitCollection?) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let withDesign = descriptor.withDesign(design) { descriptor = withDesign }
        let base = UIFont(descriptor: descriptor, size: size)
        let metrics = UIFontMetrics(forTextStyle: style)
        if let maximum {
            return metrics.scaledFont(for: base, maximumPointSize: maximum, compatibleWith: traits)
        }
        return metrics.scaledFont(for: base, compatibleWith: traits)
    }

    /// New York 34 bold (`noteTitle`).
    static func title(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 34, weight: .bold, design: .serif, style: .largeTitle, traits: traits)
    }
    /// New York 22 semibold (`h2`): the title when the first line is long.
    static func titleLong(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 22, weight: .semibold, design: .serif, style: .title2, traits: traits)
    }
    /// New York 17 semibold (sheet title), capped so the header stays one row.
    static func sheetTitle(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 17, weight: .semibold, design: .serif, style: .body, maximum: 26, traits: traits)
    }
    /// New York 17 regular (`body`).
    static func body(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 17, weight: .regular, design: .serif, style: .body, traits: traits)
    }
    /// SF 11 semibold (`caps`), set in capitals with `capsTracking`.
    static func caps(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 11, weight: .semibold, design: .default, style: .caption1, traits: traits)
    }
    /// SF 17 (`ui`): buttons and folder rows.
    static func ui(weight: UIFont.Weight = .regular, maximum: CGFloat? = nil,
                   compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 17, weight: weight, design: .default, style: .body, maximum: maximum, traits: traits)
    }
    /// SF 13 medium (`meta`).
    static func meta(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 13, weight: .medium, design: .default, style: .footnote, traits: traits)
    }
}
