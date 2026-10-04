//
//  ShareViewController.swift
//  purenoteShare
//

import UIKit

/// The share extension's whole interface: a preview of what was shared, which
/// the user can trim before saving, and the two obvious buttons.
///
/// The note is written straight into Purnote's iCloud folder through the same
/// coordinated-file layer the app uses, so a shared post is just another
/// `.md` file and turns up in the app on its own (the app's metadata query
/// notices the new file, exactly as it does for a note written on the Mac).
final class ShareViewController: UIViewController {

    private let textView = UITextView()
    private var saveButton: UIBarButtonItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        let navItem = UINavigationItem(title: "Save to Purnote")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        let save = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(save))
        save.isEnabled = false
        navItem.rightBarButtonItem = save
        navBar.items = [navItem]
        saveButton = save
        view.addSubview(navBar)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .preferredFont(forTextStyle: .body)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            textView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        Task { await loadSharedContent() }
    }

    // MARK: - Reading what was shared

    private func loadSharedContent() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []

        var text: String?
        var url: String?

        for item in items {
            for provider in item.attachments ?? [] {
                if text == nil, provider.hasItemConformingToTypeIdentifier("public.text"),
                   let loaded = try? await provider.loadItem(forTypeIdentifier: "public.text") as? String,
                   !loaded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = loaded
                }
                if url == nil, provider.hasItemConformingToTypeIdentifier("public.url") {
                    let loaded = try? await provider.loadItem(forTypeIdentifier: "public.url")
                    url = (loaded as? URL)?.absoluteString ?? (loaded as? String)
                }
            }
        }

        let content = ShareContent.note(text: text, url: url)
        textView.text = content
        saveButton?.isEnabled = !content.isEmpty
    }

    // MARK: - Actions

    @objc private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.mitrovic.purenote.share", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
    }

    @objc private func save() {
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        // The note goes into the App Group inbox; the app moves it into its
        // storage (iCloud Drive or local) the next time it opens. The
        // extension cannot reach the app's own Documents folder, so the shared
        // inbox is the hand-off point.
        guard let inbox = SharedInbox.inboxURL else {
            present(alert: "Couldn't save",
                    message: "Purnote couldn't access its shared storage. Try again.")
            return
        }

        do {
            try SharedInbox.save(content, to: inbox)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            present(alert: "Couldn't save",
                    message: "Purnote could not write this note. Try again in a moment.")
        }
    }

    private func present(alert title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
