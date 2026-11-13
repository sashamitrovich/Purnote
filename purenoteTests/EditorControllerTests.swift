@testable import Purnote
import XCTest
import UIKit
import SwiftUI

/// The editor's top-bar bridge (Undo, Redo, Find in Note), against a real
/// UITextView in a window, built the way the app builds it.
@MainActor
final class EditorControllerTests: XCTestCase {

    private final class Harness {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        let view: HangingTextView
        let coordinator: MarkdownTextView.Coordinator
        let controller = EditorController()
        /// Every value the view wrote to the `text` binding.
        var writes: [String] = []
        var text: String

        init(_ text: String) {
            self.text = text
            var box: Harness?
            let parent = MarkdownTextView(
                text: Binding(get: { box?.text ?? "" }, set: { box?.text = $0; box?.writes.append($0) }),
                selection: .constant(0..<0), caretRequest: .constant(nil), initialCaret: nil,
                controller: controller)
            coordinator = parent.makeCoordinator()
            view = MarkdownTextView.makeTextView(text: text, initialCaret: text.count, coordinator: coordinator)
            box = self
            let host = UIViewController()
            window.rootViewController = host
            host.view.addSubview(view)
            view.frame = window.bounds
            window.makeKeyAndVisible()
            _ = view.becomeFirstResponder()
            coordinator.restyle(view, dirty: nil)
            view.layoutIfNeeded()
            spin()
        }

        /// One keystroke the way UIKit delivers it (see HangingStylerTests).
        func type(_ string: String) {
            for ch in string {
                let s = String(ch)
                if coordinator.textView(view, shouldChangeTextIn: view.selectedRange, replacementText: s) {
                    view.insertText(s)
                }
            }
        }

        /// A formatting-bar edit: the binding changes, the coordinator syncs.
        func barEdit(to newText: String) {
            coordinator.syncFromBinding(view, to: newText)
        }

        /// Lets undo groups close and the controller's scheduled refresh run.
        func spin() { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }

        func font(at i: Int) -> UIFont {
            view.textStorage.attributes(at: i, effectiveRange: nil)[.font] as! UIFont
        }
    }

    // MARK: Publishing canUndo / canRedo

    func testAFreshEditorHasNothingToUndoOrRedo() {
        let h = Harness("hello")
        h.controller.refresh()
        XCTAssertFalse(h.controller.canUndo)
        XCTAssertFalse(h.controller.canRedo)
    }

    func testTypingEnablesUndoAndNotRedo() {
        let h = Harness("")
        h.type("abc")
        h.spin()
        XCTAssertTrue(h.controller.canUndo, "typing left Undo disabled")
        XCTAssertFalse(h.controller.canRedo)
    }

    func testUndoRestoresTheExactStringAndEnablesRedo() {
        let h = Harness("")
        h.type("abc")
        h.spin()
        XCTAssertEqual(h.view.text, "abc")

        h.controller.undo()
        h.spin()
        XCTAssertEqual(h.view.text, "", "one Undo must take back what was typed (UIKit groups one event)")
        XCTAssertEqual(h.text, "", "the binding must follow the undo")
        XCTAssertFalse(h.controller.canUndo, "nothing is left to undo")
        XCTAssertTrue(h.controller.canRedo, "Redo should be enabled after an undo")

        h.controller.redo()
        h.spin()
        XCTAssertEqual(h.view.text, "abc")
        XCTAssertEqual(h.text, "abc", "the binding must follow the redo")
        XCTAssertTrue(h.controller.canUndo)
        XCTAssertFalse(h.controller.canRedo)
    }

    func testANewEditAfterAnUndoClearsRedo() {
        let h = Harness("")
        h.type("abc")
        h.spin()
        h.controller.undo()
        h.spin()
        XCTAssertTrue(h.controller.canRedo)
        h.type("x")
        h.spin()
        XCTAssertFalse(h.controller.canRedo, "typing after an undo must drop the redo stack")
        XCTAssertTrue(h.controller.canUndo)
    }

