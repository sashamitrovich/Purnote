@testable import Purnote
import XCTest
import UIKit
import SwiftUI

/// The type scale: faces, sizes at the Large content size, and scaling.
final class PurnoteTypeTests: XCTestCase {

    private let large = UITraitCollection(preferredContentSizeCategory: .large)
    private let huge = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

    private func isSerif(_ f: UIFont) -> Bool { f.fontName.contains("NewYork") }
    private func isMono(_ f: UIFont) -> Bool { f.fontName.localizedCaseInsensitiveContains("Mono") }
    private func isSans(_ f: UIFont) -> Bool { !isSerif(f) && !isMono(f) }

    func testSerifRolesUseNewYork() {
        let serif: [(String, UIFont)] = [
            ("masthead", PurnoteType.masthead(compatibleWith: large)),
            ("noteTitle", PurnoteType.noteTitle(compatibleWith: large)),
            ("h2", PurnoteType.h2(compatibleWith: large)),
            ("h3", PurnoteType.h3(compatibleWith: large)),
            ("body", PurnoteType.body(compatibleWith: large)),
            ("quote", PurnoteType.quote(compatibleWith: large)),
            ("rowTitle", PurnoteType.rowTitle(compatibleWith: large)),
            ("rowPreview", PurnoteType.rowPreview(compatibleWith: large)),
            ("marginDay", PurnoteType.marginDay(compatibleWith: large)),
        ]
        for (name, f) in serif { XCTAssertTrue(isSerif(f), "\(name) is \(f.fontName)") }
    }

    func testSansAndMonoRoles() {
        for (name, f) in [("caps", PurnoteType.caps(compatibleWith: large)),
                          ("ui", PurnoteType.ui(compatibleWith: large)),
                          ("meta", PurnoteType.meta(compatibleWith: large))] {
            XCTAssertTrue(isSans(f), "\(name) is \(f.fontName)")
        }
        let m = PurnoteType.mono(compatibleWith: large)
        XCTAssertTrue(isMono(m), "mono is \(m.fontName)")
    }

    func testQuoteIsItalic() {
        let q = PurnoteType.quote(compatibleWith: large)
        XCTAssertTrue(q.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testSizesAtLarge() {
        XCTAssertEqual(PurnoteType.masthead(compatibleWith: large).pointSize, 44, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.masthead(long: true, compatibleWith: large).pointSize, 38, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.noteTitle(compatibleWith: large).pointSize, 34, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.h2(compatibleWith: large).pointSize, 22, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.h3(compatibleWith: large).pointSize, 18, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.body(compatibleWith: large).pointSize, 17, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.quote(compatibleWith: large).pointSize, 18, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.rowTitle(compatibleWith: large).pointSize, 19, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.rowPreview(compatibleWith: large).pointSize, 15, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.marginDay(compatibleWith: large).pointSize, 17, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.caps(compatibleWith: large).pointSize, 11, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.ui(compatibleWith: large).pointSize, 17, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.meta(compatibleWith: large).pointSize, 13, accuracy: 0.01)
        XCTAssertEqual(PurnoteType.mono(compatibleWith: large).pointSize, 13, accuracy: 0.01)
    }

    func testWeights() {
        func weight(_ f: UIFont) -> CGFloat {
            (f.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])?[.weight] as? CGFloat ?? 0
        }
        XCTAssertGreaterThan(weight(PurnoteType.noteTitle(compatibleWith: large)), UIFont.Weight.semibold.rawValue)
        XCTAssertEqual(weight(PurnoteType.rowTitle(compatibleWith: large)), UIFont.Weight.semibold.rawValue, accuracy: 0.01)
        XCTAssertEqual(weight(PurnoteType.body(compatibleWith: large)), UIFont.Weight.regular.rawValue, accuracy: 0.01)
    }

    func testFontsScaleUpAtAccessibilitySizes() {
        let roles: [(String, (UITraitCollection) -> UIFont)] = [
            ("masthead", { PurnoteType.masthead(compatibleWith: $0) }),
            ("noteTitle", { PurnoteType.noteTitle(compatibleWith: $0) }),
            ("h2", { PurnoteType.h2(compatibleWith: $0) }),
            ("h3", { PurnoteType.h3(compatibleWith: $0) }),
            ("body", { PurnoteType.body(compatibleWith: $0) }),
            ("quote", { PurnoteType.quote(compatibleWith: $0) }),
            ("rowTitle", { PurnoteType.rowTitle(compatibleWith: $0) }),
            ("rowPreview", { PurnoteType.rowPreview(compatibleWith: $0) }),
            ("marginDay", { PurnoteType.marginDay(compatibleWith: $0) }),
            ("caps", { PurnoteType.caps(compatibleWith: $0) }),
            ("ui", { PurnoteType.ui(compatibleWith: $0) }),
            ("meta", { PurnoteType.meta(compatibleWith: $0) }),
            ("mono", { PurnoteType.mono(compatibleWith: $0) }),
        ]
        for (name, make) in roles {
            XCTAssertGreaterThan(make(huge).pointSize, make(large).pointSize, "\(name) did not scale")
        }
    }

    func testSwiftUITwinsExist() {
        _ = PurnoteType.Twin.masthead(); _ = PurnoteType.Twin.noteTitle(); _ = PurnoteType.Twin.h2()
        _ = PurnoteType.Twin.h3(); _ = PurnoteType.Twin.body(); _ = PurnoteType.Twin.quote()
        _ = PurnoteType.Twin.rowTitle(); _ = PurnoteType.Twin.rowPreview(); _ = PurnoteType.Twin.marginDay()
        _ = PurnoteType.Twin.caps(); _ = PurnoteType.Twin.ui(); _ = PurnoteType.Twin.meta(); _ = PurnoteType.Twin.mono()
    }
}
