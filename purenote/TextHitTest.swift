//
//  TextHitTest.swift
//  purenote
//
//  Which character is under a tap.
//
//  The rendered page and the editor are two different views of the same note,
//  so a tap on the page cannot be handed straight to the editor -- a paragraph
//  is drawn by MarkdownUI, which reports nothing about where its characters
//  ended up. Knowing only which block was tapped put the caret at the top of
//  that block, which is not where anybody was looking.
//
//  So the block's text is laid out again here, at the width and font it was
//  drawn with, and TextKit is asked which character sits under the point. The
//  text laid out is the block's *source*, not the rendered version, so the
//  answer is already an offset into the file. Where a line carries markup the
//  two differ by the markers themselves -- a few characters on a line with
//  **bold** in it -- which is close enough for a caret and needs no mapping
//  between two versions of the text that could drift apart.
//

import UIKit

enum TextHitTest {

    /// Character offset within `text` for a point in a box `width` wide.
    ///
    /// Offsets are in Characters, not UTF-16, because that is what the rest of
    /// the app counts in.
    static func characterOffset(in text: String,
                                font: UIFont,
                                width: CGFloat,
                                lineSpacing: CGFloat,
                                at point: CGPoint) -> Int {
        guard width > 0, !text.isEmpty else { return 0 }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing

        let storage = NSTextStorage(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
        ])
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width,
                                                     height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)

        // A tap past the last line means the end of the block, which is where
        // somebody pointing below the text wants to write.
        let used = manager.usedRect(for: container)
        if point.y > used.maxY { return text.count }

        var fraction: CGFloat = 0
        let glyph = manager.glyphIndex(for: point, in: container,
                                       fractionOfDistanceThroughGlyph: &fraction)
        var utf16 = manager.characterIndexForGlyph(at: glyph)
        // past the middle of a character means the caret belongs after it, the
        // way a tap on the right half of a letter does in any text field
        if fraction > 0.5 { utf16 += 1 }

        return text.characterOffset(ofUTF16: min(utf16, text.utf16.count))
    }

    // MARK: - which character is under the point

    /// Index (in Characters) of the character whose glyph actually contains
    /// `point`, or nil when the point is on no character -- past the end of a
    /// line, between lines, below the text.
    ///
    /// Unlike `characterOffset`, which answers "where does the caret go" and so
    /// rounds to the nearest edge, this floors: the right half of a letter is
    /// still that letter. Used to decide whether a tap landed on a link.
    static func characterIndex(containing point: CGPoint,
                               in text: String,
                               font: UIFont,
                               width: CGFloat,
                               lineSpacing: CGFloat) -> Int? {
        guard width > 0, !text.isEmpty else { return nil }
        let layout = makeLayout(text, font: font, width: width, lineSpacing: lineSpacing)
        let manager = layout.manager
        guard manager.numberOfGlyphs > 0 else { return nil }

        var fraction: CGFloat = 0
        let glyph = manager.glyphIndex(for: point, in: layout.container,
                                       fractionOfDistanceThroughGlyph: &fraction)
        guard glyph < manager.numberOfGlyphs else { return nil }

        let line = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let box = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1),
                                       in: layout.container)
        guard point.y >= line.minY, point.y < line.maxY,
              point.x >= box.minX, point.x < box.maxX
        else { return nil }

        let utf16 = manager.characterIndexForGlyph(at: glyph)
        var characters = 0
        var units = 0
        for character in text {
            units += character.utf16.count
            if utf16 < units { return characters }
            characters += 1
        }
        return nil
    }

    /// Where the Character at `index` is drawn, in the same layout
    /// `characterIndex(containing:)` uses. For tests that need a point on a
    /// particular word.
    static func characterRect(ofCharacterAt index: Int,
                              in text: String,
                              font: UIFont,
                              width: CGFloat,
                              lineSpacing: CGFloat) -> CGRect? {
        guard width > 0, index >= 0, index < text.count else { return nil }
        let layout = makeLayout(text, font: font, width: width, lineSpacing: lineSpacing)
        let start = text.index(text.startIndex, offsetBy: index)
        let range = NSRange(start..<text.index(after: start), in: text)
        let glyphs = layout.manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return layout.manager.boundingRect(forGlyphRange: glyphs, in: layout.container)
    }

    private static func makeLayout(_ text: String, font: UIFont, width: CGFloat,
                                   lineSpacing: CGFloat)
        -> (storage: NSTextStorage, manager: NSLayoutManager, container: NSTextContainer) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        let storage = NSTextStorage(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
        ])
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width,
                                                     height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        return (storage, manager, container)
    }
}