    func testUndoAndRedoOnAnEmptyStackDoNothing() {
        let h = Harness("note")
        h.controller.undo()
        h.controller.redo()
        h.spin()
        XCTAssertEqual(h.view.text, "note")
        XCTAssertFalse(h.controller.canUndo)
        XCTAssertFalse(h.controller.canRedo)
        XCTAssertTrue(h.writes.isEmpty, "an empty-stack Undo must not write the binding")
    }

    // MARK: A bar edit is one step

    func testAFormattingBarEditIsExactlyOneUndoStep() {
        let h = Harness("")
        h.type("abc")
        h.spin()
        h.barEdit(to: "abc****")          // Bold
        h.spin()
        XCTAssertEqual(h.view.text, "abc****")
        XCTAssertTrue(h.controller.canUndo)

        h.controller.undo()
        h.spin()
        XCTAssertEqual(h.view.text, "abc", "one Undo must take back exactly the Bold edit")
        XCTAssertEqual(h.text, "abc")
        XCTAssertTrue(h.controller.canUndo, "the typing before the edit must still be undoable")
        XCTAssertTrue(h.controller.canRedo)

        h.controller.redo()
        h.spin()
        XCTAssertEqual(h.view.text, "abc****")
        XCTAssertEqual(h.text, "abc****")
    }

    func testHeadingEditUndoneInOneStep() {
        let h = Harness("")
        h.type("title")
        h.spin()
        h.barEdit(to: "# title")
        h.spin()
        h.controller.undo()
        h.spin()
        XCTAssertEqual(h.view.text, "title")
        XCTAssertEqual(h.text, "title")
    }

    // MARK: Styling follows an undo

    /// Undo puts text back through the text view; the styler must be run again
    /// or the restored characters keep whatever attributes the undo gave them
    /// (a heading's size on a line that is no longer a heading).
    func testUndoAndRedoRestyleTheText() {
        let h = Harness("")
        h.type("title")
        h.spin()
        let bodySize = h.font(at: 0).pointSize
        h.barEdit(to: "# title")
        h.spin()
        XCTAssertTrue(h.font(at: 0).fontName.localizedCaseInsensitiveContains("Mono"),
                      "the # marker should be set in the mono face")
        XCTAssertGreaterThan(h.font(at: 2).pointSize, bodySize, "heading text should be larger than body")

        h.controller.undo()
        h.spin()
        XCTAssertEqual(h.view.text, "title")
        XCTAssertEqual(h.font(at: 0).pointSize, bodySize, "undone text kept the heading's size")
        XCTAssertFalse(h.font(at: 0).fontName.localizedCaseInsensitiveContains("Mono"),
                       "undone text kept the marker's mono face")

        h.controller.redo()
        h.spin()
        XCTAssertEqual(h.view.text, "# title")
        XCTAssertTrue(h.font(at: 0).fontName.localizedCaseInsensitiveContains("Mono"),
                      "redone marker was not restyled")
        XCTAssertGreaterThan(h.font(at: 2).pointSize, bodySize)
    }

    func testStylingRegistersNoUndoOfItsOwn() {
        let h = Harness("# a\n- b")
        h.coordinator.styler.needsFullRestyle = true
        h.coordinator.restyle(h.view, dirty: nil)
        h.spin()
        XCTAssertFalse(h.controller.canUndo, "restyling put something on the undo stack")
    }

    // MARK: Find in Note

    func testFindInteractionIsEnabledAndPresentable() {
        let h = Harness("find me")
        XCTAssertTrue(h.view.isFindInteractionEnabled)
        XCTAssertNotNil(h.view.findInteraction)
        // opening it must not crash or touch the text
        h.controller.presentFind()
        h.spin()
        XCTAssertEqual(h.view.text, "find me")
        XCTAssertFalse(h.controller.canUndo)
    }

    func testAControllerWithoutATextViewIsInert() {
        let controller = EditorController()
        controller.undo()
        controller.redo()
        controller.presentFind()
        controller.refresh()
        XCTAssertFalse(controller.canUndo)
        XCTAssertFalse(controller.canRedo)
    }
}
