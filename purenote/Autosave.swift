//
//  Autosave.swift
//  purenote
//

import SwiftUI

/// Saves a moment after typing stops, and again whenever the view goes away or
/// the app leaves the foreground.
///
/// Before this, an edit only survived if you tapped Done: swiping the app away
/// mid-note lost it, and a new note that had never been saved left nothing
/// behind at all.
struct Autosave: ViewModifier {
    /// The value being edited. Any change to it restarts the timer.
    let text: String
    let save: () -> Void
    /// Called once when editing is over rather than on every debounce, for
    /// work that should not happen while the user is still typing.
    let finish: () -> Void

    /// Long enough not to write on every keystroke, short enough that the gap
    /// between typing and a save on disk is not somewhere work can be lost.
    private static let delay = Duration.seconds(1)

    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onChange(of: text) {
                pending?.cancel()
                pending = Task {
                    try? await Task.sleep(for: Self.delay)
                    guard !Task.isCancelled else { return }
                    save()
                }
            }
            // .inactive covers the app switcher, which is where a swipe away
            // begins -- waiting for .background is too late to be sure of it
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { flush() }
            }
            .onDisappear { flush() }
    }

    private func flush() {
        pending?.cancel()
        pending = nil
        finish()
    }
}

extension View {
    /// Autosaves `text` by calling `save` once typing pauses, on dismissal,
    /// and when the app stops being active.
    func autosaving(_ text: String,
                    save: @escaping () -> Void,
                    finish: @escaping () -> Void) -> some View {
        modifier(Autosave(text: text, save: save, finish: finish))
    }
}
