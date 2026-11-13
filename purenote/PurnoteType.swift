//
//  PurnoteType.swift
//  purenote
//
//  The 1.5 type scale (direction B, "Type scale"). Each role is a function
//  returning a UIFont scaled with UIFontMetrics for the stated text style,
//  plus a SwiftUI twin in `PurnoteType.Twin`. Sizes are the values at the
//  Large content size. Serif is New York (`.serif` design); sans is SF;
//  mono is SF Mono.
//
//  The twins wrap an already-scaled UIFont, so a view must be re-evaluated
//  for them to follow a Dynamic Type change.
//
//  Not yet wired into the editor or the rendered note body: TextHitTest,
//  NoteBody and LinkHit measure those fonts (see the serif-body spike).
//

import SwiftUI
import UIKit

enum PurnoteType {

    // Tracking in points, applied with NSAttributedString.kern / .kerning().
    static let mastheadTracking: CGFloat = -0.9
    static let noteTitleTracking: CGFloat = -0.6
    static let capsTracking: CGFloat = 0.8

    /// The reading body's size at the Large content size (see `body`).
    static let bodyPoints: CGFloat = 17

    // MARK: Builders

    private static func make(size: CGFloat, weight: UIFont.Weight, design: UIFontDescriptor.SystemDesign,
                             italic: Bool = false, features: Bool = false,
                             style: UIFont.TextStyle, traits: UITraitCollection?) -> UIFont {
        var d = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let withDesign = d.withDesign(design) { d = withDesign }
        if italic, let it = d.withSymbolicTraits(d.symbolicTraits.union(.traitItalic)) { d = it }
        if features {
            // lining, tabular figures
            d = d.addingAttributes([.featureSettings: [
                [UIFontDescriptor.FeatureKey.type: 21, UIFontDescriptor.FeatureKey.selector: 1],
                [UIFontDescriptor.FeatureKey.type: 6, UIFontDescriptor.FeatureKey.selector: 0],
            ]])
        }
        let base = UIFont(descriptor: d, size: size)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base, compatibleWith: traits)
    }

    // MARK: Serif (New York)

    /// 44 (38 for long names), regular. Style `.largeTitle` x 1.3.
    static func masthead(long: Bool = false, compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: long ? 38 : 44, weight: .regular, design: .serif, style: .largeTitle, traits: traits)
    }
    /// 34 bold. `.largeTitle`.
    static func noteTitle(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 34, weight: .bold, design: .serif, style: .largeTitle, traits: traits)
    }
    /// 22 semibold. `.title2`.
    static func h2(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 22, weight: .semibold, design: .serif, style: .title2, traits: traits)
    }
    /// 18 semibold. `.headline`.
    static func h3(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 18, weight: .semibold, design: .serif, style: .headline, traits: traits)
    }
    /// 17 regular. `.body`.
    static func body(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 17, weight: .regular, design: .serif, style: .body, traits: traits)
    }
    /// 18 italic. `.body`.
    static func quote(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 18, weight: .regular, design: .serif, italic: true, style: .body, traits: traits)
    }
    /// 19 semibold. `.title3`.
    static func rowTitle(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 19, weight: .semibold, design: .serif, style: .title3, traits: traits)
    }
    /// 15 regular. `.subheadline`.
    static func rowPreview(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 15, weight: .regular, design: .serif, style: .subheadline, traits: traits)
    }
    /// 17 semibold, lining tabular figures. `.body`.
    static func marginDay(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 17, weight: .semibold, design: .serif, features: true, style: .body, traits: traits)
    }

    // MARK: Sans (SF) and mono

    /// Margin weekday, kicker, section label: 11 semibold, set in capitals
    /// with `capsTracking`. `.caption1`.
    static func caps(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 11, weight: .semibold, design: .default, style: .caption1, traits: traits)
    }
    /// UI text, buttons, folder index: 17 regular (pass `.semibold` weight via the twin). `.body`.
    static func ui(weight: UIFont.Weight = .regular, compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 17, weight: weight, design: .default, style: .body, traits: traits)
    }
    /// Meta lines: 13 medium. `.footnote`.
    static func meta(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 13, weight: .medium, design: .default, style: .footnote, traits: traits)
    }
    /// Hanging syntax, code: SF Mono 13 regular. `.footnote`.
    static func mono(compatibleWith traits: UITraitCollection? = nil) -> UIFont {
        make(size: 13, weight: .regular, design: .monospaced, style: .footnote, traits: traits)
    }

    // MARK: SwiftUI twins

    enum Twin {
        static func masthead(long: Bool = false) -> Font { Font(PurnoteType.masthead(long: long)) }
        static func noteTitle() -> Font { Font(PurnoteType.noteTitle()) }
        static func h2() -> Font { Font(PurnoteType.h2()) }
        static func h3() -> Font { Font(PurnoteType.h3()) }
        static func body() -> Font { Font(PurnoteType.body()) }
        static func quote() -> Font { Font(PurnoteType.quote()) }
        static func rowTitle() -> Font { Font(PurnoteType.rowTitle()) }
        static func rowPreview() -> Font { Font(PurnoteType.rowPreview()) }
        static func marginDay() -> Font { Font(PurnoteType.marginDay()) }
        static func caps() -> Font { Font(PurnoteType.caps()) }
        static func ui(weight: UIFont.Weight = .regular) -> Font { Font(PurnoteType.ui(weight: weight)) }
        static func meta() -> Font { Font(PurnoteType.meta()) }
        static func mono() -> Font { Font(PurnoteType.mono()) }
    }
}
