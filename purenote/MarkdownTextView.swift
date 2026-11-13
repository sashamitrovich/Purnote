//
//  MarkdownTextView.swift
//  purenote
//
//  The text view behind the editor.
//
//  SwiftUI's TextEditor cannot be told about a key before it takes effect: it
//  offers a String binding and nothing else. Return inside a list therefore had
//  to be caught after the newline had already been inserted, by comparing the
//  text before and after -- and that comparison cannot say where the newline
//  went. Insert one next to an existing newline and the two versions match past
//  the real insertion point, so the wrong line gets rewritten: a stray marker
//  on the following item and the caret several lines away.
//
//  A UITextView is asked first. `shouldChangeTextIn` hands over the exact range
//  and the exact replacement, so there is nothing to infer, and the edit can be
//  made as one change -- which is also what keeps undo to a single step.
//
//  Styling (hanging syntax, see HangingSyntax / HangingStyler) is attributes
//  only. Two rules keep it from costing anything else:
//    - the view's text is never assigned after creation. When the binding
//      differs from the view (a formatting-bar edit), only the changed span is
//      replaced through `replace(_:withText:)`, so the edit lands on the undo
//      stack as one step. `view.text = ...` would wipe the attributes and the
//      whole undo history.
//    - attributes are re-applied in place after every change, with no undo
//      registered and not at all while a composition (marked text) is open.
//

import SwiftUI
import UIKit

struct MarkdownTextView: UIViewRepresentable {
    /// Base size for the editor, before Dynamic Type scales it.
    static let baseFontSize: CGFloat = 19

    @Binding var text: String
    /// The selection, in character offsets, so the formatting bar can work in
    /// the same units as MarkdownFormatter.
    @Binding var selection: Range<Int>
    /// A caret placement requested by the formatting bar, applied here so the
    /// live selection binding never has to be forced during typing.
    @Binding var caretRequest: CaretRequest?
    /// Where to put the caret the first time the editor appears.
    var initialCaret: Int?
    /// The bridge to the SwiftUI top bar (Undo, Redo) and the Find in Note
    /// item: told about the text view when it is built, and whenever its text
    /// changes.
    var controller: EditorController? = nil

    func makeUIView(context: Context) -> UITextView {
        let view = Self.makeTextView(text: text, initialCaret: initialCaret,
                                     coordinator: context.coordinator)
        DispatchQueue.main.async {
            view.becomeFirstResponder()
            view.scrollRangeToVisible(view.selectedRange)
        }
        return view
    }

