@testable import Purnote
import XCTest
import UIKit
import SwiftUI

/// The colour tokens must resolve to the exact design values, and the pairs
/// the design relies on must keep their contrast.
final class PurnoteColorTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    private func rgba(_ c: UIColor, _ t: UITraitCollection) -> (r: Int, g: Int, b: Int, a: CGFloat) {
        let resolved = c.resolvedColor(with: t)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&r, green: &g, blue: &b, alpha: &a))
        return (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()), a)
    }

    private func hex(_ c: UIColor, _ t: UITraitCollection) -> UInt32 {
        let v = rgba(c, t)
        return UInt32(v.r) << 16 | UInt32(v.g) << 8 | UInt32(v.b)
    }

    private func luminance(_ c: UIColor, _ t: UITraitCollection) -> Double {
        let resolved = c.resolvedColor(with: t)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ v: CGFloat) -> Double {
            let d = Double(v)
            return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func contrast(_ a: UIColor, _ b: UIColor, _ t: UITraitCollection) -> Double {
        let la = luminance(a, t), lb = luminance(b, t)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    // MARK: (a) exact values

    func testTokensResolveToExactHex() {
        let table: [(String, UIColor, UInt32, UInt32)] = [
            ("page", PurnoteColor.page, 0xFBFBF9, 0x0F1012),
            ("sheet", PurnoteColor.sheet, 0xFFFFFF, 0x18191C),
            ("fill", PurnoteColor.fill, 0xF1F1EE, 0x1C1D20),
            ("ink", PurnoteColor.ink, 0x14161A, 0xEDEBE6),
            ("ink2", PurnoteColor.ink2, 0x5E626B, 0xA3A5AB),
            ("ink3", PurnoteColor.ink3, 0x8C9098, 0x6B6E75),
            ("rule", PurnoteColor.rule, 0xE3E3DF, 0x26282C),
            ("ribbon", PurnoteColor.ribbon, 0xC2511A, 0xF08A3E),
            ("ribbonText", PurnoteColor.ribbonText, 0xA9480C, 0xF5A262),
            ("red", PurnoteColor.red, 0xD93A2B, 0xFF5A4B),
        ]
        for (name, color, l, d) in table {
            XCTAssertEqual(hex(color, light), l, "\(name) light: \(String(hex(color, light), radix: 16))")
            XCTAssertEqual(hex(color, dark), d, "\(name) dark: \(String(hex(color, dark), radix: 16))")
        }
    }

    func testHexInitHonoursAlpha() {
        let c = UIColor(hex: 0x102030, alpha: 0.5)
        let v = rgba(c, light)
        XCTAssertEqual(v.r, 0x10); XCTAssertEqual(v.g, 0x20); XCTAssertEqual(v.b, 0x30)
        XCTAssertEqual(v.a, 0.5, accuracy: 0.001)
    }

    func testSwiftUITwinsMatchUIKitTokens() {
        let pairs: [(Color, UIColor)] = [
            (Color.pn.page, PurnoteColor.page), (Color.pn.sheet, PurnoteColor.sheet),
            (Color.pn.fill, PurnoteColor.fill), (Color.pn.ink, PurnoteColor.ink),
            (Color.pn.ink2, PurnoteColor.ink2), (Color.pn.ink3, PurnoteColor.ink3),
            (Color.pn.rule, PurnoteColor.rule), (Color.pn.ribbon, PurnoteColor.ribbon),
            (Color.pn.ribbonText, PurnoteColor.ribbonText),
            (Color.pn.ribbonWash, PurnoteColor.ribbonWash), (Color.pn.red, PurnoteColor.red),
        ]
        for (twin, ui) in pairs {
            for t in [light, dark] {
                let a = rgba(UIColor(twin), t), b = rgba(ui, t)
                XCTAssertEqual(a.r, b.r); XCTAssertEqual(a.g, b.g); XCTAssertEqual(a.b, b.b)
                XCTAssertEqual(a.a, b.a, accuracy: 0.01)
            }
        }
    }

    // MARK: (b) contrast

    func testContrastOnPage() {
        let page = PurnoteColor.page
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.ink, page, light), 16)
        // Dark ink is 15.98:1 (the design table rounds it to 16.0), so the
        // floor here is 15.95 rather than a literal 16.
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.ink, page, dark), 15.95)
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.ink2, page, light), 5.5)
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.ink2, page, dark), 5.5)
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.ribbonText, page, light), 5.2)
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.ribbonText, page, dark), 9)
    }

    func testButtonTextOnRibbon() {
        XCTAssertGreaterThanOrEqual(contrast(.white, PurnoteColor.ribbon, light), 4.5)
        // On the dark ribbon the button text is the dark page colour (design
        // table: "ink on it 7.6:1"), not the light `ink` token.
        XCTAssertGreaterThanOrEqual(contrast(PurnoteColor.page, PurnoteColor.ribbon, dark), 7)
    }

    // MARK: (c) wash

    func testRibbonWashAlpha() {
        let l = rgba(PurnoteColor.ribbonWash, light)
        let d = rgba(PurnoteColor.ribbonWash, dark)
        XCTAssertEqual(l.a, 0.10, accuracy: 0.005)
        XCTAssertEqual(d.a, 0.14, accuracy: 0.005)
        XCTAssertEqual(hex(PurnoteColor.ribbonWash, light), 0xC2511A)
        XCTAssertEqual(hex(PurnoteColor.ribbonWash, dark), 0xF08A3E)
    }
}
