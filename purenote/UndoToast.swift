//
//  UndoToast.swift
//  purenote
//
//  The "Moved to Recently Deleted -- Undo" toast, and the one place that
//  decides what a delete looks like to the user: it worked (a toast that holds
//  exactly what moved, so one Undo puts all of it back) or it did not (the row
//  stays, an alert says why, no toast).
//
//  The model has no timers of its own: the expiry goes through an injected
//  scheduler, so the tests fire it by hand instead of sleeping. Main thread
//  only, like the views and the DataManager it works with.
//

import SwiftUI
import UIKit

/// What an alert on the delete / restore screens says.
struct TrashAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class UndoToastModel: ObservableObject {

    typealias Cancel = () -> Void
    /// Runs `action` after `delay` seconds on the main thread; the result cancels it.
    typealias Scheduler = (_ delay: TimeInterval, _ action: @escaping () -> Void) -> Cancel
    typealias Restorer = (TrashedItem) throws -> Void

    /// One toast: what it says, the items it can put back, and how.
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let items: [TrashedItem]
        let restore: Restorer
    }

    static let message = "Moved to Recently Deleted"
    /// About six seconds. The UI tests, whose every step takes a second or more to
    /// resolve on the simulator, run with the fixture launch argument and get thirty
    /// so the toast is still there when the test taps it; the expiry itself is
    /// covered by the unit tests, which inject their own scheduler.
    nonisolated static var defaultDuration: TimeInterval { Storage.isUITestFixture ? 30 : 6 }

    /// The toast on screen. There is never more than one: a newer one replaces it.
    @Published private(set) var current: Toast?
    /// A delete or an Undo that did not work, to be shown as an alert.
    @Published var alert: TrashAlert?

    private let duration: TimeInterval
    private let schedule: Scheduler
    private var cancelExpiry: Cancel?

    init(duration: TimeInterval = UndoToastModel.defaultDuration,
         schedule: @escaping Scheduler = UndoToastModel.mainQueueScheduler) {
        self.duration = duration
        self.schedule = schedule
    }

    static let mainQueueScheduler: Scheduler = { delay, action in
        let work = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        return { work.cancel() }
    }

    // MARK: Showing and expiring

    /// Shows a toast for these items, replacing any toast already there.
    /// `restore` puts one of them back; Undo calls it for each.
    func show(_ items: [TrashedItem], restore: @escaping Restorer) {
        guard !items.isEmpty else { return }
        cancelExpiry?()
        let toast = Toast(message: Self.message, items: items, restore: restore)
        current = toast
        // the id check keeps a timer that was already on its way from taking down a newer toast
        cancelExpiry = schedule(duration) { [weak self] in
            guard let self, self.current?.id == toast.id else { return }
            self.current = nil
            self.cancelExpiry = nil
        }
    }

    func dismiss() {
        cancelExpiry?()
        cancelExpiry = nil
        current = nil
    }

    // MARK: Undo

    /// Puts back everything the toast on screen covers, and nothing else. One
    /// that cannot be put back does not stop the rest; the alert says how many.
    func undo() {
        guard let toast = current else { return }
        dismiss()

        var failures: [Error] = []
        for item in toast.items {
            do { try toast.restore(item) } catch { failures.append(error) }
        }
        guard let first = failures.first else { return }

        let reason = first.localizedDescription
        if toast.items.count == 1 {
            alert = TrashAlert(title: "Could not put it back", message: reason)
        } else {
            alert = TrashAlert(title: "Could not put back everything",
                               message: "\(failures.count) of \(toast.items.count) could not be put back. \(reason) Look in Recently Deleted.")
        }
    }

    // MARK: Deleting

    /// Deletes a note through the trash. On success the row is gone and the
    /// toast is up; on failure the row stays and an alert says why.
    func delete(note: Note, from data: DataManager, index: SearchIndex?) {
        let name = Self.displayName(of: note.url)
        do {
            let item = try data.trash(note: note, index: index)
            show([item], restore: Self.restorer(data, index))
        } catch TrashError.rollbackFailed(let item, let underlying) {
            // the note is in the trash (its pictures stayed behind): it can be undone, and the user is told
            show([item], restore: Self.restorer(data, index))
            alert = TrashAlert(title: "\u{201C}\(name)\u{201D} was only partly deleted",
                               message: "Its pictures could not be moved: \(underlying.localizedDescription) The note itself is in Recently Deleted.")
        } catch {
            reportDeleteFailure(name: name, error: error)
        }
    }

    /// Deletes a folder and the notes in it through the trash; same outcomes.
    func delete(folder: Folder, from data: DataManager, index: SearchIndex?) {
        do {
            let item = try data.trash(folder: folder, index: index)
            show([item], restore: Self.restorer(data, index))
        } catch {
            reportDeleteFailure(name: folder.id, error: error)
        }
    }

    func reportDeleteFailure(name: String, error: Error) {
        alert = TrashAlert(title: "Could not delete \u{201C}\(name)\u{201D}",
                           message: "\(error.localizedDescription) Nothing was deleted.")
    }

    private static func restorer(_ data: DataManager, _ index: SearchIndex?) -> Restorer {
        { item in _ = try data.restore(item, index: index) }
    }

    /// "Marathon training" for ".../Marathon training.md".
    private static func displayName(of url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        return stem.isEmpty ? url.lastPathComponent : stem
    }
}

// MARK: - The toast

/// The toast itself: a small card that sits just above the bottom bar.
struct UndoToastView: View {
    let toast: UndoToastModel.Toast
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(Color.pn.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo", action: undo)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.pn.ribbonText)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("undo.button")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .background(Color.pn.sheet, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pn.rule, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("undo.toast")
    }
}

/// Puts the toast above whatever is below it and tells VoiceOver when one appears.
struct UndoToastHost: View {
    @ObservedObject var model: UndoToastModel

    var body: some View {
        VStack(spacing: 0) {
            if let toast = model.current {
                UndoToastView(toast: toast) { model.undo() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.current?.id)
        .onChange(of: model.current?.id) {
            if let toast = model.current {
                UIAccessibility.post(notification: .announcement,
                                     argument: "\(toast.message). Undo is available.")
            }
        }
    }
}