    /// Builds the configured, styled text view. Separate from `makeUIView` so a
    /// test can build the same view without a SwiftUI context.
    static func makeTextView(text: String, initialCaret: Int?, coordinator: Coordinator) -> HangingTextView {
        let view = HangingTextView()
        view.delegate = coordinator
        // New York 17 (PurnoteType.body), the reading view's face and size, so
        // nothing jumps when you tap into a note. Fonts on the runs come from
        // HangingStyler and follow Dynamic Type through UIFontMetrics; the
        // styler is asked again when the size changes (HangingTextView).
        view.font = PurnoteType.body()
        view.textColor = PurnoteColor.ink
        view.adjustsFontForContentSizeCategory = false
        view.backgroundColor = .clear
        // the left inset is the styler's to set (6 when hanging, 20 inline)
        view.textContainerInset = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        // plain text in, plain text out: no smart quotes or dashes, which would
        // quietly change the characters in somebody's file
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.autocorrectionType = .yes
        // Find in Note (the editor's "More" menu) presents the system find bar
        view.isFindInteractionEnabled = true
        view.text = text

        let caret = initialCaret ?? text.count
        view.selectedRange = NSRange(location: text.utf16Offset(ofCharacter: caret), length: 0)

        view.onTraitChange = { [weak view, weak coordinator] in
            guard let view, let coordinator else { return }
            coordinator.styler.needsFullRestyle = true
            coordinator.restyle(view, dirty: nil)
        }
        coordinator.restyle(view, dirty: nil)
        coordinator.controller?.attach(view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        // Only when the string really differs (a formatting-bar edit), and then
        // as a replace of the changed span: assigning `view.text` would wipe the
        // attributes and the undo stack.
        if view.text != text {
            context.coordinator.syncFromBinding(view, to: text)
        }

        // The formatting bar asks for the caret explicitly. Apply it on its own
        // rather than from the live selection binding: during ordinary typing
        // the binding lags the view, and syncing it back would yank the caret
        // mid-word. A request also arrives again after a Menu item's action,
        // once the menu has dismissed and focus has settled, so it lands even
        // though the text itself has not changed.
        guard let request = caretRequest,
              context.coordinator.appliedCaretRequest != request else { return }
        context.coordinator.appliedCaretRequest = request

        let location = text.utf16Offset(ofCharacter: request.offset)
        let range = NSRange(location: location, length: 0)
        view.selectedRange = range
        view.scrollRangeToVisible(range)
    }

    /// Makes the view's text equal `newText` by replacing only the span that
    /// differs, through the text view's own edit path (one undo step). Returns
    /// the span of the new text that was written, in UTF-16.
    @discardableResult
    static func replaceMinimally(in view: UITextView, with newText: String) -> NSRange {
        let old = (view.text ?? "") as NSString
        let new = newText as NSString

        // longest common prefix and suffix, in UTF-16 units, backed off so a
        // surrogate pair or a combined character is never split
        var prefix = 0
        let limit = min(old.length, new.length)
        while prefix < limit && old.character(at: prefix) == new.character(at: prefix) { prefix += 1 }
        if prefix < old.length { prefix = old.rangeOfComposedCharacterSequence(at: prefix).location }

        var suffix = 0
        while suffix < limit - prefix
                && old.character(at: old.length - 1 - suffix) == new.character(at: new.length - 1 - suffix) {
            suffix += 1
        }
        if suffix > 0 {
            let boundary = old.length - suffix
            if boundary > 0 && boundary < old.length {
                let composed = old.rangeOfComposedCharacterSequence(at: boundary)
                if composed.location < boundary { suffix -= boundary - composed.location }
            }
        }

        let oldRange = NSRange(location: prefix, length: old.length - prefix - suffix)
        let newRange = NSRange(location: prefix, length: new.length - prefix - suffix)
        guard let from = view.position(from: view.beginningOfDocument, offset: oldRange.location),
              let to = view.position(from: from, offset: oldRange.length),
              let target = view.textRange(from: from, to: to) else {
            // cannot happen for ranges taken from the view's own text; fall back
            // rather than leave the view out of step with the binding
            view.text = newText
            return NSRange(location: 0, length: new.length)
        }
        view.replace(target, withText: new.substring(with: newRange))
        return newRange
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: MarkdownTextView
        /// The last caret request this view applied, so the same ask does not
        /// reapply while a fresh ask (even to the same offset) still does.
        var appliedCaretRequest: CaretRequest?

        let styler = HangingStyler()
        /// The span the user's last keystroke touched, in the coordinates of
        /// the text after the change, so only those paragraphs are restyled.
        private var pendingDirty: NSRange?
        /// True while we are writing the binding's text into the view, so the
        /// view's own callbacks do not write it straight back.
        private var applyingBinding = false

        var controller: EditorController? { parent.controller }

        init(_ parent: MarkdownTextView) { self.parent = parent }

        /// Re-applies the attributes in place and keeps the typing attributes
        /// in step, so text typed next is styled as text.
        func restyle(_ view: UITextView, dirty: NSRange?) {
            styler.apply(to: view, dirty: dirty)
            styler.updateTypingAttributes(for: view)
        }

        /// A change that came from outside the view (the formatting bar).
        func syncFromBinding(_ view: UITextView, to newText: String) {
            applyingBinding = true
            MarkdownTextView.replaceMinimally(in: view, with: newText)
            applyingBinding = false
            pendingDirty = nil
            restyle(view, dirty: nil)
        }

        /// The whole point of this view: decide what Return means before the
        /// newline exists.
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText replacement: String) -> Bool {
            guard replacement == "\n", range.length == 0 else {
                pendingDirty = NSRange(location: range.location, length: replacement.utf16.count)
                return true
            }

            // Return can arrive while a word is still being composed -- the
            // grey inline prediction, or a multistage keyboard. That text is
            // not in `textView.text` yet, so continuing the list from it would
            // work off a buffer missing the letters the user can see, and they
            // end up on the wrong line. Commit it first, then read the caret
            // back rather than trusting the range we were handed, which the
            // commit may have moved.
            if textView.markedTextRange != nil {
                textView.unmarkText()
            }

            let source = textView.text ?? ""
            let caret = source.characterOffset(ofUTF16: textView.selectedRange.location)
            guard let edit = ListContinuation.edit(source, at: caret) else {
                pendingDirty = NSRange(location: textView.selectedRange.location, length: 1)
                return true
            }

            // as one edit, through the text view itself, so it lands on the
            // undo stack as a single step the user can take back
            let start = source.utf16Offset(ofCharacter: edit.range.lowerBound)
            let end = source.utf16Offset(ofCharacter: edit.range.upperBound)
            guard let from = textView.position(from: textView.beginningOfDocument, offset: start),
                  let to = textView.position(from: textView.beginningOfDocument, offset: end),
                  let target = textView.textRange(from: from, to: to)
            else { return true }

            textView.replace(target, withText: edit.replacement)

            // edit.caret is an offset into the text as it now stands, so it is
            // measured against the new text -- measuring it against the old one
            // put the caret near the top of the note and typing went there
            let updated = textView.text ?? ""
            textView.selectedRange = NSRange(
                location: updated.utf16Offset(ofCharacter: edit.caret), length: 0)
            textView.scrollRangeToVisible(textView.selectedRange)

            parent.text = textView.text
            parent.selection = edit.caret..<edit.caret
            // the characters the replace inserted took the marker's attributes
            // from the line above; restyle, then type as text
            pendingDirty = nil
            restyle(textView, dirty: nil)
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            if !applyingBinding { parent.text = textView.text }
            let dirty = pendingDirty
            pendingDirty = nil
            restyle(textView, dirty: dirty)
            // typing, Undo and Redo all end up here: Undo / Redo may have
            // changed whether there is anything left to undo or redo
            parent.controller?.scheduleRefresh()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // the caret moved: what is typed next takes the style of the
            // paragraph it lands in, not of the marker it may sit beside
            styler.updateTypingAttributes(for: textView)
            guard !applyingBinding else { return }
            let source = textView.text ?? ""
            let lower = source.characterOffset(ofUTF16: textView.selectedRange.location)
            let upper = source.characterOffset(
                ofUTF16: textView.selectedRange.location + textView.selectedRange.length)
            parent.selection = lower..<max(lower, upper)
        }
    }
}

extension String {
    /// Character offset for a UTF-16 offset. The two disagree the moment a note
    /// contains an emoji, and UIKit counts in UTF-16 while everything of ours
    /// counts in Characters.
    func characterOffset(ofUTF16 offset: Int) -> Int {
        let clamped = min(max(offset, 0), utf16.count)
        guard let index = String.Index(String.Index(utf16Offset: clamped, in: self), within: self)
        else { return count }
        return distance(from: startIndex, to: index)
    }

    /// UTF-16 offset for a character offset.
    func utf16Offset(ofCharacter offset: Int) -> Int {
        let index = index(startIndex, offsetBy: min(max(offset, 0), count))
        return index.utf16Offset(in: self)
    }
}
