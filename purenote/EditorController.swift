//
//  EditorController.swift
//  purenote
//
//  The editor's top bar (Undo, Redo) and its Find in Note item live in SwiftUI,
//  outside the UITextView that owns the undo stack. This is the small bridge:
//  it holds a weak reference to the text view, publishes whether Undo and Redo
//  have anything to do, and forwards the three commands.
//
//  Undo and Redo act on the text view's own UndoManager and nothing else, so
//  one tap is exactly one step -- the same step Cmd-Z or shake would take. The
//  text view's undo stack is the only one: styling registers none (see
//  HangingStyler), and a formatting-bar edit is a single `replace` (see
//  MarkdownTextView.replaceMinimally).
//

import SwiftUI
import UIKit

final class EditorController: ObservableObject {

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private(set) weak var textView: UITextView?

    private var observers: [NSObjectProtocol] = []
    private var refreshScheduled = false

    init() {
        // Any undo manager's traffic is enough to wake a refresh; the answer
        // is always read from the text view's own manager, so another manager
        // (a text field elsewhere) only ever costs one cheap re-read.
        let names: [Notification.Name] = [
            .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
            .NSUndoManagerDidCloseUndoGroup,
            .NSUndoManagerCheckpoint,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                self?.scheduleRefresh()
            }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Ties the controller to the editor's text view. Called when the view is
    /// built; the reference is weak, so the controller never keeps it alive.
    func attach(_ view: UITextView) {
        textView = view
        scheduleRefresh()
    }

    // MARK: - Undo and redo

    func undo() {
        guard let manager = textView?.undoManager, manager.canUndo else { return }
        manager.undo()
        scheduleRefresh()
    }

    func redo() {
        guard let manager = textView?.undoManager, manager.canRedo else { return }
        manager.redo()
        scheduleRefresh()
    }

    /// Reads the manager now. The undo manager's notifications can arrive in
    /// the middle of a SwiftUI update (a formatting-bar edit is applied from
    /// `updateUIView`), where publishing would be a state change during a view
    /// update, so notifications and the text view's callbacks go through
    /// `scheduleRefresh`; tests and callers that need the answer at once call
    /// this.
    func refresh() {
        let manager = textView?.undoManager
        let undoable = manager?.canUndo ?? false
        let redoable = manager?.canRedo ?? false
        if canUndo != undoable { canUndo = undoable }
        if canRedo != redoable { canRedo = redoable }
    }

    /// One refresh on the next turn of the run loop, however many
    /// notifications arrive before then.
    func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshScheduled = false
            self.refresh()
        }
    }

    // MARK: - Find in Note

    /// Opens the system find bar over the editor (find only, no replace).
    func presentFind() {
        guard let view = textView, let interaction = view.findInteraction else { return }
        interaction.presentFindNavigator(showingReplace: false)
    }
}

/// Undo and Redo for the editor's top bar, next to the Done button.
struct EditorUndoRedoToolbar: ToolbarContent {
    @ObservedObject var controller: EditorController

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!controller.canUndo)
            .accessibilityLabel("Undo")
            .accessibilityIdentifier("editor.undo")

            Button {
                controller.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!controller.canRedo)
            .accessibilityLabel("Redo")
            .accessibilityIdentifier("editor.redo")
        }
    }
}
