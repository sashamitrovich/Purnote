//
//  HangingStyler.swift
//  purenote
//
//  The UIKit half of the editor's hanging syntax: turns what HangingSyntax
//  describes into attributes on the text view's text storage.
//
//  The guarantee that matters: this only ever changes ATTRIBUTES. It never
//  calls replaceCharacters, never assigns `text` or `attributedText`, and never
//  goes through the text view's edit path, so the characters (and the file made
//  from them) cannot change and the undo stack is not touched -- UITextView
//  registers undo for edits made through its input system, not for attribute
//  changes made directly on the storage.
//
//  Nothing here is persisted: notes are saved from `textView.text`, a plain
//  String. The attributes live and die with the view.
//

import UIKit

final class HangingStyler {

    /// Forces the next `apply` to restyle the whole document (a size or
    /// appearance change, or text typed while a composition was open).
    var needsFullRestyle = true

    private var lastFenceLines = -1
    private var lastMode: HangingSyntax.Mode?
    /// The last description and the text length it was made for, so a caret
    /// move does not restyle the whole note to find its typing attributes.
    private var lastResult: HangingSyntax.Result?
    private var lastLength = -1

    // MARK: - Metrics

    static func metrics(for traits: UITraitCollection) -> HangingSyntax.Metrics {
        let mono = PurnoteType.mono(compatibleWith: traits)
        let cell = ("0" as NSString).size(withAttributes: [.font: mono]).width
        return HangingSyntax.Metrics(
            margin: UIFontMetrics(forTextStyle: .body).scaledValue(for: 36, compatibleWith: traits),
            cell: cell,
            isAccessibilitySize: traits.preferredContentSizeCategory.isAccessibilityCategory)
    }

    // MARK: - Fonts and attributes

    private static func baseFont(_ kind: HangingSyntax.Kind, traits: UITraitCollection) -> UIFont {
        switch kind {
        case .heading(let level):
            switch level {
            case 1: return PurnoteType.noteTitle(compatibleWith: traits)
            case 2: return PurnoteType.h2(compatibleWith: traits)
            default: return PurnoteType.h3(compatibleWith: traits)
            }
        case .quote: return PurnoteType.quote(compatibleWith: traits)
        case .code, .codeFence, .table: return PurnoteType.mono(compatibleWith: traits)
        default: return PurnoteType.body(compatibleWith: traits)
        }
    }

    private static func withTraits(_ font: UIFont, _ add: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let d = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(add))
        else { return font }
        return UIFont(descriptor: d, size: font.pointSize)
    }

    private static func paragraphStyle(_ p: HangingSyntax.Paragraph) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = p.firstLineHeadIndent
        style.headIndent = p.headIndent
        style.lineSpacing = 4
        style.baseWritingDirection = .natural
        style.alignment = .natural
        return style
    }

    /// The attributes a paragraph's text has, marker and spans aside.
    static func bodyAttributes(for p: HangingSyntax.Paragraph, traits: UITraitCollection)
        -> [NSAttributedString.Key: Any] {
        var color = PurnoteColor.ink
        switch p.kind {
        case .checklist(checked: true): color = PurnoteColor.ink2
        case .codeFence: color = PurnoteColor.ink3
        default: break
        }
        return [.font: baseFont(p.kind, traits: traits),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle(p)]
    }

    private static func attributes(for run: HangingSyntax.Run, in p: HangingSyntax.Paragraph,
                                   traits: UITraitCollection) -> [NSAttributedString.Key: Any] {
        let base = baseFont(p.kind, traits: traits)
        switch run.kind {
        case .marker:
            return [.font: PurnoteType.mono(compatibleWith: traits), .foregroundColor: PurnoteColor.ink3]
        case .delimiter:
            return [.foregroundColor: PurnoteColor.ink3]
        case .strong:
            return [.font: withTraits(base, .traitBold)]
        case .emphasis:
            return [.font: withTraits(base, .traitItalic)]
        case .strike:
            return [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        case .code:
            return [.font: PurnoteType.mono(compatibleWith: traits)]
        }
    }

    // MARK: - Applying

    /// Restyles `view`'s text. `dirty` is the range an edit just touched (new
    /// coordinates); nil restyles everything. Does nothing while a composition
    /// (CJK, dictation, the grey inline prediction) is open: changing
    /// attributes under marked text cancels it.
    func apply(to view: UITextView, dirty: NSRange?) {
        guard view.markedTextRange == nil else {
            needsFullRestyle = true
            return
        }

        let storage = view.textStorage
        let traits = view.traitCollection
        let metrics = Self.metrics(for: traits)
        let direction: HangingSyntax.Direction =
            view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rtl : .ltr
        let result = HangingSyntax.style(storage.string, metrics: metrics, direction: direction)

        let inset = UIEdgeInsets(top: 8, left: result.containerInsetLeft, bottom: 8, right: 20)
        if view.textContainerInset != inset { view.textContainerInset = inset }

        let everything = needsFullRestyle || dirty == nil
            || result.fenceLines != lastFenceLines || result.mode != lastMode
        lastFenceLines = result.fenceLines
        lastMode = result.mode
        lastResult = result
        lastLength = storage.length
        needsFullRestyle = false

        storage.beginEditing()
        for p in result.paragraphs where p.range.length > 0 {
            if !everything, let d = dirty,
               !(p.range.location <= NSMaxRange(d) && d.location <= NSMaxRange(p.range)) {
                continue
            }
            // setAttributes, not add: replaces whatever the characters carried,
            // which is what stops a marker's mono face leaking onto text typed
            // after it
            storage.setAttributes(Self.bodyAttributes(for: p, traits: traits), range: p.range)
            for run in p.runs {
                storage.addAttributes(Self.attributes(for: run, in: p, traits: traits), range: run.range)
            }
        }
        storage.endEditing()
    }

    // MARK: - Typing attributes

    /// What a character typed at the caret should look like: the paragraph's
    /// text style, never the marker's or a span's.
    func typingAttributes(for view: UITextView) -> [NSAttributedString.Key: Any] {
        let traits = view.traitCollection
        let length = view.textStorage.length
        let result: HangingSyntax.Result
        if let cached = lastResult, lastLength == length {
            result = cached
        } else {
            result = HangingSyntax.style(
                view.textStorage.string, metrics: Self.metrics(for: traits),
                direction: view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rtl : .ltr)
        }
        guard let paragraph = result.paragraph(at: view.selectedRange.location) else {
            return view.typingAttributes
        }
        return Self.bodyAttributes(for: paragraph, traits: traits)
    }

    func updateTypingAttributes(for view: UITextView) {
        guard view.markedTextRange == nil else { return }
        view.typingAttributes = typingAttributes(for: view)
    }
}

/// A UITextView that reports the trait changes the styling depends on: text
/// size, light/dark and layout direction. Attributed fonts do not follow
/// `adjustsFontForContentSizeCategory`, so the styler is asked again.
final class HangingTextView: UITextView {
    var onTraitChange: (() -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self,
                                 UITraitUserInterfaceStyle.self,
                                 UITraitLayoutDirection.self]) { (view: HangingTextView, _) in
            view.onTraitChange?()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
