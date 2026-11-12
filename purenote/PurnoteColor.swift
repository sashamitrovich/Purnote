//
//  PurnoteColor.swift
//  purenote
//
//  The colour tokens of the 1.5 design (direction B, "Colour tokens"). One
//  source: every token is a light/dark dynamic UIColor with a SwiftUI twin
//  under `Color.pn`. The share extension keeps a hand-copied subset in
//  purenoteShare/Theme.swift; keep the two in sync.
//

import SwiftUI
import UIKit

extension UIColor {
    /// 0xRRGGBB, with an optional alpha.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    /// A colour that switches between two hex values with the appearance.
    static func pnDynamic(light: UInt32, dark: UInt32,
                          lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        }
    }
}

enum PurnoteColor {
    /// Every screen.
    static let page = UIColor.pnDynamic(light: 0xFBFBF9, dark: 0x0F1012)
    /// Sheets, menus.
    static let sheet = UIColor.pnDynamic(light: 0xFFFFFF, dark: 0x18191C)
    /// Quiet buttons, fields, code blocks, segmented controls.
    static let fill = UIColor.pnDynamic(light: 0xF1F1EE, dark: 0x1C1D20)
    /// Text.
    static let ink = UIColor.pnDynamic(light: 0x14161A, dark: 0xEDEBE6)
    /// Secondary text, previews.
    static let ink2 = UIColor.pnDynamic(light: 0x5E626B, dark: 0xA3A5AB)
    /// Dimmed syntax, bullets, glyphs only. Never for text that must be read.
    static let ink3 = UIColor.pnDynamic(light: 0x8C9098, dark: 0x6B6E75)
    /// Hairlines.
    static let rule = UIColor.pnDynamic(light: 0xE3E3DF, dark: 0x26282C)
    /// Compose, primary buttons, pins, caret, tints. Carries white text (light) or ink (dark).
    static let ribbon = UIColor.pnDynamic(light: 0xC2511A, dark: 0xF08A3E)
    /// Amber as text: links, tags, Undo, active bar item.
    static let ribbonText = UIColor.pnDynamic(light: 0xA9480C, dark: 0xF5A262)
    /// Active formatting item, search match highlight: ribbon at 10% / 14%.
    static let ribbonWash = UIColor.pnDynamic(light: 0xC2511A, dark: 0xF08A3E,
                                              lightAlpha: 0.10, darkAlpha: 0.14)
    /// Delete only.
    static let red = UIColor.pnDynamic(light: 0xD93A2B, dark: 0xFF5A4B)
}

/// SwiftUI twins: `Color.pn.ink`, `Color.pn.ribbon`, ...
struct PurnoteColors {
    let page = Color(uiColor: PurnoteColor.page)
    let sheet = Color(uiColor: PurnoteColor.sheet)
    let fill = Color(uiColor: PurnoteColor.fill)
    let ink = Color(uiColor: PurnoteColor.ink)
    let ink2 = Color(uiColor: PurnoteColor.ink2)
    let ink3 = Color(uiColor: PurnoteColor.ink3)
    let rule = Color(uiColor: PurnoteColor.rule)
    let ribbon = Color(uiColor: PurnoteColor.ribbon)
    let ribbonText = Color(uiColor: PurnoteColor.ribbonText)
    let ribbonWash = Color(uiColor: PurnoteColor.ribbonWash)
    let red = Color(uiColor: PurnoteColor.red)
}

extension Color {
    static let pn = PurnoteColors()
}
