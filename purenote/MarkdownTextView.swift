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

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        // A larger base than the 17pt system body -- this is a writing app and
        // the default read small. Still routed through UIFontMetrics, so the
        // reader's own Dynamic Type setting scales it from here.
        view.font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .systemFont(ofSize: Self.baseFontSize))
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        // plain text in, plain text out: no smart quotes or dashes, which would
        // quietly change the characters in somebody's file
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.autocorrectionType = .yes
        view.text = text

        let caret = initialCaret ?? text.count
        view.selectedRange = NSRange(location: text.utf16Offset(ofCharacter: caret), length: 0)

        DispatchQueue.main.async {
            view.becomeFirstResponder()
            view.scrollRangeToVisible(view.selectedRange)
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: MarkdownTextView
        /// The last caret request this view applied, so the same ask does not
        /// reapply while a fresh ask (even to the same offset) still does.
        var appliedCaretRequest: CaretRequest?

        init(_ parent: MarkdownTextView) { self.parent = parent }

        /// The whole point of this view: decide what Return means before the
        /// newline exists.
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText replacement: String) -> Bool {
            guard replacement == "\n", range.length == 0 else { return true }

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
            guard let edit = ListContinuation.edit(source, at: caret) else { return true }

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
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
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
